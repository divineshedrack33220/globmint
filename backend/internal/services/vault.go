package services

import (
	"context"
	"errors"
	"fmt"
	"log"
	"math/big"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/domain/fees"
	"globmint/backend/internal/events"
	"globmint/backend/internal/infrastructure/blockchain"
	"globmint/backend/internal/observability"
	"globmint/backend/internal/storage"
)

// VaultConfig carries the on-chain + rate settings for the custodial personal
// vault. VaultAddress is the on-chain address users send USD deposits to; the
// backend holds its signer key, so it can detect inbound deposits and pay out
// withdraws to any address the user supplies.
type VaultConfig struct {
	VaultAddress       string
	VaultContract      string // on-chain vault contract; withdrawals to it are rejected
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
	// WithdrawElevationThresholdMinor: withdrawals above this amount (kobo) are
	// time-locked instead of broadcast immediately. 0 disables the elevation.
	WithdrawElevationThresholdMinor int64
	// WithdrawElevationDelay is how long an elevated withdrawal must wait before
	// the signer broadcasts it (default 24h).
	WithdrawElevationDelay time.Duration
	// WithdrawFeeBPS / WithdrawFeeMinMinor / WithdrawFeeCapMinor price the
	// withdrawal fee (kobo): fee = max(min(amount*bps/10000, cap), min).
	// bps = 0 disables fees. The fee is charged on top of the principal and
	// never counts toward the daily cap.
	WithdrawFeeBPS      int
	WithdrawFeeMinMinor int64
	WithdrawFeeCapMinor int64
	// PrivacyMode switches the vault to commitment-based balances. When true
	// the indexer credits deposits via the contract's privacy `DepositedPrivate`
	// events (resolved through keccak256(address, salt) and the user_salts
	// table) and never relies on a raw sender address. Env: GLOBMINT_PRIVACY_MODE.
	PrivacyMode bool
}

// indexerLeaderKey is the Postgres advisory-lock key that gates single-leader
// scanning across multiple indexer instances.
const indexerLeaderKey = int64(0x676C6F626D696E74) // "globmint"

// indexerWorkers is how many goroutines credit confirmed deposits in parallel.
// Per-user balance writes are serialized (see lockFor), so parallelism scales
// across users without corrupting any single ledger.
const indexerWorkers = 8

// WithdrawalResult is what a vault withdrawal call returns: either an executed
// transaction (immediate, below the elevation threshold) or a pending elevated
// withdrawal waiting for its time-lock.
type WithdrawalResult struct {
	Transaction *domain.Transaction
	TxHash      string
	Elevation   *domain.WithdrawalElevation
}

// VaultService runs the deposit indexer and executes withdrawals on the
// custodial vault. NGN<->USDC is converted using the seeded (USDT, NGN) rate.
type VaultService struct {
	store storage.Store
	chain blockchain.BlockchainService
	money *MoneyService
	cfg   VaultConfig
	// rate holds the NGN minor units per 1 USDC (kobo per USDC) atomically so
	// the market-rate refresher can update pricing without restarting or
	// racing the indexer/sweeper workers.
	rate atomic.Int64

	mu        sync.Mutex
	lastBlock uint64

	// cache of on-chain sender -> userID, refreshed per scan
	addressUser map[string]string

	// userLocks serializes ledger writes per user so parallel indexer workers
	// or concurrent withdrawals cannot lose a balance update.
	userLocks sync.Map // string -> *sync.Mutex

	// Hub pushes change notifications to the user's SSE subscribers; nil
	// disables push (tests/dev without a stream client).
	Hub *events.Hub
}

