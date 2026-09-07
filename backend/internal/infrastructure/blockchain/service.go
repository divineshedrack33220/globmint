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
	latest    uint64
	headErr   error
	filterErr error
}

// ---------- Mock ----------

// NewMockBlockchainService creates a new mock blockchain service.
func NewMockBlockchainService() *MockBlockchainService {
	return &MockBlockchainService{
		balances: make(map[string]string),
	}
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
func NewFromConfig(ctx context.Context, mode string, cfg EthereumConfig) (BlockchainService, func(), error) {
	if mode == "" || mode == "mock" {
		return NewMockBlockchainService(), func() {}, nil
	}
	svc, err := NewEthereumService(ctx, cfg)
	if err != nil {
		return nil, nil, err
	}
	return svc, svc.Close, nil
}
