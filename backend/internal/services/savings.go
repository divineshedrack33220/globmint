package services

import (
	"context"
	"crypto/rand"
	"errors"
	"strconv"
	"strings"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"

	"globmint/backend/internal/config"
	"globmint/backend/internal/domain"
	"globmint/backend/internal/storage"
)

// SavingsConfig carries the non-secret on-chain details the savings endpoints
// expose so clients can build non-custodial approve + deposit calls against the
// GlobmintVault. It never contains private keys.
type SavingsConfig struct {
	VaultContract      string
	VaultAddress       string // custodial deposit address users send to (signer)
	StablecoinSymbol   string
	StablecoinName     string
	StablecoinDecimals int
	StablecoinContract string
	Network            string
	ChainID            int64
	Mode               string
	// PrivacyMode enables commitment-based (salt-hashed) vault balances.
	PrivacyMode bool
}

// SavingsService manages the per-user on-chain deposit address used for
// non-custodial savings deposits into the GlobmintVault contract. The system
// never holds user keys; it only records which wallet address belongs to which
// user and exposes the contract/stablecoin details needed to deposit.
type SavingsService struct {
	store storage.Store
	cfg   SavingsConfig
}

func NewSavingsService(store storage.Store, cfg SavingsConfig) *SavingsService {
	return &SavingsService{store: store, cfg: cfg}
}

// DepositInfo is the non-secret data a client needs to fund a user's savings
// balance. Address is the on-chain deposit address (vault) funds are sent to.
type DepositInfo struct {
	Address            string `json:"address"`
	VaultContract      string `json:"vault_contract"`
	StablecoinSymbol   string `json:"stablecoin_symbol"`
	StablecoinName     string `json:"stablecoin_name"`
	StablecoinDecimals int    `json:"stablecoin_decimals"`
	StablecoinContract string `json:"stablecoin_contract"`
	Network            string `json:"network"`
	ChainID            int64  `json:"chain_id"`
	Mode               string `json:"mode"`
	// PrivacyEnabled reports whether commitment-based (salt-hashed) balances
	// are active. When true, clients must use the salt-aware vault entry points
	// and the raw address never appears in deposit events.
	PrivacyEnabled bool `json:"privacy_enabled"`
}

// GetDepositInfo returns the on-chain deposit address (vault) along with the
// stablecoin details needed to fund the user's savings.
func (s *SavingsService) GetDepositInfo(ctx context.Context, userID string) (*DepositInfo, error) {
	info := &DepositInfo{
		Address:            s.cfg.VaultAddress,
		VaultContract:      s.cfg.VaultContract,
		StablecoinSymbol:   s.cfg.StablecoinSymbol,
		StablecoinName:     s.cfg.StablecoinName,
		StablecoinDecimals: s.cfg.StablecoinDecimals,
		StablecoinContract: s.cfg.StablecoinContract,
		Network:            s.cfg.Network,
		ChainID:            s.cfg.ChainID,
		Mode:               s.cfg.Mode,
		PrivacyEnabled:     s.cfg.PrivacyMode,
	}
	return info, nil
}

// SetDepositAddress links (or re-links) the user's own wallet address. It
// rejects addresses already claimed by another user and validates the format.
//
// Privacy mode: on the very first link the backend generates a fresh 16-byte
// random salt for the user (stored in user_salts) from which deposit
// commitments (keccak256(address, salt)) are derived. Re-linking the address
// within privacy mode PRESERVES the existing salt so a commitment already
// funded on-chain stays resolvable; the salt is never returned to the client.
func (s *SavingsService) SetDepositAddress(ctx context.Context, userID, address string) (*DepositInfo, error) {
	addr, err := domain.ValidateDepositAddress(address)
	if err != nil {
		return nil, domain.ErrInvalidAddress
	}

	// An address must not be shared with another user.
	owner, err := s.store.DepositAddressRepo().OwnerOf(ctx, addr)
	if err != nil {
		return nil, err
	}
	if owner != "" && owner != userID {
		return nil, domain.ErrConflict
	}

	if err := s.store.DepositAddressRepo().Set(ctx, &domain.DepositAddress{UserID: userID, Address: addr}); err != nil {
		return nil, err
	}

	if s.cfg.PrivacyMode {
		if err := s.ensureUserSalt(ctx, userID); err != nil {
			return nil, err
		}
	}
	return s.GetDepositInfo(ctx, userID)
}