// NewVaultService builds the vault service. rateMinor is the NGN minor units
// per 1 USDC (i.e. the value 160450 for 1604.50 NGN/USDC); pass 0 to fall back
// to 160450. The rate can be refreshed live later via SetRateMinor.
func NewVaultService(store storage.Store, chain blockchain.BlockchainService, money *MoneyService, cfg VaultConfig, rateMinor int64) *VaultService {
	if rateMinor <= 0 {
		rateMinor = 160450
	}
	if cfg.PollInterval <= 0 {
		cfg.PollInterval = 8 * time.Second
	}
	if cfg.WithdrawElevationDelay <= 0 {
		cfg.WithdrawElevationDelay = 24 * time.Hour
	}
	v := &VaultService{
		store:       store,
		chain:       chain,
		money:       money,
		cfg:         cfg,
		lastBlock:   cfg.StartBlock,
		addressUser: map[string]string{},
	}
	v.rate.Store(rateMinor)
	return v
}

// SetRateMinor updates the live NGN-per-USDC conversion rate (kobo). It is
// called by the market-rate refresher; non-positive values are ignored so a
// bad feed can never zero out pricing.
func (v *VaultService) SetRateMinor(rateMinor int64) {
	if rateMinor > 0 {
		v.rate.Store(rateMinor)
	}
}

// currentRateMinor returns the live NGN minor units per 1 USDC.
func (v *VaultService) currentRateMinor() int64 {
	if r := v.rate.Load(); r > 0 {
		return r
	}
	return 160450
}

// lockFor returns the per-user serialization lock, creating it on first use.
func (v *VaultService) lockFor(userID string) *sync.Mutex {
	m, _ := v.userLocks.LoadOrStore(userID, &sync.Mutex{})
	return m.(*sync.Mutex)
}

// DepositAddress returns the on-chain address users send deposits to.
func (v *VaultService) DepositAddress() string { return v.cfg.VaultAddress }

// -------- Deposit indexer --------

// RunIndexer polls the chain for stablecoin transfers into the vault and
// credits the owning user's NGN balance for each new deposit. It runs until
// ctx is cancelled. Multiple instances can run safely: a Postgres advisory
// lock elects a single leader at a time, so only one instance scans/persists
// the cursor while the others stay ready to take over if the leader dies.
func (v *VaultService) RunIndexer(ctx context.Context) {
	if v.cfg.Mode == "mock" || v.cfg.VaultAddress == "" {
		log.Printf("vault indexer: disabled (mode=%s vault=%q)", v.cfg.Mode, v.cfg.VaultAddress)
		return
	}
	log.Printf("vault indexer: watching %s for %s deposits", v.cfg.VaultAddress, v.cfg.StablecoinSymbol)

	// Crash/restart resumption: start from the last confirmed block the
	// previous process persisted, never from the configured start block or a
	// half-way position a previous scans left in memory.
	if err := v.resumeCursor(ctx); err != nil {
		log.Printf("vault indexer: resume cursor: %v", err)
	}

	ticker := time.NewTicker(v.cfg.PollInterval)
	defer ticker.Stop()

	var leader bool
	var releaseLeader func()
	defer func() {
		if releaseLeader != nil {
			releaseLeader()
		}
	}()

	for {
		select {
		case <-ctx.Done():
			log.Println("vault indexer: stopped")
			return
		case <-ticker.C:
			// Acquire leadership lazily. Once held, we keep scanning until this
			// process dies (the advisory lock auto-releases with the session) or
			// ctx is cancelled.
			if !leader {
				rel, ok, err := v.store.TryAcquireIndexerLeadership(ctx, indexerLeaderKey)
				if err != nil {
					log.Printf("vault indexer: leadership check: %v", err)
					continue
				}
				if !ok {
					// Another instance is the leader; stay ready.
					continue
				}
				leader = true
				releaseLeader = rel
				log.Println("vault indexer: acquired leader lease")
			}
			if err := v.scan(ctx); err != nil {
				log.Printf("vault indexer: scan error: %v", err)
			}
		}
	}
}

