package blockchain

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"math/big"
	"strings"
	"sync"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"

	"globmint/backend/internal/eip712"
)

// TokenTransfer is a decoded stablecoin Transfer event.
type TokenTransfer struct {
	From        string
	To          string
	Value       *big.Int // raw base units (e.g. 6 decimals)
	TxHash      string
	LogIndex    uint64
	BlockNumber uint64
}

// VaultDeposit is a decoded GlobmintVault deposit event. It carries either a
// raw user address (the legacy `Deposited(bytes32,address,uint256)` event,
// emitted when privacy mode is OFF) or only a keccak256(user, salt) commitment
// (the privacy `DepositedPrivate(bytes32,uint256)` event). In privacy mode the
// User field is "" and the indexer must resolve the commitment via the
// user_salts table.
type VaultDeposit struct {
	Commitment  string // keccak256(user, salt); always present for both variants
	User        string // raw user address (legacy mode); "" in privacy mode
	Amount      *big.Int
	TxHash      string
	LogIndex    uint64
	BlockNumber uint64
}

// WithdrawSignature is an EIP-712 signature broken into the (v, r, s) parts the
// clone contract's withdrawWithSig accepts. v is normalized to 27/28.
type WithdrawSignature struct {
	V uint8
	R [32]byte
	S [32]byte
}

// WithdrawRelay is a fully-built withdrawWithSig call ready to broadcast: the
// destination, the base-unit amount, the exact nonce + deadline the signature
// covers, and the signature itself.
type WithdrawRelay struct {
	Clone    string
	To       string
	Amount   *big.Int // stablecoin base units
	Nonce    uint64
	Deadline int64
	Sig      WithdrawSignature
}

// BlockchainService defines the interface for blockchain operations.
type BlockchainService interface {
	GetBalance(ctx context.Context, address string) (string, error)
	GetTokenBalance(ctx context.Context, address string) (string, error)
	GetTransaction(ctx context.Context, txHash string) (string, error)
	WaitForConfirmation(ctx context.Context, txHash string, confirmations int) (string, error)
	TransferToken(ctx context.Context, recipient string, amount string) (string, error)
	// VaultAddress returns the on-chain address users send deposits to. Empty in
	// mock mode (no signer configured).
	VaultAddress() string
	// PredictClone computes the CREATE2 address the vault factory will deploy for
	// `userKey` WITHOUT broadcasting anything. userKey is a per-account bytes32
	// (e.g. keccak256(userID)) so every account's clone is unique even before
	// it has its own wallet. Deterministic per key.
	PredictClone(ctx context.Context, userKey string) (string, error)
	// CloneByUserKey resolves the deployed clone address for `userKey`, or ""
	// when no clone has been deployed for it yet.
	CloneByUserKey(ctx context.Context, userKey string) (string, error)
	// DeployClone deploys (or finds) the per-user vault clone for `userKey` and
	// returns the broadcast tx hash and the clone address. `owner` is the clone
	// owner seat: the user's linked wallet, or the platform signer as a
	// placeholder the user can later claim.
	DeployClone(ctx context.Context, userKey, owner string) (txHash, cloneAddr string, err error)
	// CloneFactoryAddress returns the configured vault clone factory address, or
	// "" when none is configured.
	CloneFactoryAddress() string
	// FilterTokenTransfers returns decoded stablecoin Transfer events from
	// `fromBlock`..`toBlock` (inclusive) where `to` equals `address` (or all
	// addresses when `address` is empty).
	FilterTokenTransfers(ctx context.Context, fromBlock, toBlock uint64, address string) ([]TokenTransfer, error)
	// FilterVaultDeposits returns decoded GlobmintVault deposit events from the
	// given vault contract over a block range. Both the privacy-mode event
	// (`DepositedPrivate(bytes32 indexed commitment, uint256 amount)`) and the
	// legacy event (`Deposited(bytes32 indexed commitment, address indexed
	// user, uint256 amount)`) are decoded. Callers resolve commitments to users
	// when the event carries no raw address.
	FilterVaultDeposits(ctx context.Context, fromBlock, toBlock uint64, vaultContract string) ([]VaultDeposit, error)
	// LatestBlock returns the current head block number.
	LatestBlock(ctx context.Context) (uint64, error)

	// CloneOwner returns the clone's owner seat (`ownerOfThis()`): the user's
	// wallet once they take custody, or the platform signer as a placeholder.
	CloneOwner(ctx context.Context, cloneAddress string) (string, error)
	// CloneNonce returns the clone's next EIP-712 withdrawal nonce.
	CloneNonce(ctx context.Context, cloneAddress string) (uint64, error)
	// SignWithdrawRelay signs a withdrawWithSig request with the platform
	// signer key. This is the TRANSITIONAL placeholder-owner path: used only
	// while a clone is still owned by the platform signer and
	// GLOBMINT_REQUIRE_USER_SIGNATURE is not yet enforced. Once a user claims
	// their clone, only their own wallet signature is accepted.
	SignWithdrawRelay(ctx context.Context, chainID int64, clone, to string, amountBase *big.Int, nonce uint64, deadline int64) (WithdrawSignature, error)
	// WithdrawFromCloneWithSig relays a pre-signed EIP-712 withdrawWithSig
	// call on the clone (the signer pays gas; the signature authorizes the
	// transfer). Returns the broadcast tx hash. The clone contract verifies
	// the signature recovers to the clone owner.
	WithdrawFromCloneWithSig(ctx context.Context, relay WithdrawRelay) (string, error)
}

// ---------- Mock ----------

