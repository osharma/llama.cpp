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
  are meaningless.
- **Mac**: 2013 iMac, i5-4570 Haswell (4 cores, no HT, AVX2+FMA+F16C),
  16 GB DDR3-1600 dual channel, macOS 10.15.8, Apple clang 12.0.0.
  (This replaces the brief's "never connect to the Mac"; the user decided
  this on 2026-10-11.)
  - Access: `ssh -i ~/.ssh/mac_lab -o IdentitiesOnly=yes claude@10.0.2.2`.
    `claude` is a Standard (non-admin) user made for this project. No sudo.
  - Write only inside `/Users/claude`. Work happens in
    `/Users/claude/llama.cpp-dev` (a clone of the fork).
  - **Never do anything in another user's home folder**, not even reading.
    Everything we need is our own copy under `/Users/claude`: downloaded
    fresh, never copied from the user's files.
  - The user's production llama.cpp (b11497) serves llm-shed on port 8082.
    Never touch its process or that port. Bind test servers to 127.0.0.1 on
    other ports.
  - Benchmarks run on a shared machine: note in the results log whether
    llm-shed was serving and that the VM was running.
  - No tmux. For long jobs use `nohup ... > ~/logs/<name>.log 2>&1 &`.
  - CMake 3.31.9 (Kitware release tarball, SHA-256 checked):
    `~/tools/cmake-3.31.9-macos10.10-universal/CMake.app/Contents/bin`
    (not on PATH; build.sh adds it).
  - Model: `~/models/Qwen3.5-4B-Q4_K_M.gguf`, from unsloth/Qwen3.5-4B-GGUF
    at revision e87f176, SHA-256 00fe7986…ef11a4. It is not guaranteed to be
    byte-identical to the user's production copy. Hybrid: 8 of 32 layers
    have KV cache. Production: `llama-server -t 3 -c 16384`, thinking off.

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
- Write only inside `/Users/claude/llama.cpp-dev`. Reading the model is fine.
  No `rm -rf`, no sudo.
- Print a compact summary that goes into the results log.
- Small commits, each explained, so the user can follow every change.
