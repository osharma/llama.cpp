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

---

## 2026-10-11: where the time goes (profile) and the memory-bandwidth ceiling

- Commit: master b11552 (23b0202a), CPU build. Model: Qwen3.5-4B Q4_K_M.
- Machine state: production llama-server running (idle), VM running.

### Weights by type (read from the GGUF header)

| Type | MiB | Share | Tensors |
|---|---:|---:|---|
| q4_K | 1298.0 | 49.9% | most matmuls (repacked q4_K_8x8 on x86) |
| q6_K |  802.9 | 30.8% | token_embd (497 MiB, also the tied output layer), attn_v, ffn_down |
| q5_K |  495.0 | 19.0% | attn_qkv, ssm_out |
| q8_0 / f32 | 7.7 | 0.3% | ssm_alpha, ssm_beta, norms |

### RAM read bandwidth (`lab/membw.c`, 1 GiB, best of 5, run twice)

| Threads | 1 | 2 | 3 | 4 |
|---|---:|---:|---:|---:|
| GB/s | 16.5 | 21.5 | 22.5 | 22.4 |

DDR3-1600 dual channel spec is 25.6 GB/s; ~22.3 GB/s is reachable.
Generation ceiling: 22.3 GB/s / 2.73 GB per token = **~8.2 tok/s**.
Measured tg128 at -t 3: 6.3 tok/s = 17.2 GB/s = 77% of the ceiling.

### Profile: generation (`bash lab/profile.sh upstream/master tg 20`, -t 3)

Self time, % of all samples on all threads:

| % | Function | Note |
|---:|---|---|
| 41.9 | ggml_gemv_q4_K_8x8_q8_K | q4_K weights, repacked |
| 24.1 | ggml_vec_dot_q6_K_q8_K | q6_K weights |
| 15.6 | ggml_vec_dot_q5_K_q8_K | q5_K weights |
| 9.5 | ggml_graph_compute_thread | threads waiting for each other (spin) |
| ~3 | memmove, get_rows, concat | copies of the recurrent state |
| 2.5 | gated_delta_net (incl. its copies) | Qwen3.5 linear-attention layers |

Matmul time per type matches the bytes per type (q4_K 51% of matmul time vs
50% of bytes, q6_K 30 vs 31, q5_K 19 vs 19): every kernel is memory bound.
Estimate: matmuls are ~82% of the time and move 17.2 GB/s overall, so
~21 GB/s while they run, near the 22.3 ceiling. The gap to 8.2 tok/s is
mostly the ~10% waiting and ~8% other ops between matmuls.

### Profile: prompt reading (`bash lab/profile.sh upstream/master pp 20`, -t 3)

| % | Function | Note |
|---:|---|---|
| 48.3 | ggml_gemm_q4_K_8x8_q8_K | q4_K, repacked |
| 20.7 | tiled_run_microtile<32,true,0,false> | q5_K, tiled path (`ggml-cpu/tiled/`) |
| 9.7 | tiled_run_microtile<16,false,32,true> | q6_K, tiled path |
| 5.7 | ggml_graph_compute_thread | waiting |
| ~6 | gated_delta_net, vec_dot_f32, concat, ssm_conv | delta-net layers |
| ~2.5 | tiled_unpack_src0/src1 | tiled path, unpacking |

Work per weight: q4_K 2.42 G weights in 48.3%; q5_K 0.76 G in 21.5%;
q6_K (without token_embd, used only for the last token) 0.39 G in 10.3%.
So the tiled q5_K/q6_K path is ~1.3-1.4x slower per weight than repacked q4_K.

---

## 2026-10-11: MUL_MAT speed per quant type (test-backend-ops perf)

- Commit: master b11552 (23b0202a), CPU build, `test-backend-ops` target.
- Run: `test-backend-ops perf -b CPU -o MUL_MAT -p "type_a=(q4_0|q8_0|q4_K|q5_K|q6_K),type_b=f32,m=4096,n=512,k=14336,"`,
  then the same with `GGML_CPU_TILED_MM=0`. One 4096x14336 weight matrix
  times a 512-token batch (prompt-reading shape), 60.13 GFLOP per run.
- test-backend-ops uses hardware_concurrency/2 = **2 threads** here, and
  plain CPU buffers (no repacking), so repacked q4_K is not in this table.
- Machine state: production llama-server running (idle), VM running.

