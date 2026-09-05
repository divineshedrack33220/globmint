-- 0007_beneficiary_addresses.sql
-- Beneficiaries become saved crypto-address contacts instead of Nigerian bank
-- payees: the bank/account_number pair is replaced by a single crypto address.
-- Re-runs are safe (idempotent).

ALTER TABLE beneficiaries ADD COLUMN IF NOT EXISTS address TEXT NOT NULL DEFAULT '';

-- Copy legacy bank account numbers into the address column only while the
-- legacy column still exists. This keeps the migration re-entrant: on an
-- already-migrated schema (account_number already dropped) the copy is a no-op.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'public'
                 AND table_name = 'beneficiaries'
                 AND column_name = 'account_number') THEN
        UPDATE beneficiaries SET address = account_number WHERE address = '';
    END IF;
END $$;

ALTER TABLE beneficiaries DROP CONSTRAINT IF EXISTS beneficiaries_user_id_bank_account_number_key;
ALTER TABLE beneficiaries DROP COLUMN IF EXISTS bank;
ALTER TABLE beneficiaries DROP COLUMN IF EXISTS account_number;

CREATE UNIQUE INDEX IF NOT EXISTS idx_beneficiaries_user_address ON beneficiaries(user_id, address);