// MockBlockchainService is a mock implementation for development/testing. It
// is controllable: SetLatest advances the head block, AddTransfer seeds events,
// and SetError injects RPC failures for chaos/fault tests.
type MockBlockchainService struct {
	mu       sync.Mutex
	balances map[string]string
	transfers []TokenTransfer
	vaultDeposits []VaultDeposit
	clones    map[string]string // owner(+predicted) -> deployed clone addr
	cloneOwners map[string]string // clone addr -> owner seat ("" = unverified)
	cloneNonces map[string]uint64
	latest    uint64
	headErr   error
	filterErr error
	relayErr  error
	cloneFactory string
	// relays records every withdrawWithSig relay the mock accepted, for tests.
	relays []WithdrawRelay
}

// ---------- Mock ----------

// NewMockBlockchainService creates a new mock blockchain service.
func NewMockBlockchainService() *MockBlockchainService {
	return &MockBlockchainService{
		balances:    make(map[string]string),
		clones:      make(map[string]string),
		cloneOwners: make(map[string]string),
		cloneNonces: make(map[string]uint64),
	}
}

// SetCloneFactory records the factory address the mock reports via
// CloneFactoryAddress (mock-only, for tests/ops).
func (m *MockBlockchainService) SetCloneFactory(addr string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.cloneFactory = addr
}

// SetClone seeds a deployed clone for a user key (mock-only, for tests).
// CloneByUserKey/DeployClone will then return it.
func (m *MockBlockchainService) SetClone(userKey string) string {
	m.mu.Lock()
	defer m.mu.Unlock()
	predicted, _ := mockPredictClone(userKey)
	m.clones[userKey] = predicted
	return predicted
}

// SetLatest sets the head block the mock reports (mock-only, for tests).
func (m *MockBlockchainService) SetLatest(n uint64) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.latest = n
}

// SetHeadError injects a failure on the next LatestBlock call; pass nil to clear.
func (m *MockBlockchainService) SetHeadError(err error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.headErr = err
}

// SetFilterError injects a failure on FilterTokenTransfers; pass nil to clear.
func (m *MockBlockchainService) SetFilterError(err error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.filterErr = err
}

// GetBalance returns a mock balance.
func (m *MockBlockchainService) GetBalance(ctx context.Context, address string) (string, error) {
	if b, ok := m.balances[address]; ok {
		return b, nil
	}
	return "0", nil
}

// GetTokenBalance returns a mock token balance.
func (m *MockBlockchainService) GetTokenBalance(ctx context.Context, address string) (string, error) {
	if b, ok := m.balances[address]; ok {
		return b, nil
	}
	return "0", nil
}

// GetTransaction returns mock transaction details.
func (m *MockBlockchainService) GetTransaction(ctx context.Context, txHash string) (string, error) {
	return fmt.Sprintf(`{"hash":"%s","from":"0x0000000000000000000000000000000000000000","to":"0x0000000000000000000000000000000000000000","value":"0x0"}`, txHash), nil
}

// WaitForConfirmation waits for confirmations.
func (m *MockBlockchainService) WaitForConfirmation(ctx context.Context, txHash string, confirmations int) (string, error) {
	return fmt.Sprintf(`{"status":"success","confirmations":%d}`, confirmations), nil
}

// TransferToken returns a synthetic hash without broadcasting.
func (m *MockBlockchainService) TransferToken(ctx context.Context, recipient string, amount string) (string, error) {
	txHash := "0x" + fmt.Sprintf("%064x", time.Now().UnixNano())
	return txHash, nil
}

// VaultAddress returns empty in mock mode (no signer configured).
func (m *MockBlockchainService) VaultAddress() string { return "" }

// CloneFactoryAddress returns the configured factory address ("" if unset).
func (m *MockBlockchainService) CloneFactoryAddress() string {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.cloneFactory
}

// mockPredictClone derives a deterministic pseudo-address for a user key,
// mirroring the factory's CREATE2 determinism for tests.
func mockPredictClone(userKey string) (string, error) {
	hash := crypto.Keccak256Hash([]byte("globmint:vaultclone:" + userKey))
	return common.BytesToAddress(hash.Bytes()[12:]).Hex(), nil
}

// PredictClone returns the deterministic pseudo-address for `userKey` (mock).
func (m *MockBlockchainService) PredictClone(ctx context.Context, userKey string) (string, error) {
	return mockPredictClone(userKey)
}

// CloneByUserKey returns the deployed clone for `userKey`, or "" when none was
// seeded via SetClone (mock).
func (m *MockBlockchainService) CloneByUserKey(ctx context.Context, userKey string) (string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.clones[userKey], nil
}

// DeployClone seeds the user key's clone and returns (txHash, cloneAddr) (mock).
func (m *MockBlockchainService) DeployClone(ctx context.Context, userKey, owner string) (string, string, error) {
	addr, err := mockPredictClone(userKey)
	if err != nil {
		return "", "", err
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	m.clones[userKey] = addr
	if owner != "" {
		m.cloneOwners[strings.ToLower(addr)] = strings.ToLower(owner)
	}
	return "0x" + fmt.Sprintf("%064x", time.Now().UnixNano()), addr, nil
}

// SetCloneOwner seeds the owner seat for a clone address (mock-only, for
// tests). The default (unset) owner is "" which the mock treats as
// "skip ownership verification", mirroring pre-clone legacy tests.
func (m *MockBlockchainService) SetCloneOwner(cloneAddr, owner string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.cloneOwners[strings.ToLower(cloneAddr)] = strings.ToLower(owner)
}

// SetCloneNonce seeds the next withdrawal nonce for a clone (mock-only).
func (m *MockBlockchainService) SetCloneNonce(cloneAddr string, nonce uint64) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.cloneNonces[strings.ToLower(cloneAddr)] = nonce
}

