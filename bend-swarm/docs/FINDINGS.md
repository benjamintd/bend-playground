# Findings

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
