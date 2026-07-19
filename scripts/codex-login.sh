#!/usr/bin/env bash
# Fetch THIS student's Codex credential from the class broker and install it.
#
#   bash scripts/codex-login.sh http://HOST:PORT      # server URL from instructor
#   SISMID_CODEX_SERVER=http://HOST:PORT bash scripts/codex-login.sh
#
# The instructor announces the server URL and passcode in class. You are assigned
# one credential and the server remembers it (a stable id is stored in ~/.codex/),
# so a Codespace restart returns the SAME credential, not a new one. After it runs,
# just launch `codex`.
set -euo pipefail

SERVER="${1:-${SISMID_CODEX_SERVER:-}}"
if [ -z "$SERVER" ]; then
  echo "Server URL not set." >&2
  echo "  bash scripts/codex-login.sh http://HOST:PORT" >&2
  exit 1
fi
SERVER="${SERVER%/}"

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
mkdir -p "$CODEX_HOME"; chmod 700 "$CODEX_HOME" 2>/dev/null || true
AUTH="$CODEX_HOME/auth.json"
IDFILE="$CODEX_HOME/.sismid_client"

# Never clobber an auth.json that Codex may have refreshed (OpenAI's guidance).
if [ -s "$AUTH" ]; then
  echo "Codex already has $AUTH; leaving it in place."
  echo "(Delete it and re-run only if the instructor tells you to.)"
  exit 0
fi

# Stable per-student client id: created once, reused on later runs.
if [ ! -s "$IDFILE" ]; then
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen > "$IDFILE"
  else
    head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$IDFILE"; echo >> "$IDFILE"
  fi
fi
CLIENT="$(tr -d ' \n\r' < "$IDFILE")"

printf 'Class passcode (input hidden): '
if { : < /dev/tty; } 2>/dev/null; then IFS= read -rs PASS < /dev/tty; echo; else IFS= read -rs PASS; echo; fi
[ -n "$PASS" ] || { echo "No passcode entered." >&2; exit 1; }

TMP="$(mktemp)"
code="$(curl -fsS -o "$TMP" -w '%{http_code}' \
          -H "X-Passcode: $PASS" -H "X-Client-Id: $CLIENT" \
          "$SERVER/claim" 2>/dev/null || true)"
unset PASS

case "$code" in
  200)
    if head -c 1 "$TMP" | grep -q '{'; then
      install -m 600 "$TMP" "$AUTH"; rm -f "$TMP"
      echo "Installed your Codex credential to $AUTH"
      echo "Start Codex with:  codex"
    else
      rm -f "$TMP"; echo "Unexpected response from server (not JSON)." >&2; exit 1
    fi ;;
  403) rm -f "$TMP"; echo "Rejected: wrong passcode." >&2; exit 1 ;;
  409) rm -f "$TMP"; echo "No credentials left in the pool. Tell the instructor." >&2; exit 1 ;;
  000|"") rm -f "$TMP"; echo "Could not reach the server at $SERVER (network/firewall?)." >&2; exit 1 ;;
  *)   rm -f "$TMP"; echo "Server error (HTTP $code)." >&2; exit 1 ;;
esac
