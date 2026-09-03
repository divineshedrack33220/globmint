package blockchain

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"math/big"
	"strings"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
)

// BlockchainService defines the interface for blockchain operations.
type BlockchainService interface {
	GetBalance(ctx context.Context, address string) (string, error)
	GetTokenBalance(ctx context.Context, address string) (string, error)
	GetTransaction(ctx context.Context, txHash string) (string, error)
	WaitForConfirmation(ctx context.Context, txHash string, confirmations int) (string, error)
	TransferToken(ctx context.Context, recipient string, amount string) (string, error)
}

// ---------- Mock ----------

// MockBlockchainService is a mock implementation for development/testing.
type MockBlockchainService struct {
	balances map[string]string
}

// NewMockBlockchainService creates a new mock blockchain service.
func NewMockBlockchainService() *MockBlockchainService {
	return &MockBlockchainService{
		balances: make(map[string]string),
	}
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
	scaled, ok := new(big.Int).SetString(strings.ReplaceAll(amount, ",", ""), 10)
	if !ok {
		return "", fmt.Errorf("invalid amount %q", amount)
	}
	// Scale human units to base units (e.g. 6 decimals -> *1e6).
	multiplier := new(big.Int).Exp(big.NewInt(10), big.NewInt(int64(s.tokenDecimals)), nil)
	value := new(big.Int).Mul(scaled, multiplier)

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
