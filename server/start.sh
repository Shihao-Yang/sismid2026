#!/usr/bin/env bash
# Start the SISMID Codex broker. Reads the passcode from ./passcode (mode 600),
# so it never appears on a command line. Run from the deploy directory on the host.
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -s passcode ]; then
  echo "Create the passcode file first:" >&2
  echo "  printf %s 'YOUR-STRONG-PASSCODE' > passcode && chmod 600 passcode" >&2
  exit 1
fi
if pgrep -f "[s]erve.py" >/dev/null 2>&1; then
  echo "Broker already running. Stop it first: ./stop.sh" >&2
  exit 1
fi

export SISMID_PASSCODE="$(cat passcode)"
export SISMID_CRED_DIR="${SISMID_CRED_DIR:-creds}"
export SISMID_PORT="${SISMID_PORT:-8080}"

nohup python3 serve.py > broker.out 2>&1 &
sleep 1
n="$(ls creds/auth-*.json 2>/dev/null | wc -l | tr -d ' ')"
echo "Started broker pid $! on port $SISMID_PORT with $n credentials."
echo "Health check:  curl -s http://127.0.0.1:$SISMID_PORT/healthz"
