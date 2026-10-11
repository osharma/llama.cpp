#!/usr/bin/env bash
# Start a test llama-server in the background on 127.0.0.1 and wait until
# it is ready. Never use port 8082 (production).
#
# Usage: bash lab/serve.sh <ref> <port> [extra llama-server args...]
#   e.g. bash lab/serve.sh upstream/master 8090 -cms 512
# Stop it with: kill $(cat ~/logs/serve-<port>.pid)
# Defaults match production: -t 3 -c 16384. MODEL overrides the model.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
REF=${1:?usage: bash lab/serve.sh <ref> <port> [args...]}
PORT=${2:?usage: bash lab/serve.sh <ref> <port> [args...]}
shift 2
[ "$PORT" != 8082 ] || { echo "8082 is production; pick another port"; exit 1; }
NAME=$(printf '%s' "$REF" | tr '/' '-')
SERVER="$ROOT/wt/$NAME/${BUILD:-build}/bin/llama-server"
MODEL=${MODEL:-$HOME/models/Qwen3.5-4B-Q4_K_M.gguf}
LOG="$HOME/logs/serve-$PORT.log"

nohup "$SERVER" -m "$MODEL" -t 3 -c 16384 --host 127.0.0.1 --port "$PORT" "$@" > "$LOG" 2>&1 &
echo $! > "$HOME/logs/serve-$PORT.pid"

# Wait for /health to answer (model load and repack take a few seconds).
for _ in $(seq 1 120); do
    if curl -sf "http://127.0.0.1:$PORT/health" > /dev/null; then
        echo "server ready: pid $(cat "$HOME/logs/serve-$PORT.pid"), port $PORT, args: $*"
        exit 0
    fi
    sleep 1
done
echo "server did not start; see $LOG"; tail -n 20 "$LOG"; exit 1
