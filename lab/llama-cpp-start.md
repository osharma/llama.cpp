I'm starting a learning project: a deep dive into llama.cpp, to make a local
model run faster on old hardware and, if it works out, contribute changes
upstream. I want to understand every change myself; I'll be asked to explain
it in interviews. So act as a tutor and pair: explain, propose, measure. Don't
write optimizations for me unless I ask, and never call a change faster
without benchmark numbers.

## How we work (important)

- You run in a Debian 12 VirtualBox VM. You must NEVER connect to the Mac
  (no SSH). The Mac is my main machine, and I run everything on it by hand.
- My fork: github.com/osharma/llama.cpp (forked from ggml-org/llama.cpp).
  Clone it into this project directory, push to it from the VM, and I
  git pull on the Mac in ~/llama.cpp-dev.
- Branches:
  - `lab`: our tooling only, in a top-level lab/ folder (scripts, notes,
    results log). Never put lab/ files on code branches.
  - Code changes: one topic branch per idea, made from upstream master,
    so a pull request contains only the change.
- Scripts that run on the Mac must be short and readable (POSIX sh or bash,
  commented). They may only write inside ~/llama.cpp-dev. No rm -rf, no sudo,
  nothing outside that folder except reading ~/models. I read every diff
  before running it, so keep commits small and explain each one.
- Scripts should print a compact summary I can paste back to you.
- llama.cpp must NOT be benchmarked in the VM: it hides FMA and F16C, so
  numbers there are meaningless. In the VM you only read, edit and commit.

## Hardware and setup

- Mac: 2013 iMac, Intel Core i5-4570 (Haswell, 4 cores, no hyper-threading,
  AVX2 + FMA + F16C), 16 GB DDR3-1600 dual channel, macOS Catalina 10.15
  (can't be upgraded). Prebuilt llama.cpp binaries need macOS 13.3+, so I
  build from source.
- VM: 2 vCPUs, 6 GB RAM, running on that Mac.
- On the Mac:
  - CMake 3.31.9 is at ~/tools/cmake-3.31.9-macos10.10-universal/CMake.app/Contents/bin
    and isn't on PATH by default.
  - A working llama.cpp (tag b11497) is in ~/llama.cpp. It was built with
    -DCMAKE_BUILD_TYPE=Release -DGGML_METAL=OFF -DGGML_BLAS=OFF -DLLAMA_OPENSSL=OFF.
  - It serves my other project (llm-shed) on port 8082. Leave ~/llama.cpp
    alone; this project uses ~/llama.cpp-dev.
- Model: ~/models/Qwen3.5-4B-Q4_K_M.gguf (2.7 GB, Unsloth GGUF). Qwen3.5 is
  a hybrid model: only 8 of 32 layers keep a KV cache. Thinking mode is off
  in production (--chat-template-kwargs '{"enable_thinking":false}').
- Production server: llama-server -t 3 -c 16384, port 8082.

## Baseline measured so far (llama-server, b11497, thinking off)

| | Prompt reading | Generation |
|---|---:|---:|
| -t 4 | 17 tok/s (27-token prompt), 27.7 tok/s (1,809-token prompt) | 3.8–4.5 tok/s |
| -t 3 | 17 tok/s (27-token prompt), 24.2 tok/s (1,809-token prompt) | 4.5–5.1 tok/s |

-t 3 won for generation because VirtualBox competes for the 4 cores.

## The plan (in order; don't skip ahead)

1. Setup: clone the fork here and add the upstream remote. Create the lab
   branch with a README and a build script. Give me the one-time commands for
   the Mac (clone the fork into ~/llama.cpp-dev, check out lab, build
   llama-bench and llama-server). Write a CLAUDE.md that records this setup
   and how we work, and copy this file's content into lab/ so it lives in
   the repo.
2. Measure: a reproducible llama-bench baseline (prompt and generation speed,
   several runs, fixed threads, with llm-shed's server stopped and running),
   for b11497 and for the latest master. Estimate the hardware ceilings
   (memory bandwidth for generation, compute for prompt reading) and how close
   we are.
3. Settings before code: test one at a time, with numbers:
   - GGML_BLAS=ON (Accelerate)
   - -fa (flash attention)
   - -b / -ub (batch sizes)
   - KV cache types
   - other quantizations (e.g. Q4_0 and its repacked CPU paths)
4. Learn the code: walk me through one token from llama-server through
   libllama to the ggml CPU backend, down to the Q4_K AVX2 dot product, and
   the code for Qwen3.5's non-attention (hybrid) layers.
5. Profile, then choose an optimization target with me. Only then change code.

Keep a results log (date, commit, flags, numbers) in lab/. I'll paste you the
outputs. Before anything goes upstream, read llama.cpp's CONTRIBUTING.md
with me.

Start with step 1.