// ensureUserSalt generates and stores a fresh random salt on first use and
// never overwrites an existing one, so an already-funded commitment keeps
// resolving to the same user after a re-link.
func (s *SavingsService) ensureUserSalt(ctx context.Context, userID string) error {
	existing, err := s.store.UserSaltsRepo().FindByUser(ctx, userID)
	if err == nil && len(existing) > 0 {
		return nil
	}
	if err != nil && !errors.Is(err, domain.ErrNotFound) {
		return err
	}
	salt := make([]byte, 16)
	if _, err := rand.Read(salt); err != nil {
		return err
	}
	return s.store.UserSaltsRepo().Upsert(ctx, userID, salt)
}

// SetWalletDerivedSalt records a salt that the user's OWN wallet produced, so
// the privacy secret's source is the user, not the backend RNG. PKCS7/personal
// signatures are EIP-191 scrambles; we bind the salt to the user's linked
// wallet by requiring a recoverable signature over an application message that
// pins the salt, then verifying it recovers to the linked deposit address.
// Legacy random salts are never silently replaced on a re-link (a commitment
// already funded on-chain must keep resolving); a wallet-derived salt may only
// be (re)recorded for the same user.
func (s *SavingsService) SetWalletDerivedSalt(ctx context.Context, userID, saltHex, message, signature string) error {
	if !s.cfg.PrivacyMode {
		return domain.ErrInvalidOperation
	}
	if _, err := domain.ValidateDepositAddress(saltHex); err != nil {
		return domain.ErrInvalidSalt
	}
	if message == "" || signature == "" {
		return domain.ErrInvalidSignature
	}

	link, err := s.store.DepositAddressRepo().FindByUser(ctx, userID)
	if err != nil {
		return err
	}
	if link == nil || link.Address == "" {
		return domain.ErrNoLinkedWallet
	}

	if !isValidPersonalSignature(signature, message, link.Address) {
		return domain.ErrInvalidSignature
	}

	salt := common.FromHex(saltHex)
	if len(salt) != 16 {
		return domain.ErrInvalidSalt
	}
	existing, err := s.store.UserSaltsRepo().FindByUser(ctx, userID)
	if err != nil && !errors.Is(err, domain.ErrNotFound) {
		return err
	}
	if len(existing) > 0 && !bytesEqual(existing, salt) {
		return domain.ErrSaltImmutable
	}
	return s.store.UserSaltsRepo().UpsertWithDerivation(ctx, userID, salt, "wallet-derived", link.Address)
}

// isValidPersonalSignature verifies `signature` recovers the EIP-191 personal
// message hash of `message` to `expected`. Used to bind a wallet-derived
// privacy salt to the user's linked wallet without ever storing a key.
func isValidPersonalSignature(signature, message, expected string) bool {
	sig := common.FromHex(signature)
	if len(sig) != 65 {
		return false
	}
	// ecrecover in go-ethereum expects v in {0,1}, not the 27/28 encoding.
	if sig[64] == 27 || sig[64] == 28 {
		sig[64] -= 27
	}
	hash := crypto.Keccak256Hash([]byte("\x19Ethereum Signed Message:\n" + strconv.Itoa(len(message)) + message))
	recovered, err := crypto.Ecrecover(hash.Bytes(), sig)
	if err != nil {
		return false
	}
	got := common.BytesToAddress(recovered)
	return strings.EqualFold(got.Hex(), expected)
}

func bytesEqual(a, b []byte) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

// FromConfig derives a SavingsConfig from the app configuration.
func FromConfig(cfg config.Config) SavingsConfig {
	return SavingsConfig{
		VaultContract:      cfg.Blockchain.VaultContract,
		VaultAddress:       cfg.Blockchain.VaultAddress,
		StablecoinSymbol:   cfg.Blockchain.Stablecoin,
		StablecoinName:     cfg.Blockchain.StablecoinName,
		StablecoinDecimals: cfg.Blockchain.StablecoinDecimals,
		StablecoinContract: cfg.Blockchain.StablecoinContract,
		Network:            cfg.Blockchain.Network,
		ChainID:            cfg.Blockchain.ChainID,
		Mode:               cfg.Blockchain.Mode,
		PrivacyMode:        cfg.PrivacyMode,
	}
}
