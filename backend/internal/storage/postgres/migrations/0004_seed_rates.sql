-- 0004_seed_rates.sql
-- Seed the exchange-rate book with the primary NGN <-> USDT pairs.
-- rate_minor is the price in minor units of the quote currency per 1 major
-- unit of the base currency (MinorUnit = 100).
--
-- USDT -> NGN : 1 USDT = 1604.50 NGN
--   base=USDT, quote=NGN, rate_minor=160450 (1604.50 * 100)
INSERT INTO exchange_rates (base, quote, rate_minor, fee_bps, min_minor, max_minor, status)
VALUES
    ('USDT', 'NGN', 160450, 50, 1000, 1000000000, 'active')
ON CONFLICT (base, quote) DO UPDATE
    SET rate_minor = EXCLUDED.rate_minor,
        fee_bps    = EXCLUDED.fee_bps,
        status     = EXCLUDED.status,
        updated_at = now();
