#!/usr/bin/env bash
# Build llama-bench and llama-server for one git ref, in its own worktree.
#
# Usage: bash lab/build.sh <ref>     e.g. b11497, upstream/master, a branch
#
# The ref is checked out (detached) in wt/<name>/ and built in
# wt/<name>/build/, so several versions can sit side by side and the lab
# checkout is never touched. Writes only inside ~/llama.cpp-dev.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)    # the repo, ~/llama.cpp-dev
export PATH="$HOME/tools/cmake-3.31.9-macos10.10-universal/CMake.app/Contents/bin:$PATH"

REF=${1:?usage: bash lab/build.sh <ref>}
NAME=$(printf '%s' "$REF" | tr '/' '-')   # upstream/master -> upstream-master
WT="$ROOT/wt/$NAME"
COMMIT=$(git -C "$ROOT" rev-parse --verify "$REF^{commit}")

# Same flags as the production build in ~/llama.cpp.
FLAGS=(-DCMAKE_BUILD_TYPE=Release -DGGML_METAL=OFF -DGGML_BLAS=OFF -DLLAMA_OPENSSL=OFF)

# Create the worktree, or move an existing one to the requested commit.
if [ -d "$WT" ]; then
    git -C "$WT" checkout --quiet --detach "$COMMIT"
else
    git -C "$ROOT" worktree add --quiet --detach "$WT" "$COMMIT"
fi

# Configure and build. Output goes to log files; on failure show the end.
mkdir -p "$WT/build"
LOG="$WT/build/lab-build.log"
START=$(date +%s)
if ! { cmake -S "$WT" -B "$WT/build" "${FLAGS[@]}" &&
       cmake --build "$WT/build" --target llama-bench llama-server -j 4; } > "$LOG" 2>&1; then
    tail -n 30 "$LOG"
    echo "BUILD FAILED for $REF (full log: $LOG)"
    exit 1
fi
SECS=$(( $(date +%s) - START ))

# Compact summary to paste back.
echo "== build $REF =="
echo "commit:   $(git -C "$WT" describe --tags --always) $(git -C "$WT" log -1 --format='%h %cs %s')"
echo "flags:    ${FLAGS[*]}"
echo "compiler: $(cc --version | head -n 1)"
echo "time:     ${SECS}s"
echo "bins:     $WT/build/bin"
