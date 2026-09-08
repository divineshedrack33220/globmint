-- 0014_unattributed_indexer_events.sql
-- Direct transfers into the vault from wallets that no user has linked are
-- no longer dropped silently: the indexer flags them as 'unattributed' and
-- operators attribute them to a user. Widen the event_type constraint to
-- allow the new kind without touching existing rows (the check is replaced
-- in place; the transaction is atomic on the migration runner).
ALTER TABLE indexer_events
    DROP CONSTRAINT IF EXISTS indexer_events_event_type_check;
ALTER TABLE indexer_events
    ADD CONSTRAINT indexer_events_event_type_check
    CHECK (event_type IN ('deposited', 'withdrawn', 'unattributed'));