// SetRelayError injects a failure on the next WithdrawFromCloneWithSig call;
// pass nil to clear (mock-only).
func (m *MockBlockchainService) SetRelayError(err error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.relayErr = err
}

// Relays returns every withdrawWithSig relay the mock accepted (mock-only).
func (m *MockBlockchainService) Relays() []WithdrawRelay {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := make([]WithdrawRelay, len(m.relays))
	copy(out, m.relays)
	return out
}

// CloneOwner returns the seeded owner seat for a clone, or "" (unset).
func (m *MockBlockchainService) CloneOwner(ctx context.Context, cloneAddress string) (string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.cloneOwners[strings.ToLower(cloneAddress)], nil
}

// CloneNonce returns the seeded nonce for a clone (0 by default).
func (m *MockBlockchainService) CloneNonce(ctx context.Context, cloneAddress string) (uint64, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.cloneNonces[strings.ToLower(cloneAddress)], nil
}

// SignWithdrawRelay returns a deterministic (but not cryptographically valid)
// dummy signature: the mock has no signing key and the service is expected to
// skip verification for unset owners.
func (m *MockBlockchainService) SignWithdrawRelay(ctx context.Context, chainID int64, clone, to string, amountBase *big.Int, nonce uint64, deadline int64) (WithdrawSignature, error) {
	payload := fmt.Sprintf("mock-sig:%s:%s:%s:%d:%d", clone, to, amountBase, nonce, deadline)
	hash := crypto.Keccak256Hash([]byte(payload))
	var r, s [32]byte
	copy(r[:], hash.Bytes()[:32])
	copy(s[:], hash.Bytes()[:32])
	return WithdrawSignature{V: 27, R: r, S: s}, nil
}

// WithdrawFromCloneWithSig records the relay and returns a synthetic hash.
// Signature verification is the vault service's job (off-chain, before the
// broadcast): the mock records the exact relay, bumps the nonce, and lets
// tests assert what would have moved on chain. SetRelayError injects failures.
func (m *MockBlockchainService) WithdrawFromCloneWithSig(ctx context.Context, relay WithdrawRelay) (string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.relayErr != nil {
		return "", m.relayErr
	}
	key := strings.ToLower(strings.TrimSpace(relay.Clone))
	m.cloneNonces[key] = relay.Nonce + 1
	m.relays = append(m.relays, relay)
	return "0x" + fmt.Sprintf("%064x", time.Now().UnixNano()), nil
}

// FilterTokenTransfers returns any transfers seeded via AddTransfer for tests.
func (m *MockBlockchainService) FilterTokenTransfers(ctx context.Context, fromBlock, toBlock uint64, address string) ([]TokenTransfer, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.filterErr != nil {
		return nil, m.filterErr
	}
	var out []TokenTransfer
	for _, t := range m.transfers {
		if t.BlockNumber >= fromBlock && t.BlockNumber <= toBlock {
			if address == "" || t.To == address {
				out = append(out, t)
			}
		}
	}
	return out, nil
}

// AddTransfer seeds a synthetic Transfer event (mock-only, for tests).
func (m *MockBlockchainService) AddTransfer(t TokenTransfer) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.transfers = append(m.transfers, t)
}

// AddVaultDeposit seeds a synthetic GlobmintVault deposit event (mock-only, for
// tests). Pass User="" to simulate a privacy-mode event carrying only the
// commitment, or User=<address> for a legacy raw-address event.
func (m *MockBlockchainService) AddVaultDeposit(d VaultDeposit) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.vaultDeposits = append(m.vaultDeposits, d)
}

// FilterVaultDeposits returns any vault deposits seeded via AddVaultDeposit
// within the requested block range (mock-only, for tests).
func (m *MockBlockchainService) FilterVaultDeposits(ctx context.Context, fromBlock, toBlock uint64, vaultContract string) ([]VaultDeposit, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.filterErr != nil {
		return nil, m.filterErr
	}
	var out []VaultDeposit
	for _, d := range m.vaultDeposits {
		if d.BlockNumber >= fromBlock && d.BlockNumber <= toBlock {
			out = append(out, d)
		}
	}
	return out, nil
}

// LatestBlock returns the configured head block number for mock mode.
func (m *MockBlockchainService) LatestBlock(ctx context.Context) (uint64, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.headErr != nil {
		return 0, m.headErr
	}
	return m.latest, nil
}

// ---------- Real (Ethereum RPC) ----------

// EthereumService implements BlockchainService against a live Ethereum RPC endpoint
// (e.g. Alchemy Sepolia). It reads its configuration from EthereumConfig.
type EthereumService struct {
	client        *ethclient.Client
	chainID       int64
	token         common.Address
	tokenSymbol   string
	tokenDecimals int
	cloneFactory  common.Address // GlobmintVaultFactory (per-user vault clones)
	signerKey     *ecdsa.PrivateKey // derive from hex key in config; never logged
	from          common.Address
}

// EthereumConfig describes a live Ethereum connection.
type EthereumConfig struct {
	RPCURL             string
	ChainID            int64
	StablecoinSymbol   string
	StablecoinDecimals int
	StablecoinContract string
	// CloneFactoryContract is the deployed GlobmintVaultFactory address that
	// creates per-user vault clones. Empty disables clone operations.
	CloneFactoryContract string
	// PrivateKeyHex is the hex-encoded signer private key used for transfers.
	// It is read from the environment and must never be logged or committed.
	PrivateKeyHex string
}

