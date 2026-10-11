# Results log

Newest entries at the bottom. Every entry records the date, commit, build flags,
run flags, the machine state (is llm-shed's server running?) and the numbers.
Only numbers from the Mac count; nothing is benchmarked in the VM.

Model unless noted: `~/models/Qwen3.5-4B-Q4_K_M.gguf`.
pp = prompt processing (reading), tg = token generation, in tok/s.

---

## Before the lab: llama-server baseline (measured by hand)

- Commit: b11497 (production build in ~/llama.cpp)
- Build: `-DCMAKE_BUILD_TYPE=Release -DGGML_METAL=OFF -DGGML_BLAS=OFF -DLLAMA_OPENSSL=OFF`
- Run: llama-server, thinking off, `-c 16384`
- Method: llama-server timings, not llama-bench, so it isn't directly
  comparable with the llama-bench entries that follow.

| Threads | pp, 27-token prompt | pp, 1,809-token prompt | tg |
|---|---:|---:|---:|
| -t 4 | 17 | 27.7 | 3.8–4.5 |
| -t 3 | 17 | 24.2 | 4.5–5.1 |

-t 3 won for generation because VirtualBox competes for the 4 cores.

---

## 2026-10-11: llama-bench baseline, b11497 vs master

- Commits: b11497 (ff30363a, 2026-10-08) and master b11552 (23b0202a, 2026-10-10),
  both built fresh by `lab/build.sh` in `/Users/claude/llama.cpp-dev/wt/`
- Build: `-DCMAKE_BUILD_TYPE=Release -DGGML_METAL=OFF -DGGML_BLAS=OFF -DLLAMA_OPENSSL=OFF`,
  Apple clang 12.0.0
- Run: `lab/bench.sh`, i.e. `llama-bench -p 512 -n 128 -t 3,4 -r 5`
- Machine state: production llama-server (port 8082) running but idle (0.0% CPU,
  434 MB resident, checked with `ps` mid-run); the VM was running.
  We decided not to do a "server stopped" run: the server will always be
  there in real use, and while idle it costs nothing measurable.
- Raw: `~/logs/bench-b11497-20261011-101103.jsonl`,
  `~/logs/bench-upstream-master-20261011-101821.jsonl` (on the Mac)

| Threads | Test | b11497 | master b11552 |
|---|---|---:|---:|
| 3 | pp512 | 27.01 ± 0.14 | 27.20 ± 0.08 |
| 3 | tg128 | 6.32 ± 0.05 | 6.07 ± 0.35 |
| 4 | pp512 | 33.32 ± 1.25 | 34.71 ± 0.15 |
| 4 | tg128 | 5.96 ± 0.29 | 6.21 ± 0.19 |

Reading it:
- pp scales with threads (+23–28% from 3 to 4): prompt reading is compute bound.
- tg barely moves with threads, and the 3-vs-4 order flips between builds,
  inside the noise: generation is memory-bandwidth bound.
- master vs b11497: no difference beyond the noise in this test.
