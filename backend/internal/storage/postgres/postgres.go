package postgres

import (
	"context"
	"embed"
	"fmt"
	"strings"
	"sync"

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

func (s *Store) UserRepo() storage.UserRepository         { return NewUserRepo(s.q) }
func (s *Store) SessionRepo() storage.SessionRepository     { return NewSessionRepo(s.q) }
func (s *Store) AccountRepo() storage.AccountRepository     { return NewAccountRepo(s.q) }
func (s *Store) LedgerRepo() storage.LedgerRepository       { return NewLedgerRepo(s.q) }
func (s *Store) BeneficiaryRepo() storage.BeneficiaryRepository { return NewBeneficiaryRepo(s.q) }
func (s *Store) BankAccountRepo() storage.BankAccountRepository { return NewBankAccountRepo(s.q) }
func (s *Store) ExchangeRateRepo() storage.ExchangeRateRepository { return NewExchangeRateRepo(s.q) }
func (s *Store) DepositAddressRepo() storage.DepositAddressRepository { return NewDepositAddressRepo(s.q) }
func (s *Store) SecurityEventRepo() storage.SecurityEventRepository { return NewSecurityEventRepo(s.q) }
func (s *Store) NotificationRepo() storage.NotificationRepository { return NewNotificationRepo(s.q) }
func (s *Store) IndexerStateRepo() storage.IndexerStateRepository { return NewIndexerStateRepo(s.q) }
func (s *Store) IndexerEventRepo() storage.IndexerEventRepository { return NewIndexerEventRepo(s.q) }
func (s *Store) ElevationRepo() storage.ElevationRepository { return NewElevationRepo(s.q) }
func (s *Store) VaultCloneRepo() storage.VaultCloneRepository { return NewVaultCloneRepo(s.q) }
func (s *Store) UserSaltsRepo() storage.UserSaltsRepository { return NewUserSaltsRepo(s.q) }
func (s *Store) EmailOTPRepo() storage.EmailOTPRepository     { return NewEmailOTPRepo(s.q) }

// TryAcquireIndexerLeadership grabs a session-level Postgres advisory lock on
// a dedicated connection so exactly one indexer instance scans at a time. The
// returned release func must be called exactly once when the process gives up
// leadership (or ctx is cancelled); a crashed process releases automatically
// because its session dies, letting a standby take over on the next poll.
func (s *Store) TryAcquireIndexerLeadership(ctx context.Context, key int64) (func(), bool, error) {
	conn, err := s.pool.Acquire(ctx)
	if err != nil {
		return nil, false, fmt.Errorf("acquire leader connection: %w", err)
	}
	var got bool
	if err := conn.QueryRow(ctx, `SELECT pg_try_advisory_lock($1)`, key).Scan(&got); err != nil {
		conn.Release()
		return nil, false, fmt.Errorf("try advisory lock: %w", err)
	}
	if !got {
		conn.Release()
		return nil, false, nil
	}
	var releaseOnce sync.Once
	release := func() {
		releaseOnce.Do(func() {
			_, _ = conn.Exec(context.Background(), `SELECT pg_advisory_unlock($1)`, key)
			conn.Release()
		})
	}
	return release, true, nil
}
