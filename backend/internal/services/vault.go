package services

import (
	"context"
	"errors"
	"fmt"
	"log"
	"math/big"
	"strings"
	"sync"
	"time"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/infrastructure/blockchain"
	"globmint/backend/internal/storage"
)

// VaultConfig carries the on-chain + rate settings for the custodial personal
// vault. VaultAddress is the on-chain address users send USD deposits to; the
// backend holds its signer key, so it can detect inbound deposits and pay out
// withdraws to any address the user supplies.
type VaultConfig struct {
	VaultAddress       string
	StablecoinSymbol   string
	StablecoinDecimals int
	Mode               string
	// PollInterval is how often the deposit indexer scans new blocks.
	PollInterval time.Duration
	// StartBlock is the first block the indexer scans from on first run.
	StartBlock uint64
	// FallbackUserID credits vault deposits to this user when the on-chain
	// sender has no deposit-address link (single-user demo deployments).
	FallbackUserID string
	// MinConfirmations is how many block confirmations a deposit must reach
	// before the indexer credits the ledger (reorg protection).
	MinConfirmations uint64
	// WithdrawEnabled gates on-chain withdrawals entirely.
	WithdrawEnabled bool
	// WithdrawMinMinor / WithdrawMaxMinor bound a single withdrawal (kobo).
	WithdrawMinMinor int64
	WithdrawMaxMinor int64
	// WithdrawDailyCapMinor caps the total withdrawn per user per UTC day (kobo).
	WithdrawDailyCapMinor int64
}

// VaultService runs the deposit indexer and executes withdrawals on the
// custodial vault. NGN<->USDC is converted using the seeded (USDT, NGN) rate.
type VaultService struct {
	store     storage.Store
	chain     blockchain.BlockchainService
	money     *MoneyService
	cfg       VaultConfig
	rateMinor int64 // NGN minor units per 1 USDC (kobo per USDC), 0 => fallback

	mu        sync.Mutex
	lastBlock uint64

	// cache of on-chain sender -> userID, refreshed per scan
	addressUser map[string]string
}

// NewVaultService builds the vault service. rateMinor is the NGN minor units
// per 1 USDC (i.e. the value 160450 for 1604.50 NGN/USDC); pass 0 to fall back
// to 160450.
func NewVaultService(store storage.Store, chain blockchain.BlockchainService, money *MoneyService, cfg VaultConfig, rateMinor int64) *VaultService {
	if rateMinor <= 0 {
		rateMinor = 160450
	}
	if cfg.PollInterval <= 0 {
		cfg.PollInterval = 8 * time.Second
	}
	return &VaultService{
		store:       store,
		chain:       chain,
		money:       money,
		cfg:         cfg,
		rateMinor:   rateMinor,
		lastBlock:   cfg.StartBlock,
		addressUser: map[string]string{},
	}
}

// DepositAddress returns the on-chain address users send deposits to.
func (v *VaultService) DepositAddress() string { return v.cfg.VaultAddress }

// -------- Deposit indexer --------

// RunIndexer polls the chain for stablecoin transfers into the vault and
// credits the owning user's NGN balance for each new deposit. It runs until
// ctx is cancelled.
func (v *VaultService) RunIndexer(ctx context.Context) {
	if v.cfg.Mode == "mock" || v.cfg.VaultAddress == "" {
		log.Printf("vault indexer: disabled (mode=%s vault=%q)", v.cfg.Mode, v.cfg.VaultAddress)
		return
	}
	log.Printf("vault indexer: watching %s for %s deposits", v.cfg.VaultAddress, v.cfg.StablecoinSymbol)

	ticker := time.NewTicker(v.cfg.PollInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			log.Println("vault indexer: stopped")
			return
		case <-ticker.C:
			if err := v.scan(ctx); err != nil {
				log.Printf("vault indexer: scan error: %v", err)
			}
		}
	}
}

