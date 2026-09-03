package money

import (
	"errors"
	"testing"
)

func TestFromMajorUnits(t *testing.T) {
	tests := []struct {
		in   string
		want int64
	}{
		{"1250000.50", 125000050},
		{"5", 500},
		{"0", 0},
		{"0.01", 1},
		{"10.55", 1055},
	}
	for _, tt := range tests {
		got, err := FromMajorUnits(tt.in)
		if err != nil {
			t.Fatalf("FromMajorUnits(%q) unexpected error: %v", tt.in, err)
		}
		if got.Minor() != tt.want {
			t.Errorf("FromMajorUnits(%q) = %d, want %d", tt.in, got.Minor(), tt.want)
		}
	}
}

func TestFromMajorUnitsRejectsNegative(t *testing.T) {
	if _, err := FromMajorUnits("-5.00"); !errors.Is(err, ErrNegative) {
		t.Fatalf("expected ErrNegative, got %v", err)
	}
}

func TestString(t *testing.T) {
	if got := FromMinorUnits(125000050).String(); got != "1250000.50" {
		t.Errorf("String() = %q, want %q", got, "1250000.50")
	}
	if got := (Money{}).String(); got != "0.00" {
		t.Errorf("zero String() = %q, want %q", got, "0.00")
	}
}

func TestAdd(t *testing.T) {
	a := FromMinorUnits(100)
	b := FromMinorUnits(250)
	got, err := a.Add(b)
	if err != nil {
		t.Fatalf("Add unexpected error: %v", err)
	}
	if got.Minor() != 350 {
		t.Errorf("Add = %d, want 350", got.Minor())
	}
}

func TestSub(t *testing.T) {
	a := FromMinorUnits(300)
	b := FromMinorUnits(100)
	got, err := a.Sub(b)
	if err != nil {
		t.Fatalf("Sub unexpected error: %v", err)
	}
	if got.Minor() != 200 {
		t.Errorf("Sub = %d, want 200", got.Minor())
	}
}

func TestPercent(t *testing.T) {
	// 25% of 100.00 = 25.00
	m := MustFromMajorUnits("100.00")
	got, err := m.Percent(2500)
	if err != nil {
		t.Fatalf("Percent unexpected error: %v", err)
	}
	if got.Minor() != 2500 {
		t.Errorf("Percent(2500) = %d, want 2500", got.Minor())
	}
	if _, err := m.Percent(10001); err == nil {
		t.Error("expected error for basis points out of range")
	}
}

func TestMulRatioRounds(t *testing.T) {
	// 100 minor * 1/3 = 33.33... -> 33 (round half down on .33)
	m := FromMinorUnits(100)
	got, err := m.MulRatio(1, 3)
	if err != nil {
		t.Fatalf("MulRatio unexpected error: %v", err)
	}
	if got.Minor() != 33 {
		t.Errorf("MulRatio(1,3) = %d, want 33", got.Minor())
	}
	if _, err := m.MulRatio(1, 0); !errors.Is(err, ErrDivideByZero) {
		t.Errorf("expected ErrDivideByZero, got %v", err)
	}
}

func TestCompareAndZero(t *testing.T) {
	a, b := FromMinorUnits(100), FromMinorUnits(200)
	if a.Compare(b) != -1 {
		t.Error("expected -1")
	}
	if b.Compare(a) != 1 {
		t.Error("expected 1")
	}
	if a.Compare(a) != 0 {
		t.Error("expected 0")
	}
	if !a.IsNegative() && a.IsZero() {
		t.Error("nonzero amount reported zero")
	}
	if !(Money{}).IsZero() {
		t.Error("zero value not reported zero")
	}
}

func TestRoundTrip(t *testing.T) {
	m := MustFromMajorUnits("1234.56")
	if FromMinorUnits(m.Minor()).String() != "1234.56" {
		t.Error("minor round-trip mismatch")
	}
	if m.Major() != 1234 {
		t.Errorf("Major() = %d, want 1234", m.Major())
	}
}
