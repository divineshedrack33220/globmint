package fees

import "testing"

// Default schedule used across tests: 20 bps (0.2%), min 1000 kobo (₦10),
// cap 10000 kobo (₦100).
const (
	testBPS = 20
	testMin = 1000
	testCap = 10000
)

func TestComputeWithdrawalFee(t *testing.T) {
	cases := []struct {
		name               string
		amount, bps, min, cap int64
		want               int64
	}{
		{"percentage wins", 1_000_000, testBPS, testMin, testCap, 2000},       // 1M * 20/10000
		{"minimum applies", 100_000, testBPS, testMin, testCap, 1000},         // raw 200 -> min
		{"cap applies", 5_000_000, testBPS, testMin, testCap, 10000},          // raw 10000 -> cap
		{"cap applies large", 50_000_000, testBPS, testMin, testCap, 10000},   // raw 100000 -> cap
		{"zero amount", 0, testBPS, testMin, testCap, 0},
		{"negative amount", -500, testBPS, testMin, testCap, 0},
		{"disabled bps", 5_000_000, 0, testMin, testCap, 0},
		{"disabled all zero", 5_000_000, 0, 0, 0, 0},
		{"zero cap disables", 5_000_000, testBPS, 0, 0, 0},
		{"custom schedule", 2_000_000, 100, 0, 1_000_000, 20000},              // 1% of 2M
		{"huge amount no overflow", 9_000_000_000_000_000_000, testBPS, testMin, testCap, 10000},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := ComputeWithdrawalFee(tc.amount, tc.bps, tc.min, tc.cap); got != tc.want {
				t.Errorf("ComputeWithdrawalFee(%d, %d, %d, %d) = %d, want %d",
					tc.amount, tc.bps, tc.min, tc.cap, got, tc.want)
			}
		})
	}
}
