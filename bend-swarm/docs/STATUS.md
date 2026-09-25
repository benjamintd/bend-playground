# Status against the brief

This is the measured foundation, generic spatial API and four native examples. The full research brief still has open experiments.

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
- Generic typed 2D/3D Spatial API, variable-radius neighborhood folds, snapshot ownership and CPU/Metal fixtures.
- Swarm migrated to the generic stencil; specialized reference retained and benchmarked.
- 3D cloth with persistent buffers, pinned corners, Verlet prediction, stretch/shear/bending constraints, sphere/floor contact, vertex/face and edge/edge self-contact, wind and perspective dragging.
- Pure Bend filled-triangle renderer, tile ownership, perspective depth, native pixel oracle and exported preview.
- Smooth high-quality cloth tessellation separate from physical resolution, cached static depth/color, event-ordered picking and bounded catch-up.
- Wind-driven meadow using reusable curves, camera projection, wind and native presentation.
- Six-species Particle Life through the generic spatial stencil, with a reusable periodic additive sprite renderer.
- Shared retained depth, four-sample geometry anti-aliasing and optional depth-aware defocus for cloth and meadow; analytic particle edge coverage.
- 2048² mesh/sprite output, live resolution changes without resetting simulation, and a reusable four-to-one Image resolve.

Still open:

- Standalone parallel microbenchmark matrix for every primitive.
- Cell-owned and halo architecture shootout, safe-sort performance comparison.
- Parallel scan performance experiment, tile-size/render-plan sweep and autotune cache.
- Neighbor throughput in HUD (available in benchmark JSON), separate integration timing.
- Measured peak heap / allocation cost, safe cached HUD refresh.
- Graceful runtime recovery from GPU faults at unvalidated large populations.
- Swarm streak/density modes and predator/obstacle interactions.
- Stronger scan/permutation/index proofs; extended native random-seed testing.

Still open for visual investigation: the reported grid-like Particle Life grouping. Cell-translation force checks, a 600-step native all-pairs probe, and full-image assembly tests pass; they have not established the visual cause.

Further rendering work:

- Temporal anti-aliasing, HDR/linear-light rendering, richer lighting, demo recording, and any million-agent performance claim.

Known failure: depth 10 at 262144 agents failed twice during warmup with a Metal
internal error; depth 14 completes 720 frames. The current reproduction is still
application-sized. The root cause is not established and has not been reported
upstream. No Bend/compiler/runtime changes were made.

An optimized interactive 131k launch also produced the same Metal internal
error once after the cruising-speed change; see
`results/interactive-metal-failure.json`. A headless 1920-step soak and a later
O1 interactive debug run passed. The trigger remains unconfirmed.