// resumeCursor loads the persisted scan cursor (indexer_state) so a restart
// continues where the last process left off instead of trusting the in-memory
// position.
func (v *VaultService) resumeCursor(ctx context.Context) error {
	stored, err := v.store.IndexerStateRepo().LastBlock(ctx)
	if err != nil {
		return err
	}
	if stored > 0 {
		v.mu.Lock()
		v.lastBlock = stored
		v.mu.Unlock()
		log.Printf("vault indexer: resumed from stored cursor %d", stored)
	}
	return nil
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
	v.mu.Unlock()
	// On the very first run (no persisted cursor yet), take the current head as
	// the baseline: skip pre-existing history, persist it, and only watch
	// blocks mined from now on.
	if scanFrom == 0 {
		if latest > 0 {
			v.mu.Lock()
			v.lastBlock = latest
			v.mu.Unlock()
			if err := v.store.IndexerStateRepo().SetLastBlock(ctx, latest); err != nil {
				log.Printf("vault indexer: persist baseline cursor: %v", err)
			}
		}
		return nil
	}
	if confirmedHead < scanFrom {
		return nil
	}
	toBlock := confirmedHead

	tsf, err := v.chain.FilterTokenTransfers(ctx, scanFrom, toBlock, v.cfg.VaultAddress)
	if err != nil {
		return err
	}

	// Privacy mode credits deposits from the vault's own `DepositedPrivate`
	// events (which carry only a keccak256(user, salt) commitment) instead of
	// raw USDC transfers, so senders never need to be linked wallet addresses.
	vaultDeposits, err := v.chain.FilterVaultDeposits(ctx, scanFrom, toBlock, v.cfg.VaultContract)
	if err != nil {
		return err
	}

	// Confirmations are per-block: the cursor advances past the highest block
	// that produced a confirmed event (or the full window when none did).
	newCursor := scanFrom
	for _, t := range tsf {
		if t.BlockNumber >= newCursor {
			newCursor = t.BlockNumber + 1
		}
	}
	for _, d := range vaultDeposits {
		if d.BlockNumber >= newCursor {
			newCursor = d.BlockNumber + 1
		}
	}
	// Credit deposits in parallel: independent users are processed by up to
	// indexerWorkers goroutines, and per-user ledger writes are serialized.
	v.processTransfers(ctx, tsf)
	if v.cfg.PrivacyMode {
		v.processVaultDeposits(ctx, vaultDeposits)
	}

	advanced := false
	v.mu.Lock()
	if newCursor > v.lastBlock {
		v.lastBlock = newCursor
		advanced = true
	}
	v.mu.Unlock()

	// Persist the cursor only after the batch is processed, so a crash mid-batch
	// re-scans the window and the deposit handler's tx-hash idempotency dedupes
	// exactly-once.
	if advanced {
		if err := v.store.IndexerStateRepo().SetLastBlock(ctx, newCursor); err != nil {
			log.Printf("vault indexer: persist cursor: %v", err)
		}
	}
	observability.Default.SetIndexerLag(int64(latest) - int64(newCursor))
	return nil
}

// processTransfers fans confirmed transfers out to a bounded worker pool so
// credits for different users happen concurrently. handleDeposit serializes
// per-user writes internally.
func (v *VaultService) processTransfers(ctx context.Context, transfers []blockchain.TokenTransfer) {
	if len(transfers) == 0 {
		return
	}
	workers := indexerWorkers
	if len(transfers) < workers {
		workers = len(transfers)
	}
	jobs := make(chan blockchain.TokenTransfer, len(transfers))
	var wg sync.WaitGroup
	for i := 0; i < workers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for t := range jobs {
				if err := v.handleDeposit(ctx, t); err != nil {
					log.Printf("vault indexer: deposit %s ignored: %v", t.TxHash, err)
				}
			}
		}()
	}
	for _, t := range transfers {
		jobs <- t
	}
	close(jobs)
	wg.Wait()
}

