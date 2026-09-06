#!/usr/bin/env bash
# Local end-to-end playground: hardhat node + real-mode API server.
# Everything here is worthless local test money. Safe to re-run.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTRACTS="$ROOT/backend/contracts"

# 0. Sandbox database (keeps rehearsals off the dev database).
docker exec globmint-postgres psql -U globmint -d postgres -tAc \
  "SELECT 1 FROM pg_database WHERE datname='globmint_local'" | grep -q 1 || \
  docker exec globmint-postgres psql -U globmint -d postgres \
    -c "CREATE DATABASE globmint_local" > /dev/null

# 1. Local chain (skip if already up — it holds our deployed contracts).
if ! curl -s -m 3 -X POST http://127.0.0.1:8545 \
    -H 'Content-Type: application/json' \
    --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}' \
    | grep -q 0x539; then
  echo "starting hardhat node..."
  setsid nohup npx hardhat node > /tmp/hardhat-node.log 2>&1 < /dev/null & disown
  sleep 6
fi

# 2. Deploy vault + mint test USDC on first run only (redeploys change
#    addresses, which would desync .env.local).
if [ ! -f "$CONTRACTS/deployments/dev.json" ]; then
  echo "running devsetup (first run only)..."
  (cd "$CONTRACTS" && npx hardhat run scripts/devsetup.js --network localhost)
else
  echo "reusing deployments/dev.json (delete it to redeploy fresh)"
fi

# 3. API server in real-localhost mode.
PID=$(ss -ltnp 2>/dev/null | grep ':8081' | grep -oP 'pid=\K[0-9]+' | head -1 || true)
[ -n "${PID:-}" ] && kill "$PID" && sleep 1
echo "starting server (local real mode)..."
set -a
# shellcheck disable=SC1091
. "$ROOT/.env.local"
set +a
setsid nohup /tmp/globmint-server > /tmp/server-8081.log 2>&1 < /dev/null & disown
sleep 4
curl -s -o /dev/null -w "health=%{http_code}\n" http://127.0.0.1:8081/health
echo "Top Up in the app now shows a real local deposit address."
echo "Send test USDC: (cd backend/contracts && SEND_AMOUNT=25 npx hardhat run scripts/devdepositor.js --network localhost)"