// NewEthereumService dials the RPC endpoint and builds a real service.
func NewEthereumService(ctx context.Context, cfg EthereumConfig) (*EthereumService, error) {
	client, err := ethclient.DialContext(ctx, cfg.RPCURL)
	if err != nil {
		return nil, fmt.Errorf("dial rpc: %w", err)
	}
	svc := &EthereumService{
		client:        client,
		chainID:       cfg.ChainID,
		token:         common.HexToAddress(cfg.StablecoinContract),
		tokenSymbol:   cfg.StablecoinSymbol,
		tokenDecimals: cfg.StablecoinDecimals,
	}
	if cfg.CloneFactoryContract != "" {
		svc.cloneFactory = common.HexToAddress(cfg.CloneFactoryContract)
	}
	if cfg.PrivateKeyHex != "" {
		key, err := crypto.HexToECDSA(strings.TrimPrefix(cfg.PrivateKeyHex, "0x"))
		if err != nil {
			client.Close()
			return nil, fmt.Errorf("invalid signer private key: %w", err)
		}
		svc.signerKey = key
		svc.from = crypto.PubkeyToAddress(key.PublicKey)
	}
	return svc, nil
}

// Close releases the underlying RPC connection.
func (s *EthereumService) Close() {
	s.client.Close()
}

// GetBalance returns the native ETH balance for an address.
func (s *EthereumService) GetBalance(ctx context.Context, address string) (string, error) {
	if !common.IsHexAddress(address) {
		return "", fmt.Errorf("invalid address %q", address)
	}
	bal, err := s.client.BalanceAt(ctx, common.HexToAddress(address), nil)
	if err != nil {
		return "", fmt.Errorf("get balance: %w", err)
	}
	return formatToken(bal, 18) + " ETH", nil
}

// GetTokenBalance returns the stablecoin (USDC) ERC-20 balance for an address.
func (s *EthereumService) GetTokenBalance(ctx context.Context, address string) (string, error) {
	if !common.IsHexAddress(address) {
		return "", fmt.Errorf("invalid address %q", address)
	}
	owner := common.HexToAddress(address)

	// balanceOf(address) -> uint256
	balanceData, err := s.callContract(ctx, s.token, encodeBalanceOf(owner))
	if err != nil {
		return "", fmt.Errorf("get token balance: %w", err)
	}
	bal := new(big.Int).SetBytes(balanceData)
	return formatToken(bal, s.tokenDecimals) + " " + s.tokenSymbol, nil
}

// GetTransaction returns details of a transaction by hash.
func (s *EthereumService) GetTransaction(ctx context.Context, txHash string) (string, error) {
	hash := common.HexToHash(txHash)
	tx, pending, err := s.client.TransactionByHash(ctx, hash)
	if err != nil {
		return "", fmt.Errorf("transaction lookup: %w", err)
	}

	from, _ := types.Sender(types.LatestSignerForChainID(big.NewInt(s.chainID)), tx)
	to := ""
	if tx.To() != nil {
		to = tx.To().Hex()
	}
	status := "mined"
	if pending {
		status = "pending"
	}

	receipt, _ := s.client.TransactionReceipt(ctx, hash)
	receiptStatus := ""
	if receipt != nil {
		receiptStatus = fmt.Sprintf("%d", receipt.Status)
	}

	return fmt.Sprintf(`{"hash":"%s","from":"%s","to":"%s","value":"%s","gas":"%d","status":"%s","receiptStatus":"%s"}`,
		tx.Hash().Hex(), from.Hex(), to, tx.Value().String(), tx.Gas(), status, receiptStatus), nil
}

// WaitForConfirmation waits until a transaction reaches the requested number of
// confirmations (or becomes mined), polling the chain.
func (s *EthereumService) WaitForConfirmation(ctx context.Context, txHash string, confirmations int) (string, error) {
	hash := common.HexToHash(txHash)

	for {
		select {
		case <-ctx.Done():
			return "", ctx.Err()
		default:
		}

		receipt, err := s.client.TransactionReceipt(ctx, hash)
		if err == nil {
			current, cerr := s.client.BlockNumber(ctx)
			if cerr != nil {
				return "", fmt.Errorf("get block number: %w", cerr)
			}
			inBlock := receipt.BlockNumber.Uint64()
			conf := int64(current) - int64(inBlock) + 1
			if conf < 0 {
				conf = 0
			}
			statusStr := "success"
			if receipt.Status == 0 {
				statusStr = "reverted"
			}
			if int(conf) >= confirmations || statusStr == "reverted" {
				return fmt.Sprintf(`{"status":"%s","confirmations":%d,"blockNumber":%d}`, statusStr, conf, inBlock), nil
			}
		} else if err != nil && err != ethereum.NotFound {
			return "", fmt.Errorf("check receipt: %w", err)
		}

		timer := time.NewTimer(5 * time.Second)
		select {
		case <-ctx.Done():
			timer.Stop()
			return "", ctx.Err()
		case <-timer.C:
		}
	}
}