// processVaultDeposits fans confirmed privacy-mode vault deposits out to the
// worker pool. Only commitment-resolved events (those reaching a user) are
// credited; unlinked commitments are ignored, never credited to a fallback.
func (v *VaultService) processVaultDeposits(ctx context.Context, deposits []blockchain.VaultDeposit) {
	if len(deposits) == 0 {
		return
	}
	commitments, err := v.commitmentUserMap(ctx)
	if err != nil {
		log.Printf("vault indexer: load commitment map: %v", err)
		return
	}
	workers := indexerWorkers
	if len(deposits) < workers {
		workers = len(deposits)
	}
	jobs := make(chan blockchain.VaultDeposit, len(deposits))
	var wg sync.WaitGroup
	for i := 0; i < workers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for d := range jobs {
				if err := v.handleVaultDeposit(ctx, d, commitments); err != nil {
					log.Printf("vault indexer: vault deposit %s ignored: %v", d.TxHash, err)
				}
			}
		}()
	}
	for _, d := range deposits {
		jobs <- d
	}
	close(jobs)
	wg.Wait()
}

// commitmentUserMap builds keccak256(address, salt) -> userID for every user
// with a stored salt and a linked deposit address, so privacy-mode deposits can
// be resolved without any raw-address lookup by external observers.
func (v *VaultService) commitmentUserMap(ctx context.Context) (map[string]string, error) {
	links, err := v.store.UserSaltsRepo().ListLinks(ctx)
	if err != nil {
		return nil, err
	}
	m := make(map[string]string, len(links))
	for _, l := range links {
		if l.Address == "" || len(l.Salt) == 0 {
			continue
		}
		m[vaultCommitment(l.Address, l.Salt)] = l.UserID
	}
	return m, nil
}

// vaultCommitment reproduces the contract's commitment
// keccak256(abi.encodePacked(address, salt)) with the stored 16-byte salt
// right-aligned into the 32-byte word (uint256 semantics). This is the exact
// encoding the backend's salt-aware deposit path uses on-chain.
func vaultCommitment(address string, salt []byte) string {
	addr := common.HexToAddress(address)
	word := make([]byte, 32)
	copy(word[32-len(salt):], salt)
	return crypto.Keccak256Hash(addr.Bytes(), word).Hex()
}

// handleVaultDeposit credits the NGN balance of the user whose deposit
// commitment resolves through the vault's privacy event. Legacy events (raw
// user present) are resolved through the deposit-address link. Unlinked
// commitments are never credited to a fallback user — doing so would risk
// crediting the wrong account.
func (v *VaultService) handleVaultDeposit(ctx context.Context, d blockchain.VaultDeposit, commitments map[string]string) error {
	if d.Amount == nil || d.Amount.Sign() <= 0 {
		return nil
	}
	userID := ""
	if d.User != "" {
		var err error
		userID, err = v.senderUserID(ctx, d.User)
		if err != nil {
			return err
		}
	} else {
		userID = commitments[d.Commitment]
	}
	if userID == "" {
		return errors.New("commitment not linked to a user")
	}

	if err := v.store.IndexerEventRepo().Insert(ctx, &domain.IndexerEvent{
		TxHash:      d.TxHash,
		LogIndex:    d.LogIndex,
		BlockNumber: d.BlockNumber,
		EventType:   "deposited",
		From:        d.Commitment,
		To:          v.cfg.VaultContract,
		ValueBase:   d.Amount.Int64(),
	}); err != nil {
		log.Printf("vault indexer: event log write failed: %v", err)
	}

	ngnMinor := depositNGNMinor(d.Amount, v.currentRateMinor())
	if ngnMinor <= 0 {
		return errors.New("deposit value below resolution")
	}

	lock := v.lockFor(userID)
	lock.Lock()
	defer lock.Unlock()

	// Distinct key from the transfer path so the two never collide on the same
	// deposit. tx hash + log index keeps privacy guarantees intact.
	key := "vault-deposit-vault-" + d.TxHash + ":" + fmt.Sprint(d.LogIndex)
	if _, err := v.money.Deposit(ctx, userID, "NGN", ngnMinor, key); err != nil {
		if errors.Is(err, domain.ErrConflict) {
			return nil
		}
		return err
	}
	if v.Hub != nil {
		v.Hub.Publish(events.Event{
			Type: "data.changed", UserID: userID, Kind: "all",
			At: time.Now().UTC().Format(time.RFC3339),
		})
	}
	log.Printf("vault indexer: credited %d kobo to %s (vault deposit %s, %s USDC)",
		ngnMinor, userID, d.TxHash, baseToMajorString(d.Amount, v.cfg.StablecoinDecimals))
	return nil
}

