package httpapi

import (
	"globmint/backend/internal/events"
	"globmint/backend/internal/infrastructure/blockchain"
	"globmint/backend/internal/services"
)

// Deps bundles the services handlers depend on. The HTTP layer stays thin and
// does not contain business logic.
type Deps struct {
	Auth       *services.AuthService
	Balance    *services.BalanceService
	Ledger     *services.LedgerService
	Money      *services.MoneyService
	Savings    *services.SavingsService
	Security   *services.SecurityService
	Blockchain blockchain.BlockchainService
	Vault      *services.VaultService
	// Events fans change notifications out to SSE subscribers.
	Events *events.Hub
	// OperatorToken authenticates the operator-only endpoints (unattributed
	// deposit review/attribution) via the X-Operator-Token header. Empty
	// disables those endpoints.
	OperatorToken string
	// RequireUserSignature mirrors GLOBMINT_REQUIRE_USER_SIGNATURE and is
	// advertised to clients on deposit-info / vault-status so they know whether
	// withdrawals must be signed by the user's wallet (true) or may still run
	// through the transitional platform-signer path (false).
	RequireUserSignature bool
}
