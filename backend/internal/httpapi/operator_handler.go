package httpapi

import (
	"crypto/subtle"
	"net/http"

	"globmint/backend/internal/domain"
)

// operatorTokenHeader is the header operators send to authenticate against the
// operator API. The static token is configured via GLOBMINT_OPERATOR_TOKEN and
// is separate from user sessions so support staff do not need a user account.
const operatorTokenHeader = "X-Operator-Token"

func (d *Deps) operatorAuthorized(r *http.Request) bool {
	if d.OperatorToken == "" {
		return false
	}
	got := r.Header.Get(operatorTokenHeader)
	return subtle.ConstantTimeCompare([]byte(got), []byte(d.OperatorToken)) == 1
}

func (d *Deps) writeOperatorUnauthorized(w http.ResponseWriter, r *http.Request) {
	writeError(w, r, domain.ErrUnauthenticated, "")
}

// attributionResponse describes a single flagged unattributed deposit.
type attributionResponse struct {
	TxHash      string `json:"tx_hash"`
	LogIndex    uint64 `json:"log_index"`
	BlockNumber uint64 `json:"block_number"`
	From        string `json:"from,omitempty"`
	To          string `json:"to,omitempty"`
	ValueBase   int64  `json:"value_base"`
}

func toAttributionResponse(e domain.IndexerEvent) attributionResponse {
	return attributionResponse{
		TxHash:      e.TxHash,
		LogIndex:    e.LogIndex,
		BlockNumber: e.BlockNumber,
		From:        e.From,
		To:          e.To,
		ValueBase:   e.ValueBase,
	}
}

// handleListUnattributedDeposits returns the queue of direct transfers into the
// vault that no user has been credited for:
//
//	GET /api/v1/operator/vault/unattributed-deposits
func (d *Deps) handleListUnattributedDeposits(w http.ResponseWriter, r *http.Request) {
	if !d.operatorAuthorized(r) {
		d.writeOperatorUnauthorized(w, r)
		return
	}
	events, err := d.Vault.UnattributedDeposits(r.Context(), 200)
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	out := make([]attributionResponse, 0, len(events))
	for _, e := range events {
		out = append(out, toAttributionResponse(e))
	}
	writeJSON(w, http.StatusOK, map[string]any{"deposits": out})
}

type attributeDepositRequest struct {
	TxHash   string `json:"tx_hash"`
	LogIndex uint64 `json:"log_index"`
	UserID   string `json:"user_id"`
}

// handleAttributeDeposit links an unattributed deposit's sender to a user and
// credits their ledger:
//
//	POST /api/v1/operator/vault/attribute-deposit
func (d *Deps) handleAttributeDeposit(w http.ResponseWriter, r *http.Request) {
	if !d.operatorAuthorized(r) {
		d.writeOperatorUnauthorized(w, r)
		return
	}
	var req attributeDepositRequest
	if err := decodeJSON(w, r, &req); err != nil {
		writeError(w, r, err, "")
		return
	}
	if req.TxHash == "" || req.UserID == "" {
		writeError(w, r, domain.ErrBadRequest, "")
		return
	}
	credited, err := d.Vault.AttributeDeposit(r.Context(), req.TxHash, req.LogIndex, req.UserID)
	if err != nil {
		writeError(w, r, err, "")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"credited": credited, "attributed": true})
}
