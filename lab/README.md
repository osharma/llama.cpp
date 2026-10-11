# lab

Tooling for making llama.cpp faster on a 2013 iMac (i5-4570 Haswell, 16 GB
DDR3-1600, macOS 10.15). The plan and the rules are in
[llama-cpp-start.md](llama-cpp-start.md).

This is the orphan `lab` branch. It shares no history with llama.cpp and
holds only this folder (plus CLAUDE.md and .gitignore). llama.cpp code is
never edited here.

## Layout

    ~/llama.cpp-dev/            clone of the fork, on `lab` (Mac: /Users/claude)
      lab/                      scripts, notes, results log (this folder)
      wt/<ref>/                 a git worktree per llama.cpp version we build
      wt/<ref>/build/bin/       its llama-bench and llama-server

`wt/` is ignored by git. To remove a worktree you don't need any more:
`git worktree remove wt/<ref>`.

## Files

| File | What |
|---|---|
| `build.sh` | Build llama-bench and llama-server for one git ref |
| `results.md` | Results log: date, commit, flags, numbers |
| `llama-cpp-start.md` | Copy of the project brief |

## Building a version

    bash lab/build.sh b11497            # a tag
    bash lab/build.sh upstream/master   # latest upstream (git fetch upstream first)
    bash lab/build.sh my-topic-branch   # one of our code branches

Every build uses the same flags as the production build in `~/llama.cpp`:
`-DCMAKE_BUILD_TYPE=Release -DGGML_METAL=OFF -DGGML_BLAS=OFF -DLLAMA_OPENSSL=OFF`.
