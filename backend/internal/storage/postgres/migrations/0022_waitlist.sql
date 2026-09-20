-- 0022_waitlist.sql
--
-- Early-access waitlist. One row per (normalized) email; joins are recorded
-- the moment they land so the landing page can capture signups without a full
-- account. Signals the product team while /auth/otp handles real onboarding.
--
-- Idempotent: migrations re-run on every boot.

CREATE TABLE IF NOT EXISTS waitlist (
    email      text        PRIMARY KEY,
    created_at timestamptz NOT NULL DEFAULT now()
);