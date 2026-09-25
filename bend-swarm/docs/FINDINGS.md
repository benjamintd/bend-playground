# Findings

## Geometry coverage, resolution and grid investigation (2026-09-25)

The shared mesh renderer now supports 512², 1024² and 2048² output. Four-sample
geometry AA resolves each sample's depth before averaging color, without a
larger framebuffer. A first intermediate-Image supersampling route measured
83.662 ms median on CPU and was rejected; direct coverage measured 28.494 ms
on CPU and 25.288 ms on Metal. Desktop load was substantial and the runs were
not interleaved. These measurements do not establish 60 FPS. Particle Life's
2048² pipeline measured 17.765 ms median on Metal before presentation.

Native CPU and Metal tests check all 4,194,304 Image pixels against the output
buffer, independent coverage/depth probes, exact four-to-one resolve and sprite
coverage across tile/torus seams. Q preserves the physical state while changing
render buffers and the macOS presentation surface dimensions. The host effect
only changes presentation metadata; rendering math remains Bend.

The reported grid-like particle grouping remains visually unexplained. Moving
a dense constellation across cell boundaries leaves the computed forces
unchanged within tolerance. After 600 native Metal steps with 8,192 particles,
482 next-step probes matched an independent all-pairs calculation with maximum
error 0.000129 (tolerance 0.0004). The full rendered Image also matches its pixel
buffer. These checks found no cell-boundary force or Image-assembly error; they
do not prove the observed visual artifact is resolved.

## Meadow, Particle Life and shared effects (2026-09-25)

These examples exercise reusable engine components: camera/rays, curves, wind,
native input/presentation, the spatial stencil, mesh finishing and periodic
sprites. No foreign simulation or rendering kernel was introduced. Meadow has
4,096 independent spring-driven blades; Life has 8,192 interacting particles
with six species and no neighborhood cap.

The initial golden-angle root placement multiplied a large floating angle
before adding jitter. After 240 steps the maximum CPU/Metal grass difference
was 0.001416, above the regression tolerance. Integer turn wrapping before F32
conversion reduced the measured difference to 0.000001621 without relaxing the
test. Both backends also pass the independent Life force, edge/focus-filter and
periodic sprite probes. The raster oracle checks every current color/depth
output and immutability of the static half at 1024².

The initial full-image spatial filter was material work: meadow CPU frame
medians were 13.499 ms raw and 19.163 ms with smoothing. Metal smoothing measured
20.282 ms. This scene does not support a 60-FPS claim with effects enabled, so
they start off. Life's analytic sprite edges measured 10.422 ms for the entire
Metal frame versus 11.484 ms on CPU. See PERF.md and raw records for p95 values
and measurement limits. A branch-heavy filtering experiment was slower in an
earlier exploratory run and was reverted; no universal compiler conclusion is
drawn from that desktop measurement.

The mesh finish pass retains resolved camera depth in a second persistent
Fragment region, avoiding a second scene evaluation. Postprocessing reads this
immutable region and builds Image output in its own tile tree. The initial effects were
deliberately small: spatial edge smoothing and depth-aware nine-tap defocus,
without temporal history, HDR or physically accurate bokeh. Particle glow is
analytic sprite falloff, not a bloom pipeline.

## 2026-09-25 — Phase 0

Installed 2.0.5 is too old for the requested APIs. Project-local upstream 2.0.27 works without altering the system installation or compiler. GPU smoke test passes on Metal; the application sandbox reports no GPU, so benchmarks explicitly request `--gpu on`.

The shader guide predates some array improvements. Current Base and `tests/run/stencil3d.bend` establish the newer shared-block approach: scalar indexed reads, exclusive output ranges, one fork tree, joins, double-buffer swap. A tree match on a shared array copies it; ordinary indexed reads do not.

Bend helpers must destructure computed tuple results as parameters. A helper declared before a recursive function cannot call its unfilled law in live safe code. Rendering tiles is statically unrolled at 1/2/4/8 pixels, avoiding that issue and avoiding per-pixel forks.

## First measured frame

131,072 independent moving points, 1024² image, 8² tiles, 128² bins, binary update depth 12, quadtree render depth 7. Update, histogram, scatter and tile rendering execute in Bend on Metal. Exclusive scan is currently a sequential native Bend loop. First 10 warmup / 20 measured frames are recorded in `results/baseline-gpu-131072.csv`: about 5.15 ms per headless frame. This is a short exploratory result, **not flocking**, and excludes Window.frame presentation and display sync. Longer measurements follow separately.

Native window visually verified; same implementation runs on CPU after G. Window title carries phase timings during this initial milestone. App.run frees the returned image in its own GPU launch, so the demo uses existing Window effects to preserve the old image and reclaim it inside the next tile tree.

## Open research

No claim yet that shared arrays beat cell-owned or halo layouts. No claim yet for safe-sort versus histogram/scatter, specialized versus template call overhead, or a million boids at 60 Hz. These require measured experiments, not inference from point throughput.

## Correctness gate

