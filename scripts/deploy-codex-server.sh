#!/usr/bin/env bash
# Deploy the Codex credential broker + credentials to an SSH host (instructor only).
#
#   scripts/deploy-codex-server.sh <ssh-host> <local-creds-dir> [remote-dir] [port]
#
# <local-creds-dir> holds your generated auth-01.json .. auth-NN.json, one per Codex
# device authorization. These are real credentials: they go only to your host, never
# into git (.gitignore blocks auth-*.json).
set -euo pipefail

HOST="${1:?ssh host alias, e.g. always-on}"
CREDS="${2:?local dir containing auth-01.json .. auth-NN.json}"
RDIR="${3:-sismid-codex}"
PORT="${4:-8080}"

here="$(cd "$(dirname "$0")/.." && pwd)"
n="$(ls "$CREDS"/auth-*.json 2>/dev/null | wc -l | tr -d ' ')"
[ "$n" -gt 0 ] || { echo "No auth-*.json found in $CREDS" >&2; exit 1; }
echo "Uploading broker + $n credentials to $HOST:$RDIR (port $PORT)..."

ssh "$HOST" "mkdir -p '$RDIR/creds' && chmod 700 '$RDIR' '$RDIR/creds'"
scp "$here/server/serve.py" "$here/server/start.sh" "$here/server/stop.sh" "$HOST:$RDIR/"
scp "$CREDS"/auth-*.json "$HOST:$RDIR/creds/"
ssh "$HOST" "chmod +x '$RDIR/start.sh' '$RDIR/stop.sh'; chmod 600 '$RDIR'/creds/*.json"

cat <<EOF

Uploaded. Finish on the host:

  ssh $HOST
  cd $RDIR
  printf %s 'YOUR-STRONG-PASSCODE' > passcode && chmod 600 passcode
  SISMID_PORT=$PORT ./start.sh

Open the firewall for port $PORT (GCP, run from your laptop):
  gcloud compute firewall-rules create sismid-codex \\
    --allow tcp:$PORT --source-ranges 0.0.0.0/0 \\
    --description 'SISMID Codex broker (delete after course)'

Verify from your laptop (replace with the host's PUBLIC IP):
  curl -s http://PUBLIC_IP:$PORT/healthz          # -> ok

Announce to students:
  URL       http://PUBLIC_IP:$PORT
  passcode  (say it aloud)
  command   bash scripts/codex-login.sh http://PUBLIC_IP:$PORT

Monitor and tear down:
  curl -s -H "X-Passcode: YOUR-STRONG-PASSCODE" http://PUBLIC_IP:$PORT/status
  ssh $HOST 'cd $RDIR && ./stop.sh'
  gcloud compute firewall-rules delete sismid-codex
EOF
