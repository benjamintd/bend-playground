# Environment — 2026-09-25

- Machine: MacBook Pro (Mac14,9), Apple M2 Pro, 10 CPU cores (6P + 4E), 16 GPU cores, 16 GB unified RAM.
- OS: macOS 15.7.4 (24G517), arm64.
- Bend: **2.0.27**, upstream commit **95317d952c8fe5be18ef49f916b2a57250cfb0aa**.
- Source: https://github.com/bendlang/bend/tree/95317d952c8fe5be18ef49f916b2a57250cfb0aa
- Exact revision in `.bend-version`; private project-local checkout under `.toolchain/bend`.
- `scripts/bend` invokes that source with Bun, disables telemetry, and stores Clang's module cache in `build/`.
- The global launcher remains unchanged (2.0.5). Its `bend version` and `bend guide shaders/effects` fail; its array API predates sharing.

Read before implementation: current guide/GUIDE.md, guide/SHADERS.md, guide/EFFECTS.md, bend2/base.bend, upstream AGENTS.md and CHANGELOG.md, app_pong_game_2d/main.bend, app_slash_boss_3d/main.bend and bend3d.bend; array_fork and stencil3d upstream tests.

## Verified execution

`repros/gpu_smoke.bend` compiled natively; `--gpu on` returned 134209536 (sum of 0..16383) on Metal. The sandbox hides the GPU; `--gpu on` correctly refuses execution there. Measurements require normal desktop execution / approved device access. Do not accept implicit CPU fallback as GPU evidence.

Native window verified through the desktop UI with 131,072 moving points. Pressing G switched the title from GPU / Metal to CPU while the scene remained live.

## Confirmed APIs

- Parallel let forks independent calls; `!` changes the root backend. JS is sequential.
- Array supports numeric in-place get/set; native arrays are contiguous blocks (8-byte Bend words). Tree pattern matching can materialize/copy blocks; hot loops use indexed access.
- `Array.fork/join` are unsafe O(1) alias operations. Disjoint writes need no atomics; overlapping counters do. Matching shared arrays copies their portion: do not do this in a hot loop.
- Atomics: add/min/max/and/or/xor/exch/cas on U32, fadd on F32. Each returns array and previous cell value.
- F32 has arithmetic, comparisons, floor, sqrt, conversions; computed values cannot be match scrutinees. Pass results to small helpers for destructuring.
- App.run exists; Window.open/frame/set_title/close support explicit frame timing and retaining the old Image for parallel reclamation.
- Image is Pix/Qua; Window.frame presents it and returns the image and events.
- Events include Key/Mouse/Move/Close; right mouse is button 1 on macOS.
- IO.now returns **milliseconds**, despite its Nat result. The sole custom effect reads the runtime monotonic clock in microseconds; no foreign simulation/rendering code.
- Insert an effect boundary between CPU parallel work and a GPU root (upstream shaders guide).