The all-pairs Bend reference matches an independent equation implementation on 24 deterministic dense/seam scenes. Spatial steps match all-pairs on 48 further scenes, with a safe Bend sort oracle for (cell,id) organization. Additional coincident-agent and partial-capacity tests ensure equal-position neighbors still align and inactive slots are excluded. Native CPU and Metal match the independent oracle with 0.0003 absolute tolerance on a dense 128-agent fixture. Pixel overlap uses max color so nondeterministic scatter order cannot flicker the result. Four structural laws pass with no unsafe dependencies.

## Fork geometry: measured, not inferred

The first depth sweep (30 warmups, 90 samples, same deterministic evolving scene) found median 131072-agent frame times of 73.07 / 33.57 / 20.11 ms at binary depths 10 / 12 / 14. At 65536 they were 32.53 / 19.86 / 14.50 ms. Rendering kept 7 quadtree levels. More simulation leaves substantially improve occupancy; histogram/scatter become slightly slower at greater depth. These measurements justify testing per-operation plans, not declaring one depth universally optimal.

The 120-warmup/600-sample depth-12 run reached 52.46 ms/frame GPU and 51.21 ms/frame CPU. The GPU neighbor stage was slower than CPU at that geometry; the GPU renderer was faster. These are separate evolving runs, not bit-identical state replay, so do not interpret small whole-frame differences as a stable backend ranking.

## Depth-14 confirmation

120 warmups / 600 samples: 131072 agents, 26.0355 ms median / 30.656 ms p95; 262144 agents, 41.8075 ms median / 49.837 ms p95. Simulation medians are 15.969 and 31.3545 ms; rendering stays around 2.8 ms. Depth 14 becomes the initial default. Two depth-10 262k warmups failed with a Metal internal error; short runs at that geometry work. Preserve the failure and investigate separately. No runtime edits were made.

## Native interaction check

The final native app was visually checked at 131072 and 262144 agents, with visible emergent flock shapes. G changed backend; bracket keys changed population; pause, HUD hide/show while paused, and a mouse drag all worked in a captured-log run. The title reports frame rate including HUD/presentation; the HUD separates compute stages. One computer-control call transiently reported `noWindowsAvailable`; repeating the controls with captured stderr did not reproduce a runtime error. Two test windows were found and closed afterward, so native UI FPS snapshots are deliberately not used as benchmark results.

## Boundary and shutdown investigation

The apparent confinement to tiles was checked with a new native regression,
`tests/crossings.bend`, using interacting pairs that start on either side of
8, 256, 512 and 1024 in both axes. For 120 steps on each native backend, the
positions and velocities agree with the independent all-pairs JS oracle
(0.012 absolute accumulated tolerance), CPU and Metal agree within 0.003, and
the expected particle colors appear in both the pixel buffer and the actual
Image tree. Each designated crossing is asserted after the first step. This
covers bin rebuilds, large quadtree boundaries, periodic wrapping and old-image
reuse; the fixture does not demonstrate stability at large dense populations.

A captured GUI run exited with status 0 and no runtime error. A separate LLDB
run reached the normal Window.close effect and exited with status 0; neither
run establishes a GPU crash. The earlier depth-10 Metal fault remains an
independent unresolved issue. Do not describe relaunching as a crash fix.

Live inspection of the original 131072-agent GPU scene at frame 1200 found
mean speed 1.1313, median speed 1.0470, and 47.03% of agents below 1 world unit/s.
Neighbor alignment damps the initially opposing headings toward rest; this
explains the nearly stationary groups without requiring tile walls. The demo
now applies a 20–60 world-unit/s cruising constraint after acceleration, with a
deterministic +X fallback for near-zero velocity. This deliberately changes the
dynamics. The old benchmark records remain historical, not current performance
claims. Native oracle and crossing regressions pass with the new constraint.
The normal-shutdown cause is still unconfirmed; the minimum-speed change is
not a crash-recovery mechanism.

A later optimized, archive-backed GUI launch **did** fail with exit 1 and
`Internal Error (0000000e:Internal Error)` after the window had reported 30 FPS.
The subsequent screenshot request observed the exited app; causality is not
established. See `results/interactive-metal-failure.json`. An O1 debug build
without a GPU archive then ran for several minutes, with moving flocks visible,
without reproducing the error. No runtime patch or crash fix has been applied;
optimized-vs-debug and archived-vs-live GPU compilation remain hypotheses.
The investigation was paused when work shifted to the generic API and cloth.

## Generic spatial API and first cloth example

The reusable API is now implemented in `engine/spatial.bend`: typed 2D/3D
layouts, source-owning snapshots, arbitrary-radius neighborhood folds and
separate output ownership. The swarm's live pipeline migrated to it; its old
specialized kernel remains as a reference. A sequential 131072-agent paired
run measured generic/specialized median full-frame costs of 33.114/38.605 ms,
with simulation medians 23.229/28.792 ms. This is one measured paired run, not a
claim that every generic callback is faster. Raw samples and executable hashes
are in `results/spatial-api-comparison.json`.

