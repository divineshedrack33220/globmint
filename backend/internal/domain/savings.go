package domain

import (
	"errors"
	"regexp"
	"time"
)

// DepositAddress links a Globmint user to their own on-chain wallet address used
// for non-custodial deposits into the GlobmintVault contract. The system never
// holds the user's private key; it only records which address belongs to which
// user so clients can build approve + deposit calls against the vault.
type DepositAddress struct {
	UserID    string
	Address   string // the user's own 0x-prefixed Ethereum wallet address
	CreatedAt time.Time
	UpdatedAt time.Time
}

// UserSaltLink pairs a user's linked deposit address with their privacy salt,
// enabling the vault indexer to resolve keccak256(user, salt) commitment-based
// deposits back to a Globmint user in privacy mode. The field name "Address"
// deliberately mirrors DepositAddress.Address (the user's on-chain wallet).
type UserSaltLink struct {
	UserID  string
	Address string // on-chain deposit address ("" when the user has no link)
	Salt    []byte // from user_salts
}

// addressRe matches a well-formed 0x-prefixed 40-hex-char Ethereum address.
var addressRe = regexp.MustCompile(`^0x[0-9a-fA-F]{40}$`)

// ValidateDepositAddress normalizes and validates a deposit address string.
func ValidateDepositAddress(addr string) (string, error) {
	if addr == "" {
		return "", errors.New("deposit address is required")
	}
	if !addressRe.MatchString(addr) {
		return "", errors.New("invalid Ethereum address")
	}
	return addr, nil
}
