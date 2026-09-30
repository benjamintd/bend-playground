# Camera sampler closure regression (2026-09-28)

The rejected selector used a template function argument chosen by `Bool.pick`
between two curried lambdas. On pinned Bend 2.0.27 this did not become a direct
scalar shader call: generated `SAMPLE_MODE_0` selected a closure and then
allocated captures for its curried arguments for each covered sample.

`repros/camera-closure-selector.patch` restores that rejected selector against
the corrected mesh. The failed binary is retained locally as
`build/camera-profile-final` with its `.gpu` companion; generated C is
`build/camera-profile-debug.c`. Do not use that binary as the final profiler.

The real Meadow all-GPU workload failed twice before its first measured frame:

```sh
./build/camera-profile-final --gpu on --threads 10 -- meadow gpu raw standard 5 20
```

Metal reported `Internal Error (0000000e:Internal Error)`. This is an NSError
reported by the Metal runtime, not a pinned Bend runtime error code. The saved
pre-camera binary, the revised binary's CPU path and its CPU-geometry/binning
hybrid path completed the control workload. Smaller mesh/policy fixtures and
new camera images had passed, so they did not expose the workload-specific
failure. Raw failed/control output is in `results/camera-final-*error*`.

The source workaround uses an ordinary first-order Bool conditional, reached
with a constant camera mode from the template wrapper. In generated
`build/camera-profile-choice.c`, the legacy sampler passes a literal zero into
inline scalar shading; no sampler closure allocation remains. Total generated
function/closure segment counts return to the saved baseline (759 / 256), from
890 / 278 in the rejected variant. This proves removal of the extra allocation
and dispatch, not the internal cause of Apple's error. No compiler/runtime
source was changed. The native test script now exercises the actual Meadow
workload in addition to small image fixtures.

The corrected `build/camera-profile-choice` completed the same 5-warmup,
20-sample all-GPU command with exit code 0 and no stderr. Its raw output is
`results/camera-final-metal-corrected.csv`. This functional retry ran while
other shader builds were active, so its timings are not a performance result.
