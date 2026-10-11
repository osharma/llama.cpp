#!/usr/bin/env bash
# Run llama-bench for one built version and print a summary for results.md.
#
# Usage: bash lab/bench.sh <ref> [extra llama-bench args...]
#   e.g. bash lab/bench.sh b11497
#        THREADS=3 bash lab/bench.sh upstream/master -fa on
#        BUILD=build-metal MODEL=~/models/Qwen3.5-0.8B-Q4_K_M.gguf \
#            bash lab/bench.sh upstream/master -ngl 0,99
#
# Runs prompt 512 and generation 128 tokens, 5 repetitions each
# (llama-bench reports mean ± stddev), for THREADS (default 3,4).
# BUILD picks the build folder (default build; build-metal from METAL=1),
# MODEL the model file (default the 4B). Extra args are appended.
# Don't pass -t/-p/-n/-r: llama-bench adds repeated values to the list
# instead of replacing them.
# Raw JSON lines go to ~/logs/bench-<name>-<time>.jsonl. Writes nothing else.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
REF=${1:?usage: bash lab/bench.sh <ref> [llama-bench args...]}
shift
NAME=$(printf '%s' "$REF" | tr '/' '-')
WT="$ROOT/wt/$NAME"
BENCH="$WT/${BUILD:-build}/bin/llama-bench"
MODEL=${MODEL:-$HOME/models/Qwen3.5-4B-Q4_K_M.gguf}
THREADS=${THREADS:-3,4}
RAW="$HOME/logs/bench-$NAME-$(date +%Y%m%d-%H%M%S).jsonl"

[ -x "$BENCH" ] || { echo "no $BENCH; run: bash lab/build.sh $REF"; exit 1; }
mkdir -p "$HOME/logs"

# Machine state, because the Mac is shared (llm-shed, the VM).
if nc -z 127.0.0.1 8082 2>/dev/null; then SHED=running; else SHED=stopped; fi
LOAD_BEFORE=$(sysctl -n vm.loadavg)

echo "== bench $REF =="
echo "date:     $(date '+%Y-%m-%d %H:%M')"
echo "commit:   $(git -C "$WT" describe --tags --always) $(git -C "$WT" log -1 --date=short --format='%h %cd')"
echo "build:    ${BUILD:-build}"
echo "model:    $(basename "$MODEL")"
echo "llm-shed: $SHED (port 8082)"
echo "load:     $LOAD_BEFORE before"
echo "args:     -p 512 -n 128 -t $THREADS -r 5 $*"

# Markdown table to stdout; JSON lines to the raw file.
"$BENCH" -m "$MODEL" -p 512 -n 128 -t "$THREADS" -r 5 "$@" -o md -oe jsonl 2> "$RAW"

echo "load:     $(sysctl -n vm.loadavg) after"
echo "raw:      $RAW"
