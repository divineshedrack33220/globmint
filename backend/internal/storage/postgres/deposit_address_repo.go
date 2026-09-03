package postgres

import (
	"context"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/storage"
)

type depositAddressRepo struct{ q Querier }

func NewDepositAddressRepo(q Querier) storage.DepositAddressRepository {
	return &depositAddressRepo{q: q}
}

const depositAddressCols = `user_id::text, address, created_at, updated_at`

func scanDepositAddress(row pgxRow) (*domain.DepositAddress, error) {
	da := &domain.DepositAddress{}
	if err := row.Scan(&da.UserID, &da.Address, &da.CreatedAt, &da.UpdatedAt); err != nil {
		return nil, err
	}
	return da, nil
}

func (r *depositAddressRepo) FindByUser(ctx context.Context, userID string) (*domain.DepositAddress, error) {
	row := r.q.QueryRow(ctx, `
		SELECT `+depositAddressCols+`
		FROM deposit_addresses
		WHERE user_id = $1::uuid`, userID)
	da, err := scanDepositAddress(row)
	if err != nil {
		return nil, mapPgErr(err)
	}
	return da, nil
}

// Set upserts the user's deposit address. The address column is UNIQUE, so a
// duplicate claim by another user maps to ErrConflict.
func (r *depositAddressRepo) Set(ctx context.Context, da *domain.DepositAddress) error {
	row := r.q.QueryRow(ctx, `
		INSERT INTO deposit_addresses (user_id, address)
		VALUES ($1::uuid, $2)
		ON CONFLICT (user_id) DO UPDATE SET address = EXCLUDED.address, updated_at = now()
		RETURNING `+depositAddressCols,
		da.UserID, da.Address)
	got, err := scanDepositAddress(row)
	if err != nil {
		return mapPgErr(err)
	}
	*da = *got
	return nil
}

func (r *depositAddressRepo) OwnerOf(ctx context.Context, address string) (string, error) {
	var userID string
	err := r.q.QueryRow(ctx, `SELECT user_id::text FROM deposit_addresses WHERE address = $1`, address).Scan(&userID)
	if err != nil {
		if mapPgErr(err) == domain.ErrNotFound {
			return "", nil
		}
		return "", mapPgErr(err)
	}
	return userID, nil
}