// TransferToken sends `amount` (in human-readable token units, e.g. "1.50" USDC)
// of the stablecoin from the signer address to `recipient`. It broadcasts the
// transaction and returns its hash. Requires a configured signer key and a
// sender funded with both the stablecoin and ETH (for gas).
func (s *EthereumService) TransferToken(ctx context.Context, recipient string, amount string) (string, error) {
	if s.signerKey == nil {
		return "", fmt.Errorf("signer key not configured")
	}
	if !common.IsHexAddress(recipient) {
		return "", fmt.Errorf("invalid recipient address %q", recipient)
	}
	scaled, err := parseMajorToBase(strings.TrimSpace(amount), s.tokenDecimals)
	if err != nil {
		return "", err
	}
	value := scaled

	to := common.HexToAddress(recipient)

	nonce, err := s.client.PendingNonceAt(ctx, s.from)
	if err != nil {
		return "", fmt.Errorf("get nonce: %w", err)
	}
	gasLimit := uint64(65000)
	gasPrice, err := s.client.SuggestGasPrice(ctx)
	if err != nil {
		return "", fmt.Errorf("suggest gas price: %w", err)
	}

	chainID := big.NewInt(s.chainID)
	tx := types.NewTx(&types.LegacyTx{
		Nonce:    nonce,
		To:       &s.token,
		Value:    big.NewInt(0),
		Gas:      gasLimit,
		GasPrice: gasPrice,
		Data:     encodeTransfer(to, value),
	})

	signed, err := types.SignTx(tx, types.LatestSignerForChainID(chainID), s.signerKey)
	if err != nil {
		return "", fmt.Errorf("sign tx: %w", err)
	}
	if err := s.client.SendTransaction(ctx, signed); err != nil {
		return "", fmt.Errorf("send tx: %w", err)
	}
	return signed.Hash().Hex(), nil
}

// callContract performs a read-only eth_call against a contract.
func (s *EthereumService) callContract(ctx context.Context, to common.Address, data []byte) ([]byte, error) {
	msg := ethereum.CallMsg{To: &to, Data: data}
	return s.client.CallContract(ctx, msg, nil)
}

// encodeBalanceOf builds the ABI payload for balanceOf(address).
// balanceOf(address) -> bytes4 selector 0x70a08231, then one 32-byte word
// containing the 20-byte address right-aligned.
func encodeBalanceOf(owner common.Address) []byte {
	data := make([]byte, 4+32)
	copy(data[:4], common.FromHex("70a08231"))
	copy(data[4+12:4+32], owner.Bytes()) // right-align the 20-byte address
	return data
}

// encodeBytes32Arg builds a 4-byte selector + one 32-byte word, used for the
// factory's predict(userKey) and cloneOfUser(userKey) calls.
func encodeBytes32Arg(selector string, key [32]byte) []byte {
	data := make([]byte, 4+32)
	copy(data[:4], common.FromHex(selector))
	copy(data[4:], key[:])
	return data
}

// encodeCreateClone builds the ABI payload for createClone(bytes32,address):
// 4-byte selector + userKey word + right-aligned owner address word.
func encodeCreateClone(key [32]byte, owner common.Address) []byte {
	data := make([]byte, 4+32+32)
	copy(data[:4], common.FromHex("eada2203"))
	copy(data[4:], key[:])
	copy(data[4+32+12:], owner.Bytes()) // right-align the 20-byte address
	return data
}

// parseBytes32 accepts a 0x-prefixed (or bare) 64-hex-char bytes32 string.
func parseBytes32(s string) ([32]byte, error) {
	var key [32]byte
	r := common.FromHex(s)
	if len(r) != 32 {
		return key, fmt.Errorf("expected 32 bytes, got %d", len(r))
	}
	copy(key[:], r)
	return key, nil
}

// encodeTransfer builds the ABI payload for transfer(address,uint256).
// selector transfer(address,uint256): 0xa9059cbb
func encodeTransfer(to common.Address, value *big.Int) []byte {
	data := make([]byte, 4+32+32)
	copy(data[:4], common.FromHex("a9059cbb"))
	copy(data[4+12:4+32], to.Bytes()) // right-align address
	value.FillBytes(data[4+32:])      // 32-byte big-endian amount
	return data
}

// formatToken formats a big-int token amount using its decimals.
func formatToken(v *big.Int, decimals int) string {
	f := new(big.Float).SetInt(v)
	divisor := new(big.Float).SetInt(new(big.Int).Exp(big.NewInt(10), big.NewInt(int64(decimals)), nil))
	quoted := new(big.Float).Quo(f, divisor)
	return quoted.Text('f', 6)
}

// VaultAddress returns the signer's address, which serves as the on-chain
// address users send deposits to. Empty when no signer key is configured.
func (s *EthereumService) VaultAddress() string {
	if s.signerKey == nil {
		return ""
	}
	return s.from.Hex()
}

// CloneFactoryAddress returns the configured GlobmintVaultFactory address.
func (s *EthereumService) CloneFactoryAddress() string {
	if s.cloneFactory == (common.Address{}) {
		return ""
	}
	return s.cloneFactory.Hex()
}

// PredictClone computes `factory.predict(userKey)` via eth_call, without
// broadcasting. The result is the deterministic CREATE2 address the factory
// would deploy for this per-user key.
func (s *EthereumService) PredictClone(ctx context.Context, userKey string) (string, error) {
	if s.cloneFactory == (common.Address{}) {
		return "", fmt.Errorf("clone factory not configured")
	}
	key, err := parseBytes32(userKey)
	if err != nil {
		return "", fmt.Errorf("invalid user key: %w", err)
	}
	out, err := s.callContract(ctx, s.cloneFactory, encodeBytes32Arg("0e787cce", key))
	if err != nil {
		return "", fmt.Errorf("predict clone: %w", err)
	}
	return common.BytesToAddress(out).Hex(), nil
}

