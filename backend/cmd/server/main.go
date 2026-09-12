package main

import (
	"context"
	"errors"
	"flag"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"globmint/backend/internal/config"
	"globmint/backend/internal/events"
	"globmint/backend/internal/httpapi"
	"globmint/backend/internal/httpapi/middleware"
	"globmint/backend/internal/infrastructure/blockchain"
	"globmint/backend/internal/infrastructure/rates"
	"globmint/backend/internal/services"
	"globmint/backend/internal/storage/postgres"
)

func main() {
	indexerOnly := flag.Bool("indexer-only", false, "run only the vault indexer + elevation sweeper (leader-elected); serve no HTTP")
	flag.Parse()

	cfg := config.Load()

	if err := config.ValidateProduction(cfg); err != nil {
		log.Fatalf("refusing to start: %v", err)
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	if !cfg.HasDatabase() {
		log.Fatal("GLOBMINT_DATABASE_URL is required")
	}

	store, err := postgres.Open(ctx, postgres.Config{DSN: cfg.DatabaseURL, MaxConns: 10})
	if err != nil {
		log.Fatalf("connect to database: %v", err)
	}
	defer store.Close()

	if err := store.RunMigrations(ctx); err != nil {
		log.Fatalf("run migrations: %v", err)
	}

	authSvc := services.NewAuthService(store, cfg.SessionTTL, cfg.SessionSecret)
	balanceSvc := services.NewBalanceService(store)
	ledgerSvc := services.NewLedgerService(store)
	moneySvc := services.NewMoneyService(store)

	// Blockchain settlement layer. Uses the mock service unless the configured
	// mode is "real" and a valid RPC URL is present.
	chainSvc, closeChain, err := blockchain.NewFromConfig(ctx, cfg.Blockchain.Mode, blockchain.EthereumConfig{
		RPCURL:               cfg.Blockchain.RPCURL,
		ChainID:              cfg.Blockchain.ChainID,
		StablecoinSymbol:     cfg.Blockchain.Stablecoin,
		StablecoinDecimals:   cfg.Blockchain.StablecoinDecimals,
		StablecoinContract:   cfg.Blockchain.StablecoinContract,
		CloneFactoryContract: cfg.Blockchain.CloneFactoryContract,
		PrivateKeyHex:        cfg.Blockchain.PrivateKeyHex,
	})
	if err != nil {
		log.Fatalf("initialize blockchain service: %v", err)
	}
	defer closeChain()
	log.Printf("blockchain service mode=%s network=%s", cfg.Blockchain.Mode, cfg.Blockchain.Network)

	// The on-chain deposit address is the backend signer (vault) when real mode.
	vaultAddress := cfg.Blockchain.VaultAddress
	if vaultAddress == "" {
		vaultAddress = chainSvc.VaultAddress()
	}
	savingsCfg := services.FromConfig(cfg)
	savingsCfg.VaultAddress = vaultAddress
	savingsSvc := services.NewSavingsService(store, savingsCfg)
	securitySvc := services.NewSecurityService(store)

	// NGN-per-USDC rate (kobo per USDC). There is NO invented fallback: the
	// rate comes from the live market feed, or, when the feed is unreachable,
	// from the last real value persisted in the rate book. If neither exists
	// the server refuses to start rather than serve fake pricing.
	rateMinor := int64(0)
	if er, rerr := store.ExchangeRateRepo().FindByPair(ctx, "USDC", "NGN"); rerr == nil && er.Rate > 0 {
		rateMinor = er.Rate
		log.Printf("market rate: using last real rate from book (%d kobo/USDC)", rateMinor)
	}
	// Live market rate: prefer the feed at boot; keep the stored real value
	// (never an invented one) when it is unreachable.
	rateProvider := rates.New(nil, 5*time.Minute)
	if live, lerr := rateProvider.NGNPerUSDCKobo(ctx); lerr == nil && live > 0 {
		log.Printf("market rate: live feed NGN/USDC kobo = %d", live)
		rateMinor = live
		if serr := services.SyncMarketRate(ctx, store.ExchangeRateRepo(), live); serr != nil {
			log.Printf("market rate: book sync failed (keeping previous rows): %v", serr)
		}
	} else if rateMinor <= 0 {
		log.Fatalf("market rate: no live feed (%v) and no real rate stored in the book; "+
			"refusing to start with invented pricing", lerr)
	} else {
		log.Printf("market rate: feed unreachable, keeping last real stored rate %d (%v)", rateMinor, lerr)
	}
	vaultSvc := services.NewVaultService(store, chainSvc, moneySvc, services.VaultConfig{
		VaultAddress:  vaultAddress,
		VaultContract: cfg.Blockchain.VaultContract, StablecoinSymbol: cfg.Blockchain.Stablecoin,
		StablecoinDecimals:              cfg.Blockchain.StablecoinDecimals,
		Mode:                            cfg.Blockchain.Mode,
		ChainID:                         cfg.Blockchain.ChainID,
		PollInterval:                    8 * time.Second,
		StartBlock:                      uint64(cfg.VaultStartBlock),
		FallbackUserID:                  cfg.VaultFallbackUserID,
		MinConfirmations:                cfg.VaultMinConfirmations,
		WithdrawEnabled:                 cfg.VaultWithdrawEnabled,
		WithdrawMinMinor:                cfg.VaultWithdrawMinMinor,
		WithdrawMaxMinor:                cfg.VaultWithdrawMaxMinor,
		WithdrawDailyCapMinor:           cfg.VaultWithdrawDailyCapMinor,
		WithdrawElevationThresholdMinor: cfg.VaultWithdrawElevationThresholdMinor,
		WithdrawElevationDelay:          cfg.VaultWithdrawElevationDelay,
		WithdrawFeeBPS:                  cfg.WithdrawFeeBPS,
		WithdrawFeeMinMinor:             cfg.WithdrawFeeMinMinor,
		WithdrawFeeCapMinor:             cfg.WithdrawFeeCapMinor,
		PrivacyMode:                     cfg.PrivacyMode,
		RequireUserSignature:            cfg.RequireUserSignature,
	}, rateMinor)

	// Fan-out hub for SSE push; shared by the money handlers and the vault
	// indexer so any balance/transaction change reaches connected clients.
	eventsHub := events.NewHub()

	deps := &httpapi.Deps{
		Auth:          authSvc,
		Balance:       balanceSvc,
		Ledger:        ledgerSvc,
		Money:         moneySvc,
		Savings:       savingsSvc,
		Security:      securitySvc,
		Blockchain:    chainSvc,
		Vault:         vaultSvc,
		Events:        eventsHub,
		OperatorToken: cfg.OperatorToken,
	}
	vaultSvc.Hub = eventsHub

	handler := httpapi.NewHandler(deps, authSvc, cfg.CORSOrigins,
		middleware.RateLimits{AuthBurst: cfg.RateLimitAuthBurst, MoneyBurst: cfg.RateLimitMoneyBurst},
		middleware.ChaosConfig{
			Enabled:      cfg.ChaosFailureRate > 0 || cfg.ChaosLatencyMaxMS > 0,
			FailureRate:  cfg.ChaosFailureRate,
			LatencyMaxMS: cfg.ChaosLatencyMaxMS,
		},
	)

	if *indexerOnly {
		// Headless indexer/sweeper: participates in single-leader election so
		// multiple instances can run against the same Postgres + chain safely,
		// and broadcasts due time-locked withdrawals. No HTTP surface.
		log.Println("indexer-only mode: running indexer + elevation sweeper")
		go vaultSvc.RunIndexer(ctx)
		go vaultSvc.RunElevationSweeper(ctx)
		go runMarketRateRefresher(ctx, store, vaultSvc)
		<-ctx.Done()
		log.Println("indexer-only mode: stopped")
		return
	}

	go vaultSvc.RunIndexer(ctx)
	go vaultSvc.RunElevationSweeper(ctx)
	go runMarketRateRefresher(ctx, store, vaultSvc)

	srv := &http.Server{
		Addr:              cfg.HTTPAddr,
		Handler:           handler,
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
	}

	go func() {
		log.Printf("globmint backend listening on %s", cfg.HTTPAddr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("http server: %v", err)
		}
	}()

	<-ctx.Done()
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Printf("graceful shutdown: %v", err)
	}
	log.Println("globmint backend stopped")
}

// runMarketRateRefresher refreshes the NGN-per-USDC rate every 5 minutes from
// the market feed. Every failure is fail-soft (log only): vault conversions,
// quotes, and clients keep pricing from the last good value.
func runMarketRateRefresher(ctx context.Context, store *postgres.Store, vaultSvc *services.VaultService) {
	provider := rates.New(nil, 5*time.Minute)
	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			live, err := provider.NGNPerUSDCKobo(ctx)
			if err != nil || live <= 0 {
				log.Printf("market rate: refresh failed, keeping last good value: %v", err)
				continue
			}
			vaultSvc.SetRateMinor(live)
			if err := services.SyncMarketRate(ctx, store.ExchangeRateRepo(), live); err != nil {
				log.Printf("market rate: book sync failed: %v", err)
			} else {
				log.Printf("market rate: updated to %d kobo/USDC", live)
			}
		}
	}
}
