package services

import (
	"context"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/storage"
)

// BalanceService exposes authoritative balances derived from the ledger.
type BalanceService struct {
	store storage.Store
}

func NewBalanceService(store storage.Store) *BalanceService {
	return &BalanceService{store: store}
}

// List returns the user's accounts with balances derived from the (immutable)
// ledger via the maintained balance projection.
func (s *BalanceService) List(ctx context.Context, userID string) ([]domain.BalanceSnapshot, error) {
	accounts, err := s.store.AccountRepo().ListByUser(ctx, userID)
	if err != nil {
		return nil, err
	}
	out := make([]domain.BalanceSnapshot, 0, len(accounts))
	for _, a := range accounts {
		minor, err := s.store.AccountRepo().GetBalance(ctx, a.ID)
		if err != nil {
			return nil, err
		}
		out = append(out, domain.BalanceSnapshot{
			AccountID: a.ID,
			Kind:      a.Kind,
			Currency:  a.Currency,
			Amount:    minor,
		})
	}
	return out, nil
}

// Get returns a single account's balance snapshot.
func (s *BalanceService) Get(ctx context.Context, userID, accountID string) (*domain.BalanceSnapshot, error) {
	account, err := s.store.AccountRepo().FindByID(ctx, accountID)
	if err != nil {
		return nil, err
	}
	if account.UserID != userID {
		return nil, domain.ErrNotFound
	}
	minor, err := s.store.AccountRepo().GetBalance(ctx, accountID)
	if err != nil {
		return nil, err
	}
	return &domain.BalanceSnapshot{
		AccountID: account.ID,
		Kind:      account.Kind,
		Currency:  account.Currency,
		Amount:    minor,
	}, nil
}
