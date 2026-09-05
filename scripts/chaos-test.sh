#!/usr/bin/env bash
# Chaos / hot-path test for the Globmint API.
#
# Runs the in-process load tester twice:
#   1. clean  - asserts hot-path latency budget + zero HTTP failures
#   2. chaos  - injects 20% failures + up to 800ms latency and asserts the
#               injected failures were actually observed and 503s are served
#
# Requirements: Docker Postgres on :5434 (or GLOBMINT_TEST_DATABASE_URL).
set -euo pipefail

cd "$(dirname "$0")/../backend"

fmt() { printf '\033[1;36m[chaos-test]\033[0m %s\n' "$*"; }

if [ -z "${GLOBMINT_TEST_DATABASE_URL:-}" ]; then
  fmt "using default dev DSN (127.0.0.1:5434)"
fi

fmt "1/3 clean run (budget p95<100ms, no failures) ..."
go run ./cmd/loadtest -users 8 -duration 4s -max-p95 100ms

fmt "2/3 chaos run (failure_rate=0.2, latency<=800ms) ..."
go run ./cmd/loadtest -users 8 -duration 6s -chaos-failure-rate 0.2 -chaos-latency-max-ms 800

fmt "3/3 metrics histogram (live dev server, optional) ..."
if curl -sf http://127.0.0.1:8081/metrics | grep -q http_request_duration_ms; then
  fmt "dev server /metrics exposes http_request_duration_ms histogram"
else
  echo "  warning: dev server not running or binary predates the histogram; skipped"
fi

fmt "ALL CHECKS PASSED"