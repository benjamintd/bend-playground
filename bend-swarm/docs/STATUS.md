# Status against the brief

This is the measured foundation and first spatial swarm prototype, not the entire requested v0.

Completed:
- Phase 0 upstream reconnaissance, exact pin, GPU/native-window proof.
- Reusable balanced region/map/reduce primitives; safe scan and partition helpers.
- Seeded SoA state, active count/capacity separation, buffer reuse.
- All-pairs reference, independent numerical oracle, periodic spatial interactions.
- Atomic histogram/scan/scatter, safe-sort comparison oracle.
- Pure Bend tile renderer and native interactive swarm, CPU/GPU roots.
- GPU/CPU stage benchmarks, depth/population sweeps, raw samples/metadata.
- Long 131k and 262k runs, correctness tests and four structural proofs.
- Cruising-speed constraint, 120-frame native boundary/image regressions, and a 1920-frame 131k GPU soak.

Still open:
- Standalone parallel microbenchmark matrix for every primitive.
- Generic game-facing Spatial.stencil API; the current neighbor kernel is specialized.
- Cell-owned and halo architecture shootout, safe-sort performance comparison.
- Parallel scan performance experiment, tile-size/render-plan sweep and autotune cache.
- Neighbor throughput in HUD (available in benchmark JSON), separate integration timing.
- Measured peak heap / allocation cost, safe cached HUD refresh.
- Graceful runtime recovery from GPU faults at unvalidated large populations.
- Streak/triangle/density modes, species interactions, predator/obstacles.
- Stronger scan/permutation/index proofs; extended native random-seed testing.
- Demo recording, Particle Life, and any million-agent performance claim.

Known failure: depth 10 at 262144 agents failed twice during warmup with a Metal
internal error; depth 14 completes 720 frames. The current reproduction is still
application-sized. The root cause is not established and has not been reported
upstream. No Bend/compiler/runtime changes were made.
