# Bend Swarm

A GPU-native simulation engine experiment in **Bend 2.0.27**. Dense owned regions, a spatial stencil and tile rendering; the same flocking implementation runs on CPU or GPU.

**Working prototype, not completed v0.** The native demo has genuine separation/alignment/cohesion, a periodic spatial grid, double buffering, mouse attraction/repulsion, a backend switch and a Bend bitmap HUD. Phase 0 and the first measured 131k-point native pipeline are complete. A tested spatial boids implementation follows it. The remaining architecture experiments are listed below; there is no million-boids-at-60-Hz claim.

## Run

Prerequisites: Bun, Git, and Bend's native prerequisites (on this Mac: recent Apple Clang and Metal). The system Bend installation is left unchanged.

```
cd bend-swarm
scripts/setup
scripts/build
scripts/run
```

On macOS you can also open `build/Bend Swarm.app`. The launcher requires a real GPU; run the binary with `--gpu off` explicitly for a CPU-only session. G changes the root dispatch in the app; when the runtime was started with `--gpu off`, GPU-labeled roots still fall back to CPU, so use the normal launcher for backend demonstrations.

- **Mouse left/right:** attract/repel; release to restore ordinary flocking.
- **G:** CPU/GPU, **Space:** pause, **R:** deterministic reset, **H:** HUD.
- **[ / ]:** halve/double population, from 1024 to 1048576; starts at 131072.
- **Escape:** close.

The HUD reports computation milliseconds, excluding HUD and presentation. Population capacity support is not a real-time performance guarantee. Dense crowds make exact boids expensive; no neighbor caps hide that cost.

## Measured on this Mac

Apple M2 Pro (10 CPU / 16 GPU cores), 1024×1024, 120 warmup + 600 sampled frames:

| Genuine boids | Metal frame median | Frame p95 |
|---:|---:|---:|
| 131,072 | 26.04 ms | 30.66 ms |
| 262,144 | 41.81 ms | 49.84 ms |

These are complete **headless computation** timings, including grid construction, flocking/integration, screen binning and Bend tile rendering. They exclude HUD/display and are not window FPS. The initial plan uses binary depth 14; results change with density and scene evolution. See `docs/PERF.md` for stage timings, CPU results, failed configurations and raw records.

## Programming shape

```bend
# One implementation, chosen root:
case True{}: Boids.step!(depth, count, buffers)
case False{}: Boids.step(depth, count, buffers)
```

The prototype uses concrete SoA buffers and scalar parameters. Public high-order stencil ergonomics will follow measured primitives. There is no ECS, no foreign simulation kernel, and no foreign principal renderer. A tiny host-only effect supplies microsecond timing; Bend's existing Window effects handle presentation.

## Verify and measure

```
scripts/test
scripts/test --native
python3 scripts/bench.py --agents 131072 --backend gpu
python3 scripts/sweep.py --agents 65536 131072 262144 --depths 8 10 12 14
```

Tests include an independent numerical oracle, 48 clustered/periodic scenes, coincident and partial-active cases, grid membership/permutation/offsets, CPU/Metal agreement, deterministic pixel collisions, map/reduce/scan, and structural proofs. Unsafe-sharing invariants are tested contracts, not formal race-freedom guarantees.

Results and scope: [performance](docs/PERF.md), [environment](docs/ENVIRONMENT.md), [findings](docs/FINDINGS.md), [architecture](docs/ARCHITECTURE.md), [original brief](docs/BRIEF.md). Raw measurements are in `results/`.

## Next research gates

1. Compare shared arrays, owned-cell scheduling and local halos on complete frame cost.
2. Compare safe spatial organization against the atomic backend; add a reusable parallel scan if measurements justify it.
3. Sweep tile sizes/render fork geometry and retain a measured plan cache.
4. Broaden structural laws to indexing, scan and permutation; extend native fuzz coverage.
5. Measure presentation/HUD overhead and peak heap; cache HUD updates safely.
6. Record the shareable demo; add Particle Life only after Swarm is stable and benchmarked.

The current spatial grid and stencil are specialized to 2D periodic boids. They are not yet the final generic Spatial API. The fundamental unit remains an **owned parallel region**.
