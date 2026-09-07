package services

import (
	"context"
	"encoding/json"
	"strings"
	"testing"

	"globmint/backend/internal/domain"
)

// privacySavings builds a SavingsService with privacy mode = wantPrivacy.
func privacySavings(st store, wantPrivacy bool) *SavingsService {
	return NewSavingsService(st, SavingsConfig{
		VaultContract:      "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238",
		VaultAddress:       "0xVault", // informational: not used by these tests
		StablecoinSymbol:   "USDC",
		StablecoinName:     "USD Coin",
		StablecoinDecimals: 6,
		StablecoinContract: "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238",
		Network:            "sepolia",
		ChainID:            11155111,
		Mode:               "real",
		PrivacyMode:        wantPrivacy,
	})
}

func saltFor(t *testing.T, st store, userID string) []byte {
	t.Helper()
	salt, err := st.UserSaltsRepo().FindByUser(context.Background(), userID)
	if err != nil {
		if err == domain.ErrNotFound {
			return nil
		}
		t.Fatalf("find user salt: %v", err)
	}
	return salt
}

// privAddrFor derives a 40-hex-char on-chain address unique to this user so
// tests never collide with rows left by earlier runs (the address is UNIQUE).
func privAddrFor(userID string) string {
	hex := strings.ReplaceAll(userID, "-", "") // 32 hex chars
	return "0x" + "C0FFeE00" + hex[:32]        // 8 + 32 = 40
}

// otherPrivAddrFor is a second distinct unique address for the same user.
func otherPrivAddrFor(userID string) string {
	hex := strings.ReplaceAll(userID, "-", "")
	return "0x" + "C0FFeE01" + hex[:32]
}

// TestSetDepositAddressPrivacyModeCreatesSalt: in privacy mode, linking a
// deposit address generates + stores a fresh 16-byte random salt, and the
// response reports privacy_enabled=true. The salt is NOT returned.
func TestSetDepositAddressPrivacyModeCreatesSalt(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "savings-priv-salt@example.com")
	svc := privacySavings(st, true)

	info, err := svc.SetDepositAddress(ctx, u.ID, privAddrFor(u.ID))
	if err != nil {
		t.Fatalf("set deposit address: %v", err)
	}
	if !info.PrivacyEnabled {
		t.Error("expected privacy_enabled=true with PrivacyMode on")
	}

	salt := saltFor(t, st, u.ID)
	if len(salt) != 16 {
		t.Errorf("stored salt = %d bytes, want 16", len(salt))
	}
}

// TestGetDepositInfoDoesNotLeakSaltOnDepositAddress: GET /savings/deposit-info
// (and update) responses carry privacy_enabled but nothing that would let a
// caller reproduce the commitment (no salt, no commitment, no hash).
func TestGetDepositInfoDoesNotLeakSaltOnDepositAddress(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "savings-priv-leak@example.com")
	svc := privacySavings(st, true)

	if _, err := svc.SetDepositAddress(ctx, u.ID, privAddrFor(u.ID)); err != nil {
		t.Fatalf("set deposit address: %v", err)
	}

	info, err := svc.GetDepositInfo(ctx, u.ID)
	if err != nil {
		t.Fatalf("get deposit info: %v", err)
	}
	if !info.PrivacyEnabled {
		t.Error("expected privacy_enabled=true")
	}
	if info.Address == "" || info.VaultContract == "" {
		t.Error("deposit info should still expose the public deposit contract details")
	}

	raw, err := json.Marshal(info)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	for _, banned := range []string{`"salt"`, `"commitment"`, `"keccak"`} {
		if strings.Contains(string(raw), banned) {
			t.Errorf("deposit-info response leaks %s: %s", banned, raw)
		}
	}
}

// TestSetDepositAddressRelinkPreservesSalt: re-linking an address within
// privacy mode preserves the existing salt (documented behaviour): a
// commitment already funded on-chain stays resolvable after the re-link.
func TestSetDepositAddressRelinkPreservesSalt(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "savings-priv-relink@example.com")
	svc := privacySavings(st, true)

	if _, err := svc.SetDepositAddress(ctx, u.ID, privAddrFor(u.ID)); err != nil {
		t.Fatalf("first link: %v", err)
	}
	salt1 := saltFor(t, st, u.ID)
	if len(salt1) != 16 {
		t.Fatalf("first salt = %d bytes, want 16", len(salt1))
	}

	if _, err := svc.SetDepositAddress(ctx, u.ID, otherPrivAddrFor(u.ID)); err != nil {
		t.Fatalf("re-link: %v", err)
	}
	salt2 := saltFor(t, st, u.ID)
	if string(salt1) != string(salt2) {
		t.Error("re-linking must preserve the existing salt (commitment stability), got a new salt")
	}
}

// TestSetDepositAddressNonPrivacyModeNoSalt: without privacy mode no salt row
// is created and the response reports privacy_enabled=false. Changing the
// address itself works exactly as before.
func TestSetDepositAddressNonPrivacyModeNoSalt(t *testing.T) {
	st := testStore(t)
	ctx := context.Background()
	u := newTestUser(t, st, "savings-legacy-salt@example.com")
	svc := privacySavings(st, false)

	info, err := svc.SetDepositAddress(ctx, u.ID, privAddrFor(u.ID))
	if err != nil {
		t.Fatalf("set deposit address: %v", err)
	}
	if info.PrivacyEnabled {
		t.Error("expected privacy_enabled=false with PrivacyMode off")
	}
	if salt := saltFor(t, st, u.ID); salt != nil {
		t.Errorf("no salt row expected in legacy mode, got %d bytes", len(salt))
	}
}