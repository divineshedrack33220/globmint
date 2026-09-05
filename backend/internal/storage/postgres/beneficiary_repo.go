package postgres

import (
	"context"

	"globmint/backend/internal/domain"
	"globmint/backend/internal/storage"
)

type beneficiaryRepo struct{ q Querier }

func NewBeneficiaryRepo(q Querier) storage.BeneficiaryRepository { return &beneficiaryRepo{q: q} }

const beneficiaryCols = `id::text, user_id::text, name, address, is_favorite, created_at`

func scanBeneficiary(row pgxRow) (*domain.Beneficiary, error) {
	b := &domain.Beneficiary{}
	if err := row.Scan(&b.ID, &b.UserID, &b.Name, &b.Address, &b.IsFavorite, &b.CreatedAt); err != nil {
		return nil, err
	}
	return b, nil
}

func (r *beneficiaryRepo) Create(ctx context.Context, b *domain.Beneficiary) error {
	err := r.q.QueryRow(ctx, `
		INSERT INTO beneficiaries (user_id, name, address, is_favorite)
		VALUES ($1::uuid, $2, $3, $4)
		RETURNING `+beneficiaryCols,
		b.UserID, b.Name, b.Address, b.IsFavorite,
	).Scan(&b.ID, &b.UserID, &b.Name, &b.Address, &b.IsFavorite, &b.CreatedAt)
	return mapPgErr(err)
}

func (r *beneficiaryRepo) ListByUser(ctx context.Context, userID string) ([]domain.Beneficiary, error) {
	rows, err := r.q.Query(ctx, `SELECT `+beneficiaryCols+` FROM beneficiaries WHERE user_id = $1::uuid ORDER BY created_at DESC`, userID)
	if err != nil {
		return nil, mapPgErr(err)
	}
	defer rows.Close()
	var out []domain.Beneficiary
	for rows.Next() {
		b, err := scanBeneficiary(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *b)
	}
	return out, rows.Err()
}

func (r *beneficiaryRepo) Update(ctx context.Context, b *domain.Beneficiary) error {
	tag, err := r.q.Exec(ctx, `
		UPDATE beneficiaries SET name=$1, address=$2, is_favorite=$3
		WHERE id=$4::uuid AND user_id=$5::uuid`,
		b.Name, b.Address, b.IsFavorite, b.ID, b.UserID)
	if err != nil {
		return mapPgErr(err)
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

func (r *beneficiaryRepo) Delete(ctx context.Context, userID, id string) error {
	tag, err := r.q.Exec(ctx, `DELETE FROM beneficiaries WHERE id=$1::uuid AND user_id=$2::uuid`, id, userID)
	if err != nil {
		return mapPgErr(err)
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

func (r *beneficiaryRepo) ToggleFavorite(ctx context.Context, userID, id string) error {
	tag, err := r.q.Exec(ctx, `
		UPDATE beneficiaries SET is_favorite = NOT is_favorite
		WHERE id=$1::uuid AND user_id=$2::uuid`, id, userID)
	if err != nil {
		return mapPgErr(err)
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrNotFound
	}
	return nil
}

func (r *beneficiaryRepo) FindByAddress(ctx context.Context, userID, address string) (*domain.Beneficiary, error) {
	row := r.q.QueryRow(ctx, `
		SELECT `+beneficiaryCols+` FROM beneficiaries
		WHERE user_id=$1::uuid AND address=$2`, userID, address)
	b, err := scanBeneficiary(row)
	if err != nil {
		return nil, mapPgErr(err)
	}
	return b, nil
}
