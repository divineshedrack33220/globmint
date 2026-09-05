-- 0008_audit_log.sql
-- Append-only, tamper-evident audit trail for privileged financial actions.
-- Rows are immutable by convention: revoke UPDATE/DELETE from the app role and
-- grant them only to a Q/A auditor role in a hardened deployment.
CREATE TABLE IF NOT EXISTS audit_events (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id   uuid        REFERENCES users (id) ON DELETE SET NULL,
    actor_email text       NOT NULL DEFAULT '',
    action     text        NOT NULL,
    subject    text        NOT NULL DEFAULT '',
    metadata   jsonb       NOT NULL DEFAULT '{}'::jsonb,
    ip         text        NOT NULL DEFAULT '',
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_events_actor ON audit_events (actor_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_events_action ON audit_events (action, created_at DESC);