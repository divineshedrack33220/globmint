package postgres

import (
	"context"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/storage"
)

// userSaltRepo persists per-user random salts for commitment-based balance privacy.
type userSaltRepo struct{ q Querier }

// NewUserSaltsRepo builds the UserSaltsRepository.
func NewUserSaltsRepo(q Querier) storage.UserSaltsRepository { return &userSaltRepo{q: q} }

const userSaltInsert = `
INSERT INTO user_salts (user_id, salt, updated_at)
VALUES ($1::uuid, $2, now())
ON CONFLICT (user_id) DO UPDATE SET salt = EXCLUDED.salt, updated_at = now()
`

const userSaltFind = `
SELECT salt FROM user_salts WHERE user_id = $1::uuid
`

func (r *userSaltRepo) Upsert(ctx context.Context, userID string, salt []byte) error {
	_, err := r.q.Exec(ctx, userSaltInsert, userID, salt)
	return err
}

func (r *userSaltRepo) FindByUser(ctx context.Context, userID string) ([]byte, error) {
	var salt []byte
	err := r.q.QueryRow(ctx, userSaltFind, userID).Scan(&salt)
	if err != nil {
		return nil, mapPgErr(err)
	}
	return salt, nil
}

func (r *userSaltRepo) Delete(ctx context.Context, userID string) error {
	_, err := r.q.Exec(ctx, `DELETE FROM user_salts WHERE user_id = $1::uuid`, userID)
	return err
}

const userSaltListLinks = `
SELECT u.user_id::text, COALESCE(da.address, '') AS address, u.salt
FROM user_salts u
LEFT JOIN deposit_addresses da ON da.user_id = u.user_id
`

func (r *userSaltRepo) ListLinks(ctx context.Context) ([]domain.UserSaltLink, error) {
	rows, err := r.q.Query(ctx, userSaltListLinks)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []domain.UserSaltLink
	for rows.Next() {
		var link domain.UserSaltLink
		if err := rows.Scan(&link.UserID, &link.Address, &link.Salt); err != nil {
			return nil, err
		}
		out = append(out, link)
	}
	return out, rows.Err()
}