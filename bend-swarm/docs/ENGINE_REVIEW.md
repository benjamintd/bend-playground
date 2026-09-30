# Engine simplification review — 2026-09-28

This pass focused on shared engine code. The baseline was the working engine
with execution policy and profiling already installed, using the project's
Bend 2.0.27 pin. Older uncommitted rendering work is not counted as part of this
review. Source hashes are in `results/engine-baseline-source.json` and
`results/engine-review-validation.json`.

## Changes retained

- **Image assembly:** one statically unrolled module constructs 2×2 through
  32×32 pixel blocks. Five renderers share it. Width and child operations are
  template arguments, retaining straight-line pixel work.
- **Tile ownership and scheduling:** one shared quadtree handles meshes,
  particles, sprites, postprocessing and resolve. Source Image children remain
  affine and separate from shared render state. CPU tile sizes and depths stay
  specific to each renderer. Unsafe sharing now lives in two definitions:
  the interval tree and the tile tree.
- **Spatial index:** histogram and scatter share a closed-operation interval
  traversal. Both still read each active position once and perform one atomic
  increment; scatter uses the returned cursor for a unique ID slot. Scan,
  stage ordering, empty/odd populations and the used `histogram_run` /
  `scatter_run` entry points remain.
- **Unused scaffolding:** removed the unused ExecutionPlan record/calculator,
  partition left/right helpers and Grid's unused CPU-only stage wrappers.
  Law-covered and reusable parallel primitives remain.

The two new shared modules earn their interfaces by replacing five sets of
ownership/scheduling or assembly logic. Their tests check actual pixels,
coordinate order, owned subtrees, duplicate/missing writes and unused buffer
capacity. They do not merely mirror helper calls.

## Validation

The proof and complete JavaScript suites pass after each structural change.
Native checks cover all 68 backend/effect/resolution policy cases, full Image
comparisons at 512², 1024² and 2048², wrapped sprites, repeated Image reuse,
120 particle frames crossing cells/quadrants/world seams, and generic spatial
membership against an independent all-pairs oracle. Cloth checks include one
step and 180 steps for both 8×8 and 32×32 grids, pinned vertices, contacts and
bounded stretch. Native blur output is checked against 1,021 independent
reference samples on each backend.

The final optimized source also passed the entire native policy matrix again.
`scripts/build` rebuilt Swarm, Cloth, Meadow and Particle Life and their app
bundles; each bundled executable and Metal library was verified against the
new build. Short CPU Cloth and Metal Meadow profiler runs completed afterward.

## Dispatch experiment rejected

The first shared tile module also centralized the CPU/GPU selector. CPU tests
passed, but the native Metal policy matrix first stalled and then reported
`a function the device does not hold`. The accepted version keeps the bang
at each renderer's entry point while sharing the traversal. The complete
native matrix passes with that shape. This is an observed workaround, not a
proved diagnosis of the compiler. The small patch and investigation notes are
in [the reproduction](../repros/tiles-indirect-dispatch.md).

## Measurements and reproduction

`scripts/bench-engine.py LABEL BINARY_DIRECTORY` runs sequential headless
comparisons and retains raw CSVs, binary hashes, settings, medians and p95s.
Use `--case NAME` repeatedly to select scenes, and `--warmup` / `--samples`
to control duration. The binary directory must contain the executables used
by the selected cases (`profile` and/or `points-frame`). Builds and other test
runs from this task were stopped during measurement; unrelated desktop work
was left running.

Initial image/tile measurements use 20 warmup + 60 samples. The tile control
uses 40 + 120; spatial comparisons use 40 + 180 in before/after/after/before
order. Initial timing swings did not survive controls: e.g. the shared tile
candidate's first Meadow/Metal/DoF run was 62.29 ms/frame, but the direct
control was 35.59 ms before versus 35.93 ms after. The control's particle
Metal times were 6.10 versus 6.14 ms/frame. These support retaining the
simplification, not an FPS improvement claim.

Spatial CPU pair medians were 42.63 → 47.16 and 52.76 → 46.47 ms/frame;
Metal pairs were 6.95 → 6.16 and 6.58 → 6.13 ms. Unchanged update and render
stages shifted along with index timings, so the apparent GPU gain is not
attributed to the traversal refactor. Source-level deduplication is the
established benefit. Raw records are `results/engine-{before,image,tiles}*`,
`engine-tiles-control-*` and `engine-spatial-{before,after}*`.

## Depth-of-field optimization retained

The blur kernel now derives a pixel's center coordinates before its 25-sample
loop. Coordinate division, remainder and conversion happen once per pixel
instead of once per tap. Samples, weights, tap order, border clamping and
per-sample depth rejection remain identical. This uses scalar parameters and
adds no heap allocation or shared configuration object.