// handleDeposit credits the NGN balance of the user whose linked wallet (the
// transfer sender) sent USDC into the vault. Duplicate tx hashes are ignored.
// The event is first written to the durable indexer_events log (idempotent),
// then credited under a per-user lock so parallel workers cannot lose writes.
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

	// Durable, replayable event log (write-ahead for idempotency + audit).
	if err := v.store.IndexerEventRepo().Insert(ctx, &domain.IndexerEvent{
		TxHash:      t.TxHash,
		LogIndex:    t.LogIndex,
		BlockNumber: t.BlockNumber,
		EventType:   "deposited",
		From:        t.From,
		To:          t.To,
		ValueBase:   t.Value.Int64(),
	}); err != nil {
		log.Printf("vault indexer: event log write failed: %v", err)
	}

	ngnMinor := depositNGNMinor(t.Value, v.currentRateMinor())
	if ngnMinor <= 0 {
		return errors.New("deposit value below resolution")
	}

	// Serialize ledger writes per user (credit reads balance, then sets it).
	lock := v.lockFor(userID)
	lock.Lock()
	defer lock.Unlock()

	// Idempotent by tx hash so rescans never double-credit.
	key := "vault-deposit-" + t.TxHash
	if _, err := v.money.Deposit(ctx, userID, "NGN", ngnMinor, key); err != nil {
		if errors.Is(err, domain.ErrConflict) {
			// Replay of an already-credited deposit (crash mid-batch rescan).
			return nil
		}
		return err
	}
	if v.Hub != nil {
		v.Hub.Publish(events.Event{
			Type: "data.changed", UserID: userID, Kind: "all",
			At: time.Now().UTC().Format(time.RFC3339),
		})
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

// withdrawalFee prices the withdrawal fee for a principal of amountNgnMinor
// kobo using the configured schedule (0 when fees are disabled).
func (v *VaultService) withdrawalFee(amountNgnMinor int64) int64 {
	return fees.ComputeWithdrawalFee(amountNgnMinor, int64(v.cfg.WithdrawFeeBPS), v.cfg.WithdrawFeeMinMinor, v.cfg.WithdrawFeeCapMinor)
}

// WithdrawToAddress converts `amountNgnMinor` kobo to USDC at the vault rate,
// debits the user's NGN available balance (principal + fee), and sends the
// USDC on-chain from the vault to `destination`. The on-chain tx hash is
// stored as the provider ref.
//
// Withdrawals above WithdrawElevationThresholdMinor are time-locked instead:
// the call returns a pending elevation and nothing leaves the vault until the
// delay has passed (see RunElevationSweeper). The user can cancel meanwhile,
// in which case no fee is ever charged.
func (v *VaultService) WithdrawToAddress(ctx context.Context, userID, destination string, amountNgnMinor int64, key string) (*WithdrawalResult, error) {
	if v.cfg.Mode == "mock" || v.cfg.VaultAddress == "" {
		// Surface as a proper 403, not a 500: this deployment cannot move
		// funds on-chain by configuration, nothing is broken.
		return nil, domain.ErrFeatureDisabled
	}
	if !v.cfg.WithdrawEnabled {
		return nil, domain.ErrFeatureDisabled
	}
	if amountNgnMinor <= 0 {
		return nil, domain.ErrInvalidAmount
	}
	// Never send to our own addresses: a withdrawal to the vault (or its
	// contract) would loop funds in a circle while still charging the user
	// the ledger debit + fee. The app also warns, this is the safety net.
	if strings.EqualFold(destination, v.cfg.VaultAddress) ||
		(v.cfg.VaultContract != "" && strings.EqualFold(destination, v.cfg.VaultContract)) {
		return nil, domain.ErrInvalidAddress
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
		// The cap counts the principal only: SumWithdrawalsSince sums
		// amount_minor, and the fee lives separately in fee_minor.
		if used+amountNgnMinor > v.cfg.WithdrawDailyCapMinor {
			return nil, domain.ErrLimitExceeded
		}
	}

	fee := v.withdrawalFee(amountNgnMinor)

	// High-value withdrawals wait out the time-lock before broadcasting.
	if v.cfg.WithdrawElevationThresholdMinor > 0 && amountNgnMinor > v.cfg.WithdrawElevationThresholdMinor {
		return v.requestElevation(ctx, userID, destination, amountNgnMinor, fee, key)
	}

	txn, err := v.executeWithdrawal(ctx, userID, destination, amountNgnMinor, fee, key)
	if err != nil {
		return nil, err
	}
	return &WithdrawalResult{Transaction: txn, TxHash: txn.ProviderRef}, nil
}

// requestElevation creates (or returns) the pending time-locked withdrawal for
// this user/destination/amount. Idempotent: an identical pending elevation is
// returned instead of duplicated. No funds move here — the fee is stored on
// the row and only debited when the sweeper broadcasts.
func (v *VaultService) requestElevation(ctx context.Context, userID, destination string, amountNgnMinor, feeMinor int64, key string) (*WithdrawalResult, error) {
	if existing, err := v.store.ElevationRepo().FindPendingByContent(ctx, userID, destination, amountNgnMinor); err == nil && existing != nil {
		return &WithdrawalResult{Elevation: existing}, nil
	}
	// Reject doomed time-locks upfront: the sweep will debit principal + fee,
	// so there is no point holding a withdrawal the user cannot cover.
	suff, err := v.hasSufficientNGN(ctx, userID, amountNgnMinor+feeMinor)
	if err != nil {
		return nil, err
	}
	if !suff {
		return nil, domain.ErrInsufficientBalance
	}
	now := time.Now().UTC()
	e := &domain.WithdrawalElevation{
		UserID:         userID,
		Destination:    destination,
		AmountNgnMinor: amountNgnMinor,
		FeeMinor:       feeMinor,
		Status:         domain.ElevationPending,
		RequestedAt:    now,
		ReleaseAfter:   now.Add(v.cfg.WithdrawElevationDelay),
		IdempotencyKey: key,
	}
	if created, err := v.store.ElevationRepo().Create(ctx, e); err != nil {
		// Concurrent duplicate request: the unique pending index fired, so
		// return the row the other request created.
		if existing, findErr := v.store.ElevationRepo().FindPendingByContent(ctx, userID, destination, amountNgnMinor); findErr == nil && existing != nil {
			return &WithdrawalResult{Elevation: existing}, nil
		}
		return nil, err
	} else {
		e = created
	}
	if v.Hub != nil {
		v.Hub.Publish(events.Event{
			Type: "data.changed", UserID: userID, Kind: "all",
			At: time.Now().UTC().Format(time.RFC3339),
		})
	}
	return &WithdrawalResult{Elevation: e}, nil
}

// executeWithdrawal runs the immutable broadcast-then-debit sequence shared by
// immediate withdrawals and by the elevation sweeper. The user pays principal
// + fee (debited atomically, fee settled to the platform account); only the
// principal is converted to USDC and broadcast. The NGN balance is
// pre-checked (inside the ledger transaction too) before any gas is spent.
func (v *VaultService) executeWithdrawal(ctx context.Context, userID, destination string, amountNgnMinor, feeMinor int64, key string) (*domain.Transaction, error) {
	// Replay protection: if this idempotency key already produced a
	// withdrawal, return the recorded transaction without touching the chain.
	if key != "" {
		if existing, err := v.store.LedgerRepo().FindTransactionByIDempotencyKey(ctx, key); err == nil && existing != nil {
			return existing, nil
		}
	}

	// Pre-check sufficiency (principal + fee) before spending gas on the
	// chain broadcast.
	suff, err := v.hasSufficientNGN(ctx, userID, amountNgnMinor+feeMinor)
	if err != nil {
		return nil, err
	}
	if !suff {
		return nil, domain.ErrInsufficientBalance
	}

	usdcBase := withdrawUSDCBase(amountNgnMinor, v.currentRateMinor())
	if usdcBase <= 0 {
		return nil, domain.ErrInvalidAmount
	}

	// Broadcast the on-chain transfer first (it may fail on insufficient funds).
	major := baseToMajorString(big.NewInt(usdcBase), v.cfg.StablecoinDecimals)
	txHash, err := v.chain.TransferToken(ctx, destination, major)
	if err != nil {
		observability.Default.WithdrawalFailure("broadcast")
		return nil, fmt.Errorf("on-chain send failed: %w", err)
	}

	// Debit NGN after the chain send succeeds: principal + fee, with the fee
	// settled to the platform account in the same atomic transaction.
	txn, err := v.money.WithdrawExternal(ctx, LedgerMoveRequest{
		UserID:         userID,
		AccountKind:    domain.AccountKindAvailable,
		Currency:       "NGN",
		Type:           domain.TransactionTypeWithdrawal,
		AmountMinor:    amountNgnMinor,
		FeeMinor:       feeMinor,
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
		observability.Default.WithdrawalFailure("ledger")
		return nil, fmt.Errorf("on-chain sent (%s) but ledger debit failed: %w", txHash, err)
	}
	observability.Default.Withdrawal()
	// Inbox: the user asked to be told whenever money arrives or leaves.
	v.money.notify(ctx, userID, domain.NotificationCategoryWithdrawal,
		"Withdrawal broadcast",
		formatMinor(amountNgnMinor, "NGN")+" (≈"+major+" USDC) sent to "+shortAddress(destination)+".")
	if v.Hub != nil {
		v.Hub.Publish(events.Event{
			Type: "data.changed", UserID: userID, Kind: "all",
			At: time.Now().UTC().Format(time.RFC3339),
		})
	}
	return txn, nil
}

// hasSufficientNGN reports whether the user's available NGN balance covers a
// total debit of totalMinor kobo (principal + fee for withdrawals).
func (v *VaultService) hasSufficientNGN(ctx context.Context, userID string, amountNgnMinor int64) (bool, error) {
	acc, err := v.store.AccountRepo().FindByUserAndKind(ctx, userID, domain.AccountKindAvailable, "NGN")
	if err != nil {
		return false, err
	}
	bal, err := v.store.LedgerRepo().SumBalanceByAccount(ctx, acc.ID)
	if err != nil {
		return false, err
	}
	return bal >= amountNgnMinor, nil
}

// shortAddress renders 0x1234…abcd for inbox display.
func shortAddress(address string) string {
	if len(address) <= 12 {
		return address
	}
	return address[:6] + "…" + address[len(address)-4:]
}

// WithdrawLimits describes the operator-configured withdrawal guards.
type WithdrawLimits struct {
	MinMinor       int64
	MaxMinor       int64
	DailyCapMinor  int64
	ThresholdMinor int64
	// ElevationDelaySeconds is how long an elevated withdrawal waits before
	// broadcast (0 when the time-lock is disabled).
	ElevationDelaySeconds int64
}

// WithdrawLimits exposes the withdrawal guards so clients can display them
// (daily-cap usage, time-lock threshold) before submission.
func (v *VaultService) WithdrawLimits() WithdrawLimits {
	return WithdrawLimits{
		MinMinor:              v.cfg.WithdrawMinMinor,
		MaxMinor:              v.cfg.WithdrawMaxMinor,
		DailyCapMinor:         v.cfg.WithdrawDailyCapMinor,
		ThresholdMinor:        v.cfg.WithdrawElevationThresholdMinor,
		ElevationDelaySeconds: int64(v.cfg.WithdrawElevationDelay / time.Second),
	}
}

// FindElevation returns a user's elevation by id (for the cancel/list APIs).
func (v *VaultService) FindElevation(ctx context.Context, userID, id string) (*domain.WithdrawalElevation, error) {
	return v.store.ElevationRepo().FindByUserAndID(ctx, userID, id)
}

// ListPendingElevations returns the user's time-locked withdrawals.
func (v *VaultService) ListPendingElevations(ctx context.Context, userID string) ([]domain.WithdrawalElevation, error) {
	return v.store.ElevationRepo().ListPendingByUser(ctx, userID)
}

// CancelElevation cancels a pending time-locked withdrawal before it is due.
func (v *VaultService) CancelElevation(ctx context.Context, userID, id string) error {
	return v.store.ElevationRepo().CancelPending(ctx, userID, id)
}

// RunElevationSweeper releases due time-locked withdrawals: once a pending
// elevation's release_after passes, the sweep broadcasts it (exactly once via
// the claim) and debits the ledger. It also publishes signer-balance + lag
// metrics for monitoring.
func (v *VaultService) RunElevationSweeper(ctx context.Context) {
	if v.cfg.WithdrawElevationThresholdMinor <= 0 {
		return
	}
	ticker := time.NewTicker(v.cfg.PollInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			log.Println("elevation sweeper: stopped")
			return
		case <-ticker.C:
			v.updateSignerBalanceMetric(ctx)
			if err := v.sweepDueElevations(ctx); err != nil {
				log.Printf("elevation sweeper: %v", err)
			}
		}
	}
}

// sweepDueElevations broadcasts every due pending elevation. The atomic claim
// guarantees exactly one broadcaster even when several instances sweep.
func (v *VaultService) sweepDueElevations(ctx context.Context) error {
	if !v.cfg.WithdrawEnabled {
		return nil
	}
	due, err := v.store.ElevationRepo().FindDuePending(ctx, time.Now().UTC())
	if err != nil {
		return err
	}
	for _, e := range due {
		claimed, err := v.store.ElevationRepo().ClaimForBroadcast(ctx, e.ID)
		if err != nil {
			log.Printf("elevation sweeper: claim %s: %v", e.ID, err)
			continue
		}
		if !claimed {
			continue // another instance won the claim
		}
		txn, err := v.executeWithdrawal(ctx, e.UserID, e.Destination, e.AmountNgnMinor, e.FeeMinor, e.IdempotencyKey)
		if err != nil {
			log.Printf("elevation sweeper: release %s failed: %v", e.ID, err)
			observability.Default.WithdrawalFailure("elevation")
			_ = v.store.ElevationRepo().ReleaseClaim(ctx, e.ID) // retry next sweep
			continue
		}
		if err := v.store.ElevationRepo().MarkBroadcast(ctx, e.ID, txn.ProviderRef); err != nil {
			log.Printf("elevation sweeper: mark %s broadcast: %v", e.ID, err)
		}
		if v.Hub != nil {
			v.Hub.Publish(events.Event{
				Type: "data.changed", UserID: e.UserID, Kind: "all",
				At: time.Now().UTC().Format(time.RFC3339),
			})
		}
	}
	return nil
}

// updateSignerBalanceMetric refreshes the signer-balance gauge used by the
// monitoring dashboard to alert on a nearly-empty signer wallet.
func (v *VaultService) updateSignerBalanceMetric(ctx context.Context) {
	if v.cfg.Mode == "mock" || v.cfg.VaultAddress == "" {
		return
	}
	bal, err := v.chain.GetTokenBalance(ctx, v.cfg.VaultAddress)
	if err != nil {
		return
	}
	if f, ok := parseMajorFloat(bal); ok {
		observability.Default.SetSignerBalance(f)
	}
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

// parseMajorFloat extracts the leading decimal number from a balance render
// like "8.500000 USDC" (used to feed the signer-balance gauge).
func parseMajorFloat(s string) (float64, bool) {
	num := strings.TrimSpace(s)
	if i := strings.IndexByte(num, ' '); i >= 0 {
		num = num[:i]
	}
	if num == "NaN" || num == "+Inf" || num == "-Inf" || num == "" {
		return 0, false
	}
	var f float64
	if _, err := fmt.Sscanf(num, "%g", &f); err != nil {
		return 0, false
	}
	return f, true
}
