package services

import (
	"context"

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
	}
	return info, nil
}

// SetDepositAddress links (or re-links) the user's own wallet address. It
// rejects addresses already claimed by another user and validates the format.
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
	return s.GetDepositInfo(ctx, userID)
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
	}
}