// CloneByUserKey resolves `factory.cloneOfUser(userKey)`, returning "" when no
// clone has been deployed yet (the factory map yields zero address).
func (s *EthereumService) CloneByUserKey(ctx context.Context, userKey string) (string, error) {
	if s.cloneFactory == (common.Address{}) {
		return "", fmt.Errorf("clone factory not configured")
	}
	key, err := parseBytes32(userKey)
	if err != nil {
		return "", fmt.Errorf("invalid user key: %w", err)
	}
	out, err := s.callContract(ctx, s.cloneFactory, encodeBytes32Arg("416fe6ad", key))
	if err != nil {
		return "", fmt.Errorf("lookup clone: %w", err)
	}
	addr := common.BytesToAddress(out)
	if addr == (common.Address{}) {
		return "", nil
	}
	return addr.Hex(), nil
}

// DeployClone calls `factory.createClone(userKey, owner)` with the signer key
// and returns the broadcast tx hash plus the (deterministic) clone address.
// Any account can have a unique clone even before it has a wallet: the user
// key drives CREATE2 while `owner` is the wallet seat (or the platform signer
// as a placeholder the user can later claim).
func (s *EthereumService) DeployClone(ctx context.Context, userKey, owner string) (string, string, error) {
	if s.cloneFactory == (common.Address{}) {
		return "", "", fmt.Errorf("clone factory not configured")
	}
	if s.signerKey == nil {
		return "", "", fmt.Errorf("signer key not configured")
	}
	key, err := parseBytes32(userKey)
	if err != nil {
		return "", "", fmt.Errorf("invalid user key: %w", err)
	}
	if !common.IsHexAddress(owner) {
		return "", "", fmt.Errorf("invalid owner address %q", owner)
	}
	predicted, err := s.PredictClone(ctx, userKey)
	if err != nil {
		return "", "", err
	}
	data := encodeCreateClone(key, common.HexToAddress(owner))
	txHash, err := s.sendTx(ctx, s.cloneFactory, data)
	if err != nil {
		return "", "", fmt.Errorf("deploy clone: %w", err)
	}
	return txHash, predicted, nil
}

// CloneOwner reads `clone.ownerOfThis()` via eth_call: the user's wallet once
// they take custody, or the platform signer as a placeholder.
func (s *EthereumService) CloneOwner(ctx context.Context, cloneAddress string) (string, error) {
	if !common.IsHexAddress(cloneAddress) {
		return "", fmt.Errorf("invalid clone address %q", cloneAddress)
	}
	out, err := s.callContract(ctx, common.HexToAddress(cloneAddress), common.FromHex("efd6bab0"))
	if err != nil {
		return "", fmt.Errorf("owner of clone: %w", err)
	}
	return common.BytesToAddress(out).Hex(), nil
}

// CloneNonce reads `clone.nonce()` via eth_call — the next EIP-712 withdrawal
// nonce the contract will accept.
func (s *EthereumService) CloneNonce(ctx context.Context, cloneAddress string) (uint64, error) {
	if !common.IsHexAddress(cloneAddress) {
		return 0, fmt.Errorf("invalid clone address %q", cloneAddress)
	}
	out, err := s.callContract(ctx, common.HexToAddress(cloneAddress), common.FromHex("affed0e0"))
	if err != nil {
		return 0, fmt.Errorf("clone nonce: %w", err)
	}
	n := new(big.Int).SetBytes(out)
	if !n.IsUint64() {
		return 0, fmt.Errorf("clone nonce overflows uint64")
	}
	return n.Uint64(), nil
}

// SignWithdrawRelay signs a withdrawWithSig request with the platform signer
// key. TRANSITIONAL path only: valid while the clone is still owned by the
// platform signer and GLOBMINT_REQUIRE_USER_SIGNATURE is not enforced. Once a
// user claims their clone, only their own wallet signature is accepted.
func (s *EthereumService) SignWithdrawRelay(ctx context.Context, chainID int64, clone, to string, amountBase *big.Int, nonce uint64, deadline int64) (WithdrawSignature, error) {
	if s.signerKey == nil {
		return WithdrawSignature{}, fmt.Errorf("signer key not configured")
	}
	if !common.IsHexAddress(clone) || !common.IsHexAddress(to) {
		return WithdrawSignature{}, fmt.Errorf("invalid relay address")
	}
	if amountBase == nil || amountBase.Sign() <= 0 {
		return WithdrawSignature{}, fmt.Errorf("invalid relay amount")
	}
	digest := eip712.WithdrawDigest(chainID, common.HexToAddress(clone), eip712.WithdrawRequest{
		To:       common.HexToAddress(to),
		Amount:   amountBase,
		Nonce:    nonce,
		Deadline: deadline,
	})
	sig, err := eip712.SignDigest(digest, s.signerKey)
	if err != nil {
		return WithdrawSignature{}, err
	}
	v, r, sPart, err := eip712.ParseSignature(common.Bytes2Hex(sig))
	if err != nil {
		return WithdrawSignature{}, err
	}
	return WithdrawSignature{V: v, R: r, S: sPart}, nil
}

// WithdrawFromCloneWithSig relays a pre-signed EIP-712 withdrawWithSig call on
// the clone. The signer pays the gas; the signature inside relay authorizes
// the exact transfer, and the clone contract re-verifies it against the
// clone's owner before moving funds.
func (s *EthereumService) WithdrawFromCloneWithSig(ctx context.Context, relay WithdrawRelay) (string, error) {
	if !common.IsHexAddress(relay.Clone) || !common.IsHexAddress(relay.To) {
		return "", fmt.Errorf("invalid relay address")
	}
	if relay.Amount == nil || relay.Amount.Sign() <= 0 {
		return "", fmt.Errorf("invalid relay amount")
	}
	clone := common.HexToAddress(relay.Clone)
	data := encodeWithdrawWithSig(relay)
	txHash, err := s.sendTx(ctx, clone, data)
	if err != nil {
		return "", fmt.Errorf("relay withdrawWithSig: %w", err)
	}
	return txHash, nil
}

