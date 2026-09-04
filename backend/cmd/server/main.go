package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"globmint/backend/internal/config"
	"globmint/backend/internal/httpapi"
	"globmint/backend/internal/infrastructure/blockchain"
	"globmint/backend/internal/services"
	"globmint/backend/internal/storage/postgres"
)

func main() {
	cfg := config.Load()

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

	authSvc := services.NewAuthService(store, cfg.SessionTTL)
	balanceSvc := services.NewBalanceService(store)
	ledgerSvc := services.NewLedgerService(store)
	moneySvc := services.NewMoneyService(store)
	savingsSvc := services.NewSavingsService(store, services.FromConfig(cfg))
	securitySvc := services.NewSecurityService(store)

	// Blockchain settlement layer. Uses the mock service unless the configured
	// mode is "real" and a valid RPC URL is present.
	chainSvc, closeChain, err := blockchain.NewFromConfig(ctx, cfg.Blockchain.Mode, blockchain.EthereumConfig{
		RPCURL:              cfg.Blockchain.RPCURL,
		ChainID:             cfg.Blockchain.ChainID,
		StablecoinSymbol:    cfg.Blockchain.Stablecoin,
		StablecoinDecimals:  cfg.Blockchain.StablecoinDecimals,
		StablecoinContract:  cfg.Blockchain.StablecoinContract,
		PrivateKeyHex:       cfg.Blockchain.PrivateKeyHex,
	})
	if err != nil {
		log.Fatalf("initialize blockchain service: %v", err)
	}
	defer closeChain()
	log.Printf("blockchain service mode=%s network=%s", cfg.Blockchain.Mode, cfg.Blockchain.Network)

	deps := &httpapi.Deps{
		Auth:       authSvc,
		Balance:    balanceSvc,
		Ledger:     ledgerSvc,
		Money:      moneySvc,
		Savings:    savingsSvc,
		Security:   securitySvc,
		Blockchain: chainSvc,
	}
	handler := httpapi.NewHandler(deps, authSvc)

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
