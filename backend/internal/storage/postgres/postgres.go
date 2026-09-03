package postgres

import (
	"context"
	"embed"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"globmint/backend/internal/storage"
)

// Querier is the minimal surface shared by *pgxpool.Pool, *pgxpool.Tx and
// pgx.Tx, letting repositories run against both a connected pool and an
// in-flight transaction.
type Querier interface {
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

// Store is the Postgres-backed storage root.
type Store struct {
	pool *pgxpool.Pool
	dsn  string
	q    Querier
}

// Config configures the connection pool.
type Config struct {
	DSN      string
	MaxConns int32
}

//go:embed migrations/*.sql
var migrationsFS embed.FS

// Open establishes a connection pool.
func Open(ctx context.Context, cfg Config) (*Store, error) {
	poolCfg, err := pgxpool.ParseConfig(cfg.DSN)
	if err != nil {
		return nil, fmt.Errorf("parse dsn: %w", err)
	}
	if cfg.MaxConns > 0 {
		poolCfg.MaxConns = cfg.MaxConns
	}
	pool, err := pgxpool.NewWithConfig(ctx, poolCfg)
	if err != nil {
		return nil, fmt.Errorf("create pool: %w", err)
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("ping: %w", err)
	}
	return &Store{pool: pool, dsn: cfg.DSN, q: pool}, nil
}

// RunMigrations applies embedded .sql files in lexicographic order. Migration
// files may contain multiple statements, so they run on a dedicated connection
// in simple-query protocol; the application pool keeps default (extended)
// protocol so pgx can type-encode parameters correctly (e.g. jsonb).
func (s *Store) RunMigrations(ctx context.Context) error {
	entries, err := migrationsFS.ReadDir("migrations")
	if err != nil {
		return err
	}
	connCfg, err := pgx.ParseConfig(s.dsn)
	if err != nil {
		return fmt.Errorf("parse migration dsn: %w", err)
	}
	connCfg.DefaultQueryExecMode = pgx.QueryExecModeSimpleProtocol
	conn, err := pgx.ConnectConfig(ctx, connCfg)
	if err != nil {
		return fmt.Errorf("connect for migrations: %w", err)
	}
	defer func() { _ = conn.Close(ctx) }()

	for _, e := range entries {
		if !strings.HasSuffix(e.Name(), ".sql") {
			continue
		}
		b, err := migrationsFS.ReadFile("migrations/" + e.Name())
		if err != nil {
			return err
		}
		if _, err := conn.Exec(ctx, string(b)); err != nil {
			return fmt.Errorf("apply migration %s: %w", e.Name(), err)
		}
	}
	return nil
}

// Close releases pool resources.
func (s *Store) Close() { s.pool.Close() }

// RunInTx executes fn within a database transaction, exposing a storage.Store
// whose repositories are bound to the transaction. If fn returns an error the
// transaction is rolled back, otherwise it is committed.
func (s *Store) RunInTx(ctx context.Context, fn func(store storage.Store) error) error {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	store := &Store{pool: s.pool, q: tx}
	defer func() {
		_ = tx.Rollback(ctx)
	}()
	if err := fn(store); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func (s *Store) UserRepo() storage.UserRepository     { return NewUserRepo(s.q) }
func (s *Store) SessionRepo() storage.SessionRepository { return NewSessionRepo(s.q) }
func (s *Store) AccountRepo() storage.AccountRepository { return NewAccountRepo(s.q) }
func (s *Store) LedgerRepo() storage.LedgerRepository   { return NewLedgerRepo(s.q) }
