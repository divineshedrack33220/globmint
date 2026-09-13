-- 0019_email_otp.sql
--
-- Email one-time passwords (6-digit codes sent via Resend) for email
-- verification. The code is stored ONLY as a SHA-256 hash so a database leak
-- never exposes usable codes; expiry + attempt caps live in columns so brute
-- force is bounded across restarts.
--
-- Idempotent: migrations re-run on every boot.

CREATE TABLE IF NOT EXISTS email_otps (
    email      text        PRIMARY KEY,
    code_hash  text        NOT NULL,
    expires_at timestamptz NOT NULL,
    -- next_send_at rate-limits "resend" requests per email (anti-abuse).
    next_send_at timestamptz,
    attempts   integer     NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified_at timestamptz;