The 32×32 cloth uses three persistent SoA position buffers, two pinned opposite
corners, Verlet prediction, twelve Jacobi passes per substep, obstacle contact
and the same spatial API for vertex self-contact. Its filled 3D renderer uses
flat numeric triangle records, AABB bins and exclusive screen tiles. The
compiled C inspection found no boxed Triangle, Point, Controls or Correction
constructors in the hot program; scheduling and Image construction still have
runtime allocation costs. No compiler/runtime patch or foreign rendering kernel
was added.

At this small population, Metal's many short passes cost more than CPU execution.
Scheduling depths 6, 8 and 10 did not materially improve the GPU result; depth 10
is retained. The cloth example prioritizes readable, independently testable
passes. It is a compliant PBD sheet: twelve Jacobi iterations permit noticeable
local stretch near pins at 32×32, and vertex self-contact does not guarantee
triangle non-intersection. These are simulation limitations, not hidden
candidate caps. The larger swarm's previously captured interactive GPU fault
remains an independent unresolved runtime issue.

The full-resolution cloth contact fold amplifies small CPU/GPU floating-point
differences over time. Native tests therefore separate one-step agreement
(1e-5 m) from 180-step agreement (0.002 m for 8×8 and 0.02 m for 32×32), while
checking pins, finiteness and obstacle contact independently. The 32×32 strain
regression bound is 1.5× rest edge length; this example does not claim
inextensibility.

## Cloth contact, dragging and execution plans (2026-09-25)

Live LLDB inspection confirmed twelve separate constraint roots per substep at
1024 vertices. Combining them into one enclosing bang only reduced a short
Metal frame from roughly 52 ms to 50 ms; the internal fork continuations still
cost iterations. That experiment was discarded. Running the same solver with
one CPU region reduced its old particle-contact simulation from about 40 ms on
Metal to 2.86 ms on CPU. This is execution-plan overhead on a small mesh, not a
claim that the GPU cannot run large cloth workloads efficiently.

Vertex-only contact with a 35 mm radius left gaps between vertices spaced
116 mm apart. The replacement checks finite faces and edges and retains the
previous approach side. Flat, reusable surface samples keep the generic stencil
API and avoid per-vertex heap allocation. AABB rejection is necessary: the first
unpruned surface-contact version took about 48 ms even on CPU. CPU solver,
contact, projection and raster stages need different work sizes.

The drag test exposed a second cause of intersections: forcing the grabbed
vertex to its target during every constraint pass defeated collision response.
The accepted version uses a bounded spring during prediction and lets the
structural constraints move that vertex. Adding more repulsion passes or
extending face-plane corrections to crossing edges made the hard-grab case
worse; those experiments were discarded. The accepted version passed twenty
independently checked snapshots over a ten-second drape/drag/release sequence.
This does not establish continuous non-intersection between snapshots or for
arbitrary material stretch and extreme input.

Raster work was also undersubscribed on Metal. Changing 4096 8x8 work units to
16384 4x4 work units reduced drawing from 11.42 ms to 5.59 ms in a paired short
sweep, before smooth shading. CPU retains 8x8 work units and processes four
4x4 bins per unit. Flat-color coverage/checksum oracles still apply; a separate
fixture checks interpolated vertex lighting.


## Cloth quality regression and visual tessellation

The first high-quality attempt multiplied the physical grid from 32² to 64².
In the live app it fell to about 2–3 FPS; allowing eight catch-up substeps made
an expensive frame cause still more work. It was withdrawn. Q now changes only
visual tessellation and framebuffer size, with a two-substep catch-up ceiling.
The physics grid and all twelve constraint passes remain unchanged.

A bounded generic Catmull–Rom grid sampler derives 64² visual vertices from the
32² physical grid. It caches projected vertices once, then assembles triangles
into a disjoint portion of the same persistent buffer. The initial high-quality
CPU run (120 warmup, 600 samples) measured 16.188 ms median / 19.454 ms p95,
including 9.539 ms simulation and 6.624 ms rendering. This excludes the window
and HUD, so it does not establish sustained 60 FPS. See
`results/cloth-visual-high-cpu.json`. Moving pixel rejection before color/depth
work did not establish an improvement: 16.437 ms median / 20.703 ms p95 in the
follow-up run (`cloth-visual-cull-cpu`), with unrelated long outliers present.

Input had a separate event-ordering bug: a press followed by movement in the
same frame was picked at the final cursor position. The new regression sends
both events in one batch and confirms selection at the original press.


Stage timing located the remaining high-quality cost in rasterization
(6.239 ms median, compared with 0.448 ms projection and 0.336 ms binning).
A persistent color/depth backdrop reduced high-quality drawing to 5.219 ms
median and the headless frame to 15.081 ms. The full window/HUD/pacing run was
21.302 ms median / 42.715 ms p95. Desktop load was not quiescent: a later process
snapshot showed Linear at roughly 199% CPU plus a VM and browser renderer.
There was no concurrent demo, but these are not machine-isolated timings.

CPU physics plus Metal projection/binning/raster was also measured and rejected
as the default: 25.640 ms median full frame, including 15.523 ms rendering.
The benchmark can still select this plan with `-- hybrid`. Standard CPU quality
remains the interactive default. No sustained 60 FPS claim is made for high
quality. Raw baseline, cache, hybrid and window results remain under `results/`.
