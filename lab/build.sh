#!/usr/bin/env bash
# Build llama-bench and llama-server for one git ref, in its own worktree.
#
# Usage: bash lab/build.sh <ref>     e.g. b11497, upstream/master, a branch
#        METAL=1 bash lab/build.sh upstream/master
#
# The ref is checked out (detached) in wt/<name>/ and built in
# wt/<name>/build/, so several versions can sit side by side and the lab
# checkout is never touched. METAL=1 builds with the GPU (Metal) backend
# into wt/<name>/build-metal/ instead, plus test-backend-ops. Writes only inside the repo (~/llama.cpp-dev
# of the Mac's claude user).
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)    # the repo, ~/llama.cpp-dev
export PATH="$HOME/tools/cmake-3.31.9-macos10.10-universal/CMake.app/Contents/bin:$PATH"

REF=${1:?usage: bash lab/build.sh <ref>}
NAME=$(printf '%s' "$REF" | tr '/' '-')   # upstream/master -> upstream-master
WT="$ROOT/wt/$NAME"
COMMIT=$(git -C "$ROOT" rev-parse --verify "$REF^{commit}")

# Same flags as the production build in ~/llama.cpp, unless METAL=1.
BUILD="$WT/build"
TARGETS=(llama-bench llama-server)
FLAGS=(-DCMAKE_BUILD_TYPE=Release -DGGML_METAL=OFF -DGGML_BLAS=OFF -DLLAMA_OPENSSL=OFF)
if [ "${METAL:-0}" = 1 ]; then
    BUILD="$WT/build-metal"
    TARGETS+=(test-backend-ops)          # compares GPU results with the CPU
    FLAGS=(-DCMAKE_BUILD_TYPE=Release -DGGML_METAL=ON -DGGML_BLAS=OFF -DLLAMA_OPENSSL=OFF)
fi

# Create the worktree, or move an existing one to the requested commit.
# Guard: if wt/<name> exists but isn't a worktree, git -C would walk up
# and switch the lab checkout instead, so stop.
if [ -d "$WT" ]; then
    if [ "$(git -C "$WT" rev-parse --show-toplevel)" != "$WT" ]; then
        echo "$WT exists but is not a git worktree; move it aside and rerun."
        exit 1
    fi
    git -C "$WT" checkout --quiet --detach "$COMMIT"
else
    git -C "$ROOT" worktree add --quiet --detach "$WT" "$COMMIT"
fi

# Configure and build. Output goes to log files; on failure show the end.
mkdir -p "$BUILD"
LOG="$BUILD/lab-build.log"
START=$(date +%s)
if ! { cmake -S "$WT" -B "$BUILD" "${FLAGS[@]}" &&
       cmake --build "$BUILD" --target "${TARGETS[@]}" -j 4; } > "$LOG" 2>&1; then
    tail -n 30 "$LOG"
    echo "BUILD FAILED for $REF (full log: $LOG)"
    exit 1
fi
SECS=$(( $(date +%s) - START ))

# Compact summary to paste back.
echo "== build $REF =="
echo "commit:   $(git -C "$WT" describe --tags --always) $(git -C "$WT" log -1 --date=short --format='%h %cd %s')"
echo "flags:    ${FLAGS[*]}"
echo "compiler: $(cc --version | head -n 1)"
echo "time:     ${SECS}s"
echo "bins:     $BUILD/bin"
