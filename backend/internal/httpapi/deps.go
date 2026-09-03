package httpapi

import (
	"globmint/backend/internal/services"
)

// Deps bundles the services handlers depend on. The HTTP layer stays thin and
// does not contain business logic.
type Deps struct {
	Auth    *services.AuthService
	Balance *services.BalanceService
	Ledger  *services.LedgerService
	Money   *services.MoneyService
}
