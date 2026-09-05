package domain

import "time"

// Beneficiary is a saved payee for quick transfers.
type Beneficiary struct {
	ID            string
	UserID        string
	Name          string
	Address       string
	Bank          string
	AccountNumber string
	IsFavorite    bool
	CreatedAt     time.Time
}

// BankAccount is a user's own saved external bank account (for withdrawals).
type BankAccount struct {
	ID            string
	UserID        string
	BankName      string
	BankCode      string
	AccountNumber string
	AccountName   string
	IsDefault     bool
	CreatedAt     time.Time
}

// ExchangeRate quotes a conversion rate between two currencies.
type ExchangeRate struct {
	ID       string
	Base     string
	Quote    string
	Rate     int64 // minor units of quote per 1 major unit of base
	FeeBPS   int   // fee in basis points (1% = 100)
	MinMinor int64
	MaxMinor int64
	Status   string
	CreatedAt time.Time
	UpdatedAt time.Time
}