func (v *VaultService) scan(ctx context.Context) error {
	latest, err := v.chain.LatestBlock(ctx)
	if err != nil {
		return err
	}

	// Only credit deposits past the confirmation window so a reorg cannot
	// reverse a credited deposit. Blocks inside the window are re-scanned on a
	// later poll once they are deep enough.
	confirmedHead := latest
	if v.cfg.MinConfirmations > 0 {
		if latest <= v.cfg.MinConfirmations {
			return nil
		}
		confirmedHead = latest - v.cfg.MinConfirmations
	}

	v.mu.Lock()
	scanFrom := v.lastBlock
	// On the very first scan, skip pre-existing history and only watch blocks
	// mined from now on.
	if scanFrom == 0 {
		scanFrom = latest
	}
	if scanFrom == 0 {
		v.mu.Unlock()
		return nil
	}
	confHead := confirmedHead
	if confHead < scanFrom {
		v.mu.Unlock()
		return nil
	}
	toBlock := confHead
	v.mu.Unlock()

	tsf, err := v.chain.FilterTokenTransfers(ctx, scanFrom, toBlock, v.cfg.VaultAddress)
	if err != nil {
		return err
	}

	newCursor := scanFrom
	for _, t := range tsf {
		if t.BlockNumber >= newCursor {
			newCursor = t.BlockNumber + 1
		}
		if err := v.handleDeposit(ctx, t); err != nil {
			log.Printf("vault indexer: deposit %s ignored: %v", t.TxHash, err)
		}
	}
	v.mu.Lock()
	if newCursor > v.lastBlock {
		v.lastBlock = newCursor
	}
	v.mu.Unlock()
	return nil
}

// handleDeposit credits the NGN balance of the user whose linked wallet (the
// transfer sender) sent USDC into the vault. Duplicate tx hashes are ignored.
func (v *VaultService) handleDeposit(ctx context.Context, t blockchain.TokenTransfer) error {
	if !strings.EqualFold(t.To, v.cfg.VaultAddress) || t.Value == nil || t.Value.Sign() <= 0 {
		return nil
	}
	userID, err := v.senderUserID(ctx, t.From)
	if err != nil || userID == "" {
		if err == nil {
			err = errors.New("sender not linked to a user")
		}
		return err
	}

	ngnMinor := depositNGNMinor(t.Value, v.rateMinor)
	if ngnMinor <= 0 {
		return errors.New("deposit value below resolution")
	}

	// Idempotent by tx hash so rescans never double-credit.
	key := "vault-deposit-" + t.TxHash
	_, err = v.money.Deposit(ctx, userID, "NGN", ngnMinor, key)
	if err != nil && !errors.Is(err, domain.ErrConflict) {
		return err
	}
	log.Printf("vault indexer: credited %d kobo to %s (tx %s, %s USDC)",
		ngnMinor, userID, t.TxHash, baseToMajorString(t.Value, v.cfg.StablecoinDecimals))
	return nil
}

// senderUserID resolves an on-chain sender address to a Globmint user via the
// deposit-address link. Results are cached for the lifetime of the service.
func (v *VaultService) senderUserID(ctx context.Context, from string) (string, error) {
	v.mu.Lock()
	if uid, ok := v.addressUser[from]; ok {
		v.mu.Unlock()
		return uid, nil
	}
	v.mu.Unlock()

	uid, err := v.store.DepositAddressRepo().OwnerOf(ctx, from)
	if err != nil {
		return "", err
	}
	if uid == "" {
		uid = v.cfg.FallbackUserID
	}
	if uid == "" {
		return "", nil
	}
	v.mu.Lock()
	v.addressUser[from] = uid
	v.mu.Unlock()
	return uid, nil
}

// -------- Withdraw --------

