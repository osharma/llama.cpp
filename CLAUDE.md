# llama.cpp performance lab

A learning project: understand llama.cpp deeply, make a local model run
faster on an old Mac, and maybe contribute upstream. The full brief and plan
are in `lab/llama-cpp-start.md`. Read it at the start of a session.

## Role

Tutor and pair: explain, propose, measure. The user must be able to explain
every change in an interview.
- Don't write optimizations unless asked.
- Never call a change faster without benchmark numbers from the Mac.
- Follow the plan in order (setup, measure, settings, code walkthrough,
  profile, then code). Don't skip ahead.
- Before anything goes upstream, read llama.cpp's CONTRIBUTING.md with the user.

## Machines

- **VM (here)**: Debian 12 in VirtualBox, 2 vCPUs. Read, edit, commit, push.
  **Never benchmark llama.cpp here.** The VM hides FMA/F16C, so its numbers
  are meaningless. **Never connect to the Mac** (no SSH).
- **Mac**: 2013 iMac, i5-4570 Haswell (4 cores, no HT, AVX2+FMA+F16C),
  16 GB DDR3-1600 dual channel, macOS 10.15. The user runs everything there
  by hand and pastes back the output.
  - Work happens in `~/llama.cpp-dev` (the user pulls from the fork).
  - `~/llama.cpp` (b11497) serves llm-shed on port 8082. Don't touch it.
  - CMake 3.31.9: `~/tools/cmake-3.31.9-macos10.10-universal/CMake.app/Contents/bin`
    (not on PATH).
  - Model: `~/models/Qwen3.5-4B-Q4_K_M.gguf` (hybrid: 8 of 32 layers have
    KV cache). Production: `llama-server -t 3 -c 16384`, thinking off.

## Repository

- `origin` = github.com/osharma/llama.cpp (fork), `upstream` = ggml-org/llama.cpp.
- `lab`: an orphan branch with only `lab/`, `CLAUDE.md` and `.gitignore`.
  It holds tooling, notes and `lab/results.md` (date, commit, flags, numbers).
- Code changes: one topic branch per idea, from `upstream/master`, so a PR
  contains only the change. Never put lab files on a code branch.
- Here and on the Mac, the main checkout stays on `lab`. llama.cpp source
  lives in git worktrees under `wt/` (ignored). In the VM, read the source
  in `wt/master` (update it with
  `git fetch upstream && git -C wt/master checkout --detach upstream/master`);
  make topic-branch worktrees as `wt/<topic>`.

## Rules for scripts that run on the Mac

- Short, readable, commented POSIX sh or bash.
- Write only inside `~/llama.cpp-dev`. Reading `~/models` is fine.
  No `rm -rf`, no sudo.
- Print a compact summary the user can paste back.
- Small commits, each explained. The user reads every diff before running it.
