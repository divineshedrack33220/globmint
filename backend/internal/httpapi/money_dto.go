package httpapi

import (
	"time"

	"globmint/backend/internal/domain"
)

type amountRequest struct {
	Amount   string `json:"amount"`            // major-unit decimal string
	Currency string `json:"currency,omitempty"` // defaults to NGN
}

type depositRequest struct {
	Amount   string `json:"amount"`
	Currency string `json:"currency,omitempty"`
}

type withdrawRequest struct {
	Amount     string `json:"amount"`
	Currency   string `json:"currency,omitempty"`
	BankID     string `json:"bank_id"`
	Narration  string `json:"narration,omitempty"`
}

type transferRequest struct {
	Amount       string  `json:"amount"`
	Currency     string  `json:"currency,omitempty"`
	ToKind       string  `json:"to_kind,omitempty"` // savings | available
	AccountName  string  `json:"account_name,omitempty"`
	AccountNumber string `json:"account_number,omitempty"`
	BankName     string  `json:"bank_name,omitempty"`
	Narration    string  `json:"narration,omitempty"`
}

type convertQuoteRequest struct {
	Amount       string `json:"amount"`
	FromCurrency string `json:"from_currency"`
	ToCurrency   string `json:"to_currency"`
}

type convertRequest struct {
	Amount       string `json:"amount"`
	FromCurrency string `json:"from_currency"`
	ToCurrency   string `json:"to_currency"`
}

type beneficiaryRequest struct {
	Name          string `json:"name"`
	Bank          string `json:"bank"`
	AccountNumber string `json:"account_number"`
	IsFavorite    bool   `json:"is_favorite"`
}

type beneficiaryUpdateRequest struct {
	Name          string `json:"name"`
	Bank          string `json:"bank"`
	AccountNumber string `json:"account_number"`
	IsFavorite    bool   `json:"is_favorite"`
}

type bankAccountRequest struct {
	BankName      string `json:"bank_name"`
	BankCode      string `json:"bank_code"`
	AccountNumber string `json:"account_number"`
	AccountName   string `json:"account_name"`
	IsDefault     bool   `json:"is_default"`
}

type beneficiaryResponse struct {
	ID            string `json:"id"`
	Name          string `json:"name"`
	Bank          string `json:"bank"`
	AccountNumber string `json:"account_number"`
	IsFavorite    bool   `json:"is_favorite"`
}

type bankAccountResponse struct {
	ID            string `json:"id"`
	BankName      string `json:"bank_name"`
	BankCode      string `json:"bank_code"`
	AccountNumber string `json:"account_number"`
	AccountName   string `json:"account_name"`
	IsDefault     bool   `json:"is_default"`
}

type quoteResponse struct {
	InputAmountMajor string `json:"input_amount"`
	InputCurrency     string `json:"input_currency"`
	OutputAmountMajor string `json:"output_amount"`
	OutputCurrency    string `json:"output_currency"`
	RateMajor         string `json:"rate"`
	FeeBPS            int    `json:"fee_bps"`
	FeeAmountMajor    string `json:"fee_amount"`
	ExpiresAt         string `json:"expires_at"`
}

func newBeneficiaryResponse(b *domain.Beneficiary) beneficiaryResponse {
	return beneficiaryResponse{
		ID:            b.ID,
		Name:          b.Name,
		Bank:          b.Bank,
		AccountNumber: b.AccountNumber,
		IsFavorite:    b.IsFavorite,
	}
}

func newBankAccountResponse(a *domain.BankAccount) bankAccountResponse {
	return bankAccountResponse{
		ID:            a.ID,
		BankName:      a.BankName,
		BankCode:      a.BankCode,
		AccountNumber: a.AccountNumber,
		AccountName:   a.AccountName,
		IsDefault:     a.IsDefault,
	}
}

func quoteExpiresAt() string {
	return time.Now().UTC().Add(5 * time.Minute).Format(time.RFC3339)
}
