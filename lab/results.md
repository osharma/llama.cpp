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

---

## 2026-10-11: can the GPU (GT 755M, 1 GB) run anything? No.

- Commit: master b11552 (23b0202a), `METAL=1 bash lab/build.sh upstream/master`
  (`-DGGML_METAL=ON`, build-metal/), built in 299s.
- `test-backend-ops support -b MTL0` (log: `~/logs/metal-support.log` on the Mac):
  - GPU family MTLGPUFamilyCommon2; simdgroup reduction = false,
    simdgroup matrix mul = false, bfloat = false, unified memory = false.
  - All 34 Metal shader libraries (mul_mv, mul_mm, norm, rope, softmax,
    gated_delta_net, ...) fail to compile in macOS 10.15's runtime Metal
    compiler. Top errors: `default initialization of an object of const
    type` (function constants), `invalid type 'const constant ggml_metal_kargs_* &'
    for buffer declaration`, `undeclared identifier 'simdgroup_half8x8'`.
  - Metal context init fails, so test-backend-ops aborts
    (`GGML_ASSERT(backend != NULL)`). Not one op runs on the GPU, so
    there is no GPU benchmark.

## 2026-10-11: Qwen3.5-0.8B on the CPU

- Commit: master b11552 (23b0202a), CPU build (same flags as the baseline)
- Model: `~/models/Qwen3.5-0.8B-Q4_K_M.gguf` (unsloth/Qwen3.5-0.8B-GGUF @ 6ab4614,
  SHA-256 bd258782…21dc517, 497 MiB)
- Run: `MODEL=... bash lab/bench.sh upstream/master` (`-p 512 -n 128 -t 3,4 -r 5`)
- Machine state: production llama-server running (idle), VM running; load
  2.98 before (the Metal build had just finished).

| Threads | Test | 0.8B | 4B (same commit, earlier today) | 0.8B / 4B |
|---|---|---:|---:|---:|
| 3 | pp512 | 153.06 ± 0.42 | 27.20 ± 0.08 | 5.6× |
| 3 | tg128 | 27.33 ± 0.76 | 6.07 ± 0.35 | 4.5× |
| 4 | pp512 | 178.56 ± 1.92 | 34.71 ± 0.15 | 5.1× |
| 4 | tg128 | 26.53 ± 0.43 | 6.21 ± 0.19 | 4.3× |

tg × model size: 27 tok/s × 0.5 GB ≈ 13.5 GB/s, close to the 4B's
6.2 × 2.5 GB ≈ 15.5 GB/s: both are limited by the same memory bandwidth.
Quality of the 0.8B on llm-shed's prompts is not tested yet.

---

## 2026-10-11: what does CPU repacking give on Haswell? (4B, -t 4)

- Commit: master b11552 (23b0202a), CPU build
- Run: `THREADS=4 bash lab/bench.sh upstream/master --repack 0,1`
- Machine state: production llama-server running (idle), VM running.
- Model tensor types: 131 q4_K, 48 q5_K, 48 q8_0, 22 q6_K, 177 f32.
  On x86 only q4_K is repacked (q4_K_8x8, AVX2): CPU_REPACK buffer is
  1298 MiB of the 2.54 GiB model. q5_K, q6_K and q8_0 have repack kernels
  for ARM only (`ggml/src/ggml-cpu/repack.cpp`, ggml_repack_get_optimal_repack_type).

| repack | pp512 | tg128 |
|---|---:|---:|
| 0 | 28.26 +- 0.14 | 5.99 +- 0.06 |
| 1 | 34.30 +- 0.52 | 6.13 +- 0.05 |

Repacking about half the weights: pp +21%, tg +2% (generation is memory
bound, so the layout barely matters). Open x86 Q6_K repack PR: #19706.
