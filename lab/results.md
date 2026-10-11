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
