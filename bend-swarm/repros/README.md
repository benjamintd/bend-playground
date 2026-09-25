# Reproductions

`gpu_smoke.bend` is the Phase 0 compiler/device check. Build with the pinned
launcher, then explicitly require the backend:

```
scripts/bend repros/gpu_smoke.bend -o build/gpu-smoke
build/gpu-smoke --gpu on
```

Expected: `134209536`. A sandbox without Metal visibility must fail with
`--gpu on, but this binary found no GPU device`; do not count its implicit CPU
fallback as a GPU test. No compiler or runtime modifications are needed.

`metal_long_leaf.sh` reproduces the observed depth-10 / 262144-agent failure
without a window. Two 30-warmup/90-sample attempts returned Metal
`Internal Error (0000000e:Internal Error)` before the CSV header; 2 warmups and
3 samples succeeded. Depth 14 completed 120 warmups + 600 samples. The precise
cause and reduction to a tiny kernel remain open; this is not evidence of a
proven compiler bug. The engine-level workaround is the measured depth-14 plan.
The raw failure is in `results/failure-boids-gpu-262144-d10.json`.