| Type | Path (default) | GFLOPS | GFLOPS with TILED_MM=0 | tiled speed-up |
|---|---|---:|---:|---:|
| q4_0 | llamafile sgemm | 70.8 | 70.6 | - |
| q8_0 | llamafile sgemm | 87.8 | 86.3 | - |
| q4_K | tiled | 122.3 | 86.2 (vec_dot) | 1.42x |
| q5_K | tiled | 120.9 | 66.7 (vec_dot) | 1.81x |
| q6_K | tiled | 128.8 | 73.6 (vec_dot) | 1.75x |

Reading it:
- The tiled path runs q4_K, q5_K and q6_K at the same speed. q5_K/q6_K are
  not slow inside the tiled path.
- The gap in the model profile is tiled vs repacked: with `--repack 0`, q4_K
  falls back to the tiled path and pp512 drops 34.30 -> 28.26 (earlier
  entry). With q4_K at 48.3% of pp time, that makes repacked q4_K ~1.44x
  faster than tiled q4_K (estimate; profile at -t 3, bench at -t 4).
- So q5_K/q6_K at repacked-q4_K speed would cut their ~33% of pp time to
  ~23%: about +10-11% pp512 for this model (estimate).

---

## 2026-10-11: system-level levers: prompt cache, speculative decoding, small batches

- Commits: master b11552 (23b0202a) and b11497, CPU builds. Model: Qwen3.5-4B Q4_K_M.
- Test server: `bash lab/serve.sh <ref> 8090 [args]` (production flags -t 3 -c 16384,
  127.0.0.1), requests from `python3 lab/probe.py 8090 cache|gen wt/probe-doc.txt`.
  Document: first 7000 bytes of docs/build.md = 1966 tokens. Greedy, thinking off.
- Machine state: production llama-server running (idle), VM running.

### Prompt cache (probe.py cache): works, on master and on b11497 (same numbers)

| Request | Prompt tokens processed | Prompt time |
|---|---:|---:|
| 1 doc + Q1 (cold) | 1998 | 77.3 s |
| 2 identical | 4 | 0.4 s |
| 3 doc + new question | 23 | 1.8 s |
| 4 doc + Q1 + answer + follow-up | 70 | 4.5 s |
| 5 back to doc + Q1 | 22 | 1.7 s |

The model loads once at startup, and a shared prompt start is reused, also
for this hybrid model. Only the cold first request pays the full prompt.

### Speculative decoding (probe.py gen, 200 tokens max)

| Task | base tok/s | 0.8B draft tok/s (accepted) | ngram-mod tok/s (accepted) |
|---|---:|---:|---:|
| summary | 5.48 | 3.57 (96/183) | 5.54 (no drafts) |
| list | 5.45 | 3.68 (104/179) | 5.49 (no drafts) |
| quote (copy text) | 5.50 | 6.05 (61/63) | 6.78 (57/64) |

- The 0.8B draft is 33-35% slower on normal answers and only +10% even at
  97% acceptance. With the draft, the summary and list answers also differ
  from the base answers (batched math rounds differently); the quote matches.
- ngram-mod costs nothing when it has no match and gives +23% when the answer
  copies the prompt.

### Cost of small batches (llama-bench -p N -n 0 -r 3 -t 3)

| Tokens | 1 | 2 | 4 | 6 | 8 | 9 | 12 | 16 | 24 | 32 | 64 | 128 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| tok/s default | 6.14 | 8.32 | 15.78 | 15.03 | 14.03 | 14.37 | 17.76 | 22.01 | 21.31 | 24.94 | 26.53 | 27.08 |
| tok/s GGML_CPU_TILED_MM=0 | | | 15.28 | 14.97 | 17.79 | 17.51 | 18.65 | 20.49 | 20.68 | 21.13 | 21.53 | 21.70 |
| tok/s --repack 0 | | | 12.33 | 13.18 | 8.40 | 9.35 | 12.33 | | | | | |

- A batch of 4 costs 1.6x one token, a batch of 8 costs 3.5x: above ~4 tokens
  the CPU's arithmetic is the limit. That is why speculative decoding gains
  so little here.
- The tiled matmul (#27851, merged 2026-09-26, tuned on AVX512-VNNI) turns on
  at >= 8 rows (`ggml_tiled_min_batch`, tiled.cpp). On Haswell (AVX2, no VNNI)
  it is slower than the stock path up to 12 rows (-21% at 8, -18% at 9,
  -5% at 12) and faster from 16 rows. The PR text says break-even at 32 rows
  on the author's machine.
