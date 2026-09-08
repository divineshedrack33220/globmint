-- 0004_seed_rates.sql
--
-- This migration does NOT invent market prices. It only ensures the four
-- cross rows (NGN <-> USDC/USDT) exist so fee/min/max limits are defined;
-- rate_minor starts at 0 (= "no live rate yet") and is populated exclusively
-- by real market data pulled from the feed at boot and every refresh
-- (see services/market.go). A rate of 0 is never exposed as a price: quote
-- and rate endpoints fail loudly until a real rate is stored.
--
-- ON CONFLICT DO NOTHING is deliberate: a previously persisted real rate
-- must never be clobbered back to anything on a restart (migrations re-run
-- on every boot).
INSERT INTO exchange_rates (base, quote, rate_minor, fee_bps, min_minor, max_minor, status)
VALUES
    ('USDT', 'NGN', 0, 50, 1000, 1000000000, 'active'),
    ('USDC', 'NGN', 0, 50, 1000, 1000000000, 'active'),
    ('NGN',  'USDC', 0, 50, 1000, 1000000000, 'active'),
    ('NGN',  'USDT', 0, 50, 1000, 1000000000, 'active')
ON CONFLICT (base, quote) DO NOTHING;