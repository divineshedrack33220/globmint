-- 0004_seed_rates.sql
-- Seed the exchange-rate book with the primary NGN <-> USDT pairs.
-- rate_minor is the price in minor units of the quote currency per 1 major
-- unit of the base currency (MinorUnit = 100).
--
-- USDT -> NGN : 1 USDT = 1604.50 NGN
--   base=USDT, quote=NGN, rate_minor=160450 (1604.50 * 100)
-- USDC -> NGN : 1 USDC = 1600.00 NGN
--   base=USDC, quote=NGN, rate_minor=160000 (1600.00 * 100)
-- Reverse pairs (NGN -> USDC / NGN -> USDT) are scaled to a theoretical
-- $0.62 output per 100 NGN for demo convenience with the integer kobo model.
INSERT INTO exchange_rates (base, quote, rate_minor, fee_bps, min_minor, max_minor, status)
VALUES
    ('USDT', 'NGN', 160450, 50, 1000, 1000000000, 'active'),
    ('USDC', 'NGN', 160000, 50, 1000, 1000000000, 'active'),
    ('NGN',  'USDC', 62,    50, 1000, 1000000000, 'active'),
    ('NGN',  'USDT', 62,    50, 1000, 1000000000, 'active')
ON CONFLICT (base, quote) DO UPDATE
    SET rate_minor = EXCLUDED.rate_minor,
        fee_bps    = EXCLUDED.fee_bps,
        status     = EXCLUDED.status,
        updated_at = now();
