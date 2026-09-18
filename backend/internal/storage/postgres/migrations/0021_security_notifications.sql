-- 0021_security_notifications.sql
-- Extends the security activity feed with severity, richer device context, and
-- free-form metadata (never containing secrets — see the auth service), and
-- adds per-user email alert preferences for the "new sign-in" and "failed
-- sign-in" notifications. Both default ON so accounts get more visibility
-- unless the user opts out.

ALTER TABLE security_events
    ADD COLUMN IF NOT EXISTS severity   TEXT NOT NULL DEFAULT 'info',
    ADD COLUMN IF NOT EXISTS user_agent TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS device_id  TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS metadata   JSONB DEFAULT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'chk_security_events_severity'
    ) THEN
        ALTER TABLE security_events
            ADD CONSTRAINT chk_security_events_severity
            CHECK (severity IN ('info', 'warn', 'critical'));
    END IF;
END
$$;

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS notify_new_signin    BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS notify_failed_login  BOOLEAN NOT NULL DEFAULT TRUE;
