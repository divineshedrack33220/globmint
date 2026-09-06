package httpapi

import (
	"log"
	"net/http"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/httpapi/middleware"
	"globmint/backend/internal/services"
)

// depositInfoResponse mirrors services.DepositInfo for the JSON API.
type depositInfoResponse struct {
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

func toDepositInfoResponse(info *services.DepositInfo) depositInfoResponse {
	return depositInfoResponse{
		Address:            info.Address,
		VaultContract:      info.VaultContract,
		StablecoinSymbol:   info.StablecoinSymbol,
		StablecoinName:     info.StablecoinName,
		StablecoinDecimals: info.StablecoinDecimals,
		StablecoinContract: info.StablecoinContract,
		Network:            info.Network,
		ChainID:            info.ChainID,
		Mode:               info.Mode,
	}
}

type setDepositAddressRequest struct {
	Address string `json:"address"`
}

// handleGetDepositInfo returns the authenticated user's deposit info (vault
// contract, stablecoin details, network) and their linked wallet address, if any.
func (d *Deps) handleGetDepositInfo(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	if d.Savings == nil {
		writeError(w, r, domain.ErrNotFound, "")
		return
	}
	info, err := d.Savings.GetDepositInfo(r.Context(), user.ID)
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, toDepositInfoResponse(info))
}

// handleSetDepositAddress links (or re-links) the authenticated user's own
// on-chain wallet address for non-custodial vault deposits.
func (d *Deps) handleSetDepositAddress(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	if d.Savings == nil {
		writeError(w, r, domain.ErrNotFound, "")
		return
	}
	var req setDepositAddressRequest
	if err := decodeJSON(w, r, &req); err != nil {
		writeError(w, r, err, "")
		return
	}
	info, err := d.Savings.SetDepositAddress(r.Context(), user.ID, req.Address)
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, toDepositInfoResponse(info))
}
// handleVaultStatus returns the authenticated user's vault on-chain status
// and deposit info.
func (d *Deps) handleVaultStatus(w http.ResponseWriter, r *http.Request) {
	user := middleware.UserFrom(r.Context())
	if user == nil {
		writeError(w, r, domain.ErrUnauthenticated, "")
		return
	}
	if d.Vault == nil {
		writeError(w, r, domain.ErrNotFound, "")
		return
	}
	info, err := d.Savings.GetDepositInfo(r.Context(), user.ID)
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	vaultUsdc := "0.000000"
	bal, berr := d.Blockchain.GetTokenBalance(r.Context(), d.Vault.DepositAddress())
	if berr == nil {
		vaultUsdc = bal
	} else {
		// Never invent funds: when the chain is unreachable the honest answer
		// is zero confirmed holdings, not a demo balance. Clients treat the
		// vault figure as informational; the personal ledger is authoritative.
		log.Printf("vault-status: chain balance unavailable, reporting zero: %v", berr)
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"vault_usdc_balance": vaultUsdc,
		"deposit_info":       info,
	})
}