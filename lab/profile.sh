#!/usr/bin/env bash
# Profile llama-bench with macOS `sample` and print where the CPU time goes.
#
# Usage: bash lab/profile.sh <ref> pp|tg [seconds]
#   pp = prompt reading (-p 512), tg = generation (-n 128)
#   e.g. bash lab/profile.sh upstream/master tg 20
#        THREADS=4 MODEL=~/models/Qwen3.5-0.8B-Q4_K_M.gguf bash lab/profile.sh upstream/master pp
#
# `sample` stops the process every 1 ms and records each thread's call
# stack. "Top of stack" counts say which function was running (self time).
# Full report: ~/logs/profile-<name>-<mode>-<time>.txt. Writes nothing else.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
REF=${1:?usage: bash lab/profile.sh <ref> pp|tg [seconds]}
MODE=${2:?usage: bash lab/profile.sh <ref> pp|tg [seconds]}
SECS=${3:-20}
NAME=$(printf '%s' "$REF" | tr '/' '-')
WT="$ROOT/wt/$NAME"
BENCH="$WT/${BUILD:-build}/bin/llama-bench"
MODEL=${MODEL:-$HOME/models/Qwen3.5-4B-Q4_K_M.gguf}
THREADS=${THREADS:-3}
OUT="$HOME/logs/profile-$NAME-$MODE-$(date +%Y%m%d-%H%M%S).txt"

case "$MODE" in
    pp) WORK=(-p 512 -n 0) ;;
    tg) WORK=(-p 0 -n 128) ;;
    *)  echo "mode must be pp or tg"; exit 1 ;;
esac
[ -x "$BENCH" ] || { echo "no $BENCH; run: bash lab/build.sh $REF"; exit 1; }
mkdir -p "$HOME/logs"

# Many repetitions so the benchmark outlives the sampling window.
"$BENCH" -m "$MODEL" "${WORK[@]}" -t "$THREADS" -r 100 > /dev/null 2>&1 &
PID=$!
sleep 15                                  # model load, repack and warm-up
sample "$PID" "$SECS" -file "$OUT" > /dev/null 2>&1
kill "$PID" 2>/dev/null || true
wait "$PID" 2>/dev/null || true

echo "== profile $REF $MODE =="
echo "date:     $(date '+%Y-%m-%d %H:%M')"
echo "commit:   $(git -C "$WT" describe --tags --always)"
echo "model:    $(basename "$MODEL"), -t $THREADS, ${WORK[*]}, ${SECS}s at 1 ms"
echo "load:     $(sysctl -n vm.loadavg)"
echo "report:   $OUT"

# Self time per function, as % of all samples on all threads.
awk '/^Sort by top of stack/ { on = 1; next }
     on && /^$/               { exit }
     on { n = $NF; $NF = ""; sub(/^ +/, ""); sub(/ +$/, "")
          name[++k] = $0; cnt[k] = n; total += n }
     END { for (i = 1; i <= k && i <= 25; i++)
               printf "%6.1f%%  %7d  %s\n", 100 * cnt[i] / total, cnt[i], name[i]
           printf "total samples: %d\n", total }' "$OUT"
