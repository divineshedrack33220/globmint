package domain

import "time"

// WithdrawalElevationStatus is the lifecycle state of a time-locked
// (elevated) withdrawal.
type WithdrawalElevationStatus string

const (
	// ElevationPending waits for its release_after timestamp to pass.
	ElevationPending WithdrawalElevationStatus = "pending"
	// ElevationBroadcasting has been claimed by a sweeper and its chain tx is
	// being broadcast.
	ElevationBroadcasting WithdrawalElevationStatus = "broadcasting"
	// ElevationBroadcast finished: the signer broadcast the tx and the ledger
	// was debited.
	ElevationBroadcast WithdrawalElevationStatus = "broadcast"
	// ElevationCancelled by the user while still pending.
	ElevationCancelled WithdrawalElevationStatus = "cancelled"
	// ElevationExpired means the pre-signed intent can no longer be relayed
	// (its deadline passed, or a newer withdrawal consumed the signed nonce).
	// The user is told the reason and must re-request.
	ElevationExpired WithdrawalElevationStatus = "expired"
)

// WithdrawalElevation is a high-value withdrawal held by the time-lock so
// operations/user have a window to react before the signer broadcasts it.
type WithdrawalElevation struct {
	ID             string
	UserID         string
	Destination    string
	AmountNgnMinor int64
	// FeeMinor is the withdrawal fee (kobo) computed at request time. It is
	// only debited when the sweeper broadcasts; cancellations never charge it.
	FeeMinor        int64
	Status          WithdrawalElevationStatus
	RequestedAt     time.Time
	ReleaseAfter    time.Time
	BroadcastTxHash string
	BroadcastAt     *time.Time
	IdempotencyKey  string
	// Signature + Deadline + SignedNonce + SignedAmountBase persist the
	// user's EIP-712 intent so the sweeper can relay the EXACT signed
	// withdrawWithSig call at release (never re-signing or mutating it).
	Signature       string
	Deadline        int64
	SignedNonce     uint64
	SignedAmountBase int64
	// ExpiredReason explains why an expired elevation could not be relayed.
	ExpiredReason string
}

// HasSignedIntent reports whether this elevation carries a user signature.
func (e *WithdrawalElevation) HasSignedIntent() bool {
	return e.Signature != ""
}

// IndexerEventType identifies what an indexer log row represents. Types:
//   - IndexerEventDeposited    — a credited transfer (vault custody -> user ledger).
//   - IndexerEventUnattributed — a transfer into the vault the indexer could
//     not assign to a user (direct send from an unlinked wallet). Flagged for
//     operator review; operators attribute it via AttributeDeposit.
type IndexerEventType = string

const (
	IndexerEventDeposited    IndexerEventType = "deposited"
	IndexerEventUnattributed IndexerEventType = "unattributed"
)

// IndexerEvent is a durable log line recorded for each confirmed vault transfer
// the indexer ingests. It is the on-chain-agnostic audit trail that makes
// replay fast (no RPC re-fetch) and ingest idempotent.
type IndexerEvent struct {
	TxHash      string
	LogIndex    uint64
	BlockNumber uint64
	// EventType identifies the event kind (see IndexerEventType constants).
	EventType IndexerEventType
	From      string
	To        string
	// ValueBase is the token base-unit amount (e.g. 6-decimals USDC).
	ValueBase int64
}
