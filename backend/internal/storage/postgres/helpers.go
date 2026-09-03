package postgres

import (
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"globmint/backend/internal/domain"
)

// pgxRow is the minimal scanner shared by pgx.Row and pgx.Rows.
type pgxRow interface {
	Scan(dest ...any) error
}

// mapPgErr translates driver-level errors into typed domain errors so that
// business logic and tests are decoupled from the database driver.
func mapPgErr(err error) error {
	if err == nil {
		return nil
	}
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.ErrNotFound
	}
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		switch pgErr.Code {
		case "23505": // unique_violation
			return domain.ErrConflict
		default:
			// Keep other database errors opaque at the boundary.
			return err
		}
	}
	return err
}