// WithdrawToAddress converts `amountNgnMinor` kobo to USDC at the vault rate,
// debits the user's NGN available balance, and sends the USDC on-chain from the
// vault to `destination`. The on-chain tx hash is stored as the provider ref.
func (v *VaultService) WithdrawToAddress(ctx context.Context, userID, destination string, amountNgnMinor int64, key string) (*domain.Transaction, error) {
	if v.cfg.Mode == "mock" || v.cfg.VaultAddress == "" {
		return nil, errors.New("on-chain vault is not enabled")
	}
	if !v.cfg.WithdrawEnabled {
		return nil, domain.ErrFeatureDisabled
	}
	if amountNgnMinor <= 0 {
		return nil, domain.ErrInvalidAmount
	}
	if v.cfg.WithdrawMinMinor > 0 && amountNgnMinor < v.cfg.WithdrawMinMinor {
		return nil, domain.ErrInvalidAmount
	}
	if v.cfg.WithdrawMaxMinor > 0 && amountNgnMinor > v.cfg.WithdrawMaxMinor {
		return nil, domain.ErrLimitExceeded
	}
	if v.cfg.WithdrawDailyCapMinor > 0 {
		dayStart := time.Now().UTC().Truncate(24 * time.Hour)
		used, err := v.store.LedgerRepo().SumWithdrawalsSince(ctx, userID, dayStart)
		if err != nil {
			return nil, err
		}
		if used+amountNgnMinor > v.cfg.WithdrawDailyCapMinor {
			return nil, domain.ErrLimitExceeded
		}
	}

	// Replay protection: if this idempotency key already produced a
	// withdrawal, return the recorded transaction without touching the chain.
	if key != "" {
		if existing, err := v.store.LedgerRepo().FindTransactionByIDempotencyKey(ctx, key); err == nil && existing != nil {
			return existing, nil
		}
	}

	usdcBase := withdrawUSDCBase(amountNgnMinor, v.rateMinor)
	if usdcBase <= 0 {
		return nil, domain.ErrInvalidAmount
	}

	// Broadcast the on-chain transfer first (it may fail on insufficient funds).
	major := baseToMajorString(big.NewInt(usdcBase), v.cfg.StablecoinDecimals)
	txHash, err := v.chain.TransferToken(ctx, destination, major)
	if err != nil {
		return nil, fmt.Errorf("on-chain send failed: %w", err)
	}

	// Debit NGN after the chain send succeeds.
	txn, err := v.money.Withdraw(ctx, LedgerMoveRequest{
		UserID:         userID,
		AccountKind:    domain.AccountKindAvailable,
		Currency:       "NGN",
		Type:           domain.TransactionTypeWithdrawal,
		AmountMinor:    amountNgnMinor,
		ProviderRef:    txHash,
		IdempotencyKey: key,
		Metadata: map[string]any{
			"destination": destination,
			"stablecoin":  v.cfg.StablecoinSymbol,
		},
	}, key)
	if err != nil {
		// Ledger was not debited; the USDC already left the vault. Surface the
		// tx hash so the situation is traceable.
		return nil, fmt.Errorf("on-chain sent (%s) but ledger debit failed: %w", txHash, err)
	}
	return txn, nil
}

// -------- Conversion helpers (integer math) --------

// depositNGNMinor converts an on-chain stablecoin base amount (6 decimals) into
// NGN minor units (kobo) using the seeded rate (NGN minor per 1 USDC major).
func depositNGNMinor(usdcBase *big.Int, rateMinor int64) int64 {
	// ngnMinor = usdcBase * rateMinor / 1_000_000
	num := new(big.Int).Mul(usdcBase, big.NewInt(rateMinor))
	num.Div(num, big.NewInt(1_000_000))
	return num.Int64()
}

// withdrawUSDCBase converts a NGN minor amount (kobo) into stablecoin base
// units (6 decimals) using the seeded rate.
func withdrawUSDCBase(ngnMinor int64, rateMinor int64) int64 {
	// usdcBase = ngnMinor * 1_000_000 / rateMinor
	val := big.NewInt(ngnMinor)
	val.Mul(val, big.NewInt(1_000_000))
	val.Div(val, big.NewInt(rateMinor))
	return val.Int64()
}

// baseToMajorString renders a base-unit amount as a decimal major string with
// exactly `decimals` fractional digits.
func baseToMajorString(base *big.Int, decimals int) string {
	if decimals <= 0 {
		return base.String()
	}
	div := new(big.Int).Exp(big.NewInt(10), big.NewInt(int64(decimals)), nil)
	q, r := new(big.Int).QuoRem(base, div, new(big.Int))
	return fmt.Sprintf("%s.%0*d", q.String(), decimals, r)
}