The initial `engine-post-{before,after}*` captures compare the combined spatial
and coordinate changes. For isolation, a second baseline copied the same
final engine and demos with only `render/post.bend` restored to its pre-hoist
form. All other engine files were verified byte-identical. Two Metal Meadow
pairs used ten workers, 40 warmup + 240 measured frames, AA plus DoF at 1024²,
and before/after/after/before order:

| Pair | Post median before → after | Post p95 before → after | Frame median before → after |
| --- | ---: | ---: | ---: |
| 0 | 11.879 → 10.417 ms | 12.209 → 10.715 ms | 36.327 → 34.401 ms |
| 1 | 11.886 → 10.424 ms | 12.191 → 10.673 ms | 36.413 → 34.531 ms |

The median of run medians is **12.3% lower for postprocessing** and **5.2% lower
for the whole frame**. Simulation medians remained about 1.31 ms. This is a
measured improvement for this scene, machine and settings; it does not imply
60 FPS with effects or a universal gain. Cloth's Metal post stage was essentially
unchanged in the initial pairs. CPU measurements varied substantially with
other desktop work. Raw isolated data: `results/engine-post-isolated-*`.

## Size and scope

| Engine source measure | Before | After | Change |
| --- | ---: | ---: | ---: |
| Physical lines | 2,429 | 2,230 | −199 (8.2%) |
| Nonblank, non-comment lines | 2,044 | 1,888 | −156 (7.6%) |
| Unsafe definitions | 6 | 2 | −4 |
| Source files | 41 | 43 | +2 shared modules |

Counts include engine `.bend`, `.c` and `.js` files, not generated output.
Tests, benchmark tooling, reproductions and documentation were added outside
the engine; this is not a claim that total repository LOC fell by 199 lines.
The project keeps its verified Bend 2.0.27 Metal pin.

## API cleanup and TURN integration (2026-09-28)

The camera render target now owns its resolution: callers resize the target,
then draw without repeating the level. Runtime Metal availability is resolved
inside `Scene.draw`, so both dispatch and reported backend agree. Camera
preparation and pointer mapping share viewport validation; checked preparation
also rejects derived overflow, scale underflow and collapsed culling normals.
The unchecked helper is explicitly named `prepare_unchecked`.

The pure and profiled finish paths share effect selection. The existing IO
boundaries and static raster specialization remain intact.

Triangle storage moved from projection into `render/batch.bend`. Camera clipping,
TURN world geometry and generated outline text now share `create/clear/push`.
TURN's duplicate geometry record, font tuple, conversion wrappers and unchecked
append implementations were removed. The 32,768-triangle initial reserve is
preserved, and storage now grows safely beyond it. TURN's custom projection and
selective text coverage remain game code; see its `ENGINE_NOTES.md` for the
concrete interface and the reasons a broader scene-renderer abstraction was
not introduced.

| Implementation code lines (nonblank, non-comment) | Before | After |
| --- | ---: | ---: |
| Engine `.bend`, `.c`, `.js` | 2,424 | 2,435 |
| TURN `.bend` and font generator | 7,554 | 7,542 |
| Combined | 9,978 | 9,977 |

The reduction is modest: additional validation offsets most of the deleted
plumbing. Generated data is included consistently; tests and docs are excluded.
The useful simplification is one triangle ownership contract across geometry
and text, one resolution source per target, and shared effect dispatch.

Validation passed: engine proof and 25 JS suites, TURN proofs, 494 decorated
scenes, 390 camera poses, independent font coverage oracles, and a native
25-frame growth/reuse test comparing all 1,048,576 pixels with a fresh renderer.
All 12 CPU/Metal camera snapshots and four TURN snapshots are unchanged from
the saved baseline. Native scene tests cover size changes, clearing populated
frames and actual CPU fallback. Native finish checks cover 34 cases per backend.
Existing camera and TURN application bundles were rebuilt.

Sequential before/after runs used ABBA order with no concurrent builds/tests
from this task. Median-of-run values in milliseconds:

| Workload | Before | After |
| --- | ---: | ---: |
| TURN CPU, warmed rotation frames | 7.872 | 7.982 |
| Monochrome Metal, 1024² | 9.922 | 9.794 |
| Voxels Metal, 1024² | 10.093 | 10.181 |
| Meadow Metal with AA/DoF, 1024² | 34.668 | 34.699 |

These timings show broadly unchanged performance in the sampled workloads;
there is no claimed speedup. They exclude window presentation and pacing,
measure host elapsed time and do not control other desktop load. Raw captures,
source hashes and scope are in `results/api-cleanup-performance.json` and
`results/api-cleanup-validation.json`. Packaging remains deferred.