// encodeWithdrawWithSig builds the ABI payload for
// withdrawWithSig(address,uint256,uint256,uint256,uint8,bytes32,bytes32):
// 4-byte selector + to + amount + nonce + deadline + v (right-aligned byte) +
// r + s, each a 32-byte word.
func encodeWithdrawWithSig(relay WithdrawRelay) []byte {
	data := make([]byte, 4+32+32+32+32+32+32+32)
	copy(data[:4], common.FromHex("4a5b1f51"))
	copy(data[4+12:4+32], common.HexToAddress(relay.To).Bytes()) // right-align address
	relay.Amount.FillBytes(data[4+32 : 4+64])
	new(big.Int).SetUint64(relay.Nonce).FillBytes(data[4+64 : 4+96])
	new(big.Int).SetInt64(relay.Deadline).FillBytes(data[4+96 : 4+128])
	data[4+128+31] = relay.Sig.V // uint8 right-aligned in its word
	copy(data[4+160:4+192], relay.Sig.R[:])
	copy(data[4+192:4+224], relay.Sig.S[:])
	return data
}

// sendTx broadcasts a signed transaction to `to` with `data` (zero value) from
// the signer account. Shared by transfers and clone deployment.
func (s *EthereumService) sendTx(ctx context.Context, to common.Address, data []byte) (string, error) {
	nonce, err := s.client.PendingNonceAt(ctx, s.from)
	if err != nil {
		return "", fmt.Errorf("get nonce: %w", err)
	}
	gasLimit := uint64(300000)
	gasPrice, err := s.client.SuggestGasPrice(ctx)
	if err != nil {
		return "", fmt.Errorf("suggest gas price: %w", err)
	}
	tx := types.NewTx(&types.LegacyTx{
		Nonce:    nonce,
		To:       &to,
		Value:    big.NewInt(0),
		Gas:      gasLimit,
		GasPrice: gasPrice,
		Data:     data,
	})
	signed, err := types.SignTx(tx, types.LatestSignerForChainID(big.NewInt(s.chainID)), s.signerKey)
	if err != nil {
		return "", fmt.Errorf("sign tx: %w", err)
	}
	if err := s.client.SendTransaction(ctx, signed); err != nil {
		return "", fmt.Errorf("send tx: %w", err)
	}
	return signed.Hash().Hex(), nil
}

// LatestBlock returns the current head block number.
func (s *EthereumService) LatestBlock(ctx context.Context) (uint64, error) {
	n, err := s.client.BlockNumber(ctx)
	if err != nil {
		return 0, fmt.Errorf("get latest block: %w", err)
	}
	return n, nil
}

// FilterTokenTransfers returns decoded stablecoin Transfer events from
// `fromBlock`..`toBlock` (inclusive) where the recipient matches `address`
// (or all recipients when `address` is empty).
// maxLogsBlockRange caps each eth_getLogs request. Alchemy's free tier allows
// at most a 10-block range per request; larger ranges are rejected with a 400
// error, so we always split the scan into sub-ranges of this size.
const maxLogsBlockRange = 10

func (s *EthereumService) FilterTokenTransfers(ctx context.Context, fromBlock, toBlock uint64, address string) ([]TokenTransfer, error) {
	// Transfer(address,address,uint256) topic0
	topic0 := common.HexToHash("0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef")
	out := make([]TokenTransfer, 0)
	// Walk the (inclusive) range in up-to-10-block slices.
	start := fromBlock
	for start <= toBlock {
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		end := start + maxLogsBlockRange - 1
		if end > toBlock {
			end = toBlock
		}
		query := ethereum.FilterQuery{
			FromBlock: new(big.Int).SetUint64(start),
			ToBlock:   new(big.Int).SetUint64(end),
			Addresses: []common.Address{s.token},
			Topics:    [][]common.Hash{{topic0}},
		}
		logs, err := s.client.FilterLogs(ctx, query)
		if err != nil {
			return nil, fmt.Errorf("filter token transfers (%d..%d): %w", start, end, err)
		}
		for _, l := range logs {
			if len(l.Topics) < 3 || len(l.Data) < 32 {
				continue
			}
			tsf := TokenTransfer{
				From:        common.HexToAddress(l.Topics[1].Hex()).Hex(),
				To:          common.HexToAddress(l.Topics[2].Hex()).Hex(),
				Value:       new(big.Int).SetBytes(l.Data[:32]),
				TxHash:      l.TxHash.Hex(),
				LogIndex:    uint64(l.Index),
				BlockNumber: l.BlockNumber,
			}
			if address == "" || strings.EqualFold(tsf.To, address) {
				out = append(out, tsf)
			}
		}
		if end >= toBlock {
			break
		}
		start = end + 1
	}
	return out, nil
}

