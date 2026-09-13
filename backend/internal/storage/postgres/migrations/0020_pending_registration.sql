-- 0020_pending_registration.sql
--
-- Email-OTP-gated registration. No account row is ever created until the
-- emailed code is verified; the signup payload is staged on the same single-use
-- email_otps row the code lives on. When /auth/otp/verify succeeds with a
-- pending payload present, the service creates the user, stamps
-- email_verified_at, issues a session, and clears the row. Resends issued via
-- /auth/otp/send must NOT wipe a staged (but unverified) signup payload, so
-- these columns are only written at stage time.
--
-- Idempotent: migrations re-run on every boot.

ALTER TABLE email_otps ADD COLUMN IF NOT EXISTS first_name  text;
ALTER TABLE email_otps ADD COLUMN IF NOT EXISTS last_name   text;
ALTER TABLE email_otps ADD COLUMN IF NOT EXISTS phone       text;
ALTER TABLE email_otps ADD COLUMN IF NOT EXISTS password_hash text;