// FilterVaultDeposits returns decoded GlobmintVault deposit events from the
// vault contract over a block range. Both the privacy event
// `DepositedPrivate(bytes32 indexed commitment, uint256 amount)` and the
// legacy `Deposited(bytes32 indexed commitment, address indexed user, uint256
// amount)` are decoded. Privacy-mode events have an empty User field; the
// indexer resolves the commitment via the user_salts table.
func (s *EthereumService) FilterVaultDeposits(ctx context.Context, fromBlock, toBlock uint64, vaultContract string) ([]VaultDeposit, error) {
	if vaultContract == "" {
		return nil, nil
	}
	vault := common.HexToAddress(vaultContract)
	// topic0 for Deposited(bytes32,address,uint256) and DepositedPrivate(bytes32,uint256)
	legacyTopic0 := common.HexToHash("0x87d4c0b5e30d6808bc8a94ba1c4d839b29d664151551a31753387ee9ef48429b")
	privateTopic0 := common.HexToHash("0x7a4336eceb7d2f2153fd7bb67a16180b75c5a3e7b373e843abb237e2e9c05a8e")

	out := make([]VaultDeposit, 0)
	start := fromBlock
	for start <= toBlock {
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		end := start + maxLogsBlockRange - 1
		if end > toBlock {
			end = toBlock
		}
		query := ethereum.FilterQuery{
			FromBlock: new(big.Int).SetUint64(start),
			ToBlock:   new(big.Int).SetUint64(end),
			Addresses: []common.Address{vault},
			Topics:    [][]common.Hash{{legacyTopic0, privateTopic0}},
		}
		logs, err := s.client.FilterLogs(ctx, query)
		if err != nil {
			return nil, fmt.Errorf("filter vault deposits (%d..%d): %w", start, end, err)
		}
		for _, l := range logs {
			if len(l.Topics) < 2 || len(l.Data) < 32 {
				continue
			}
			d, ok := decodeVaultDeposit(&l)
			if ok {
				out = append(out, *d)
			}
		}
		if end >= toBlock {
			break
		}
		start = end + 1
	}
	return out, nil
}

// decodeVaultDeposit decodes a vault Deposit log line. Legacy events carry the
// user as the second indexed topic; privacy events do not.
func decodeVaultDeposit(l *types.Log) (*VaultDeposit, bool) {
	legacyTopic0 := common.HexToHash("0x87d4c0b5e30d6808bc8a94ba1c4d839b29d664151551a31753387ee9ef48429b")
	d := &VaultDeposit{
		Commitment:  l.Topics[1].Hex(),
		Amount:      new(big.Int).SetBytes(l.Data[:32]),
		TxHash:      l.TxHash.Hex(),
		LogIndex:    uint64(l.Index),
		BlockNumber: l.BlockNumber,
	}
	if l.Topics[0] == legacyTopic0 {
		if len(l.Topics) < 3 {
			return nil, false
		}
		d.User = common.HexToAddress(l.Topics[2].Hex()).Hex()
	}
	return d, true
}

// parseMajorToBase parses a decimal major-unit string (e.g. "1.50") into base
// units given the token's decimals (e.g. 1.50 USDC * 1e6 = 1500000).
func parseMajorToBase(s string, decimals int) (*big.Int, error) {
	if s == "" {
		return nil, fmt.Errorf("empty amount")
	}
	neg := false
	if s[0] == '-' {
		neg = true
		s = s[1:]
	}
	parts := strings.SplitN(s, ".", 2)
	whole := parts[0]
	frac := ""
	if len(parts) == 2 {
		frac = parts[1]
	}
	if whole == "" {
		whole = "0"
	}
	// Reject an overly precise fraction instead of silently truncating.
	if len(frac) > decimals {
		return nil, fmt.Errorf("amount %q has too many decimal places", s)
	}
	for len(frac) < decimals {
		frac += "0"
	}
	combined := whole + frac
	val, ok := new(big.Int).SetString(combined, 10)
	if !ok {
		return nil, fmt.Errorf("invalid amount %q", s)
	}
	if neg {
		return nil, fmt.Errorf("negative amount")
	}
	return val, nil
}

// ---------- Factory ----------

// BlockchainServiceFactory constructs a BlockchainService from configuration.
type BlockchainServiceFactory struct{}

// CreateMock creates a mock blockchain service for development.
func (f BlockchainServiceFactory) CreateMock() BlockchainService {
	return NewMockBlockchainService()
}

// CreateReal creates a live Ethereum service connected to an RPC.
func (f BlockchainServiceFactory) CreateReal(ctx context.Context, cfg EthereumConfig) (BlockchainService, error) {
	return NewEthereumService(ctx, cfg)
}

// NewFromConfig creates the appropriate service based on the configured mode.
// Mode "mock" (default) returns a mock; any other mode dials the live network.
// The mock is seeded so the per-user clone deposit flow is exercisable end to
// end without a chain: a deterministic factory address is always visible (the
// configured one when set, else a keccak-derived placeholder) so every account
// resolves its own stable, unique deposit address.
func NewFromConfig(ctx context.Context, mode string, cfg EthereumConfig) (BlockchainService, func(), error) {
	if mode == "" || mode == "mock" {
		m := NewMockBlockchainService()
		factory := cfg.CloneFactoryContract
		if factory == "" {
			factory = mockPseudoAddress("globmint:mock-vault-factory:" + cfg.StablecoinSymbol)
		}
		m.SetCloneFactory(factory)
		return m, func() {}, nil
	}
	svc, err := NewEthereumService(ctx, cfg)
	if err != nil {
		return nil, nil, err
	}
	return svc, svc.Close, nil
}

// mockPseudoAddress derives a deterministic 0x address from a seed, giving the
// mock stable stand-ins for on-chain contracts (no real chain involved).
func mockPseudoAddress(seed string) string {
	h := crypto.Keccak256Hash([]byte(seed))
	return common.BytesToAddress(h.Bytes()[12:]).Hex()
}
