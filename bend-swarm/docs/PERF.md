# Performance methodology and log

Report milliseconds, raw samples and machine metadata. FPS is secondary. Never compare this project's point baseline with true-boid throughput.

## Reproduce

```
scripts/build
python3 scripts/bench.py --agents 131072 --backend gpu --warmup 120 --frames 600
python3 scripts/bench.py --agents 131072 --backend cpu --warmup 120 --frames 600
python3 scripts/sweep.py --agents 65536 131072 262144 --depths 8 10 12 14
```

GPU runs require a desktop/device-access environment; `--gpu on` must succeed. The Python wrapper only launches native Bend and computes statistics: it performs no simulation or rasterization. Every row measures one completed Bend pipeline. IO effect boundaries separate launches. Startup/Metal compilation/allocation happen before warmup. Samples report histogram, scan, scatter, neighbor update plus integration, screen binning, tile rendering and their complete headless total. CSV printing, HUD, presentation and display sync are excluded, explicitly. These are **headless computation times**, not window FPS. The native display includes extra overhead and sync.

Warmup evolves the actual scene. Flocks change density over time; a longer run may be slower than the short initial test. Candidate throughput is candidate visits (including the rejected self candidate), divided by neighbor-stage time. The counter is a 48-bit Nat so a dense million-agent scene cannot wrap a U32 count. No neighbor truncation or sampling is used.

Raw CSV and JSON metadata live under `results/`. JSON includes exact compiler commit, source and binary hashes, CPU/GPU/OS, count, resolution, parameters, fork geometry, warmup/samples, mean/median/p95/min/max. The enclosing Git commit may be absent before the first commit; source hashes remain available. Keep the Mac idle and run comparisons sequentially. Sweep runs are exploratory; retest a chosen plan interleaved with the baseline before claiming a stable improvement.

## 2026-09-25 — exploratory point baseline

Metal, 131072 independent points, 1024², update binary depth 12, rendering quadtree depth 7, 8² tiles. 10 warmup and 20 samples in `baseline-gpu-131072.csv`: approximately 5.15 ms computation. Native window and G switch verified. This preserved baseline is `demos/swarm/points.bend`; it is deliberately labeled points, not boids.

## 2026-09-25 — first true boids

Initial 10 warmup / 20 sample run in `boids-gpu-131072-initial.csv`: roughly 30 ms per computation frame, approximately 9.6 million candidate visits/frame. Neighbor work dominates. This early run preceded the coincident-agent edge-case correction and uses a U32 candidate counter; final runs use the corrected implementation. No throughput improvement is claimed from these code changes.

## Remaining measurements

The current harness sweeps simulation/grid binary fork depth. Rendering is fixed at 8² tiles / 7 quadtree levels. It does not yet constitute the requested tile-size sweep, safe-sort/atomic comparison or shared-array/cell-owned/halo shootout. The runtime's 2 GiB heap is known; measured peak allocation/bytes per active agent is still outstanding. Approximate payload memory is in ARCHITECTURE.md.

## Longer runs and selected initial plan

M2 Pro, 1024², 120 warmups then 600 frames. Separate runs, evolving scenes; times exclude HUD/display.

| Agents | Backend / depth | Simulation median | Render median | Frame median | Frame p95 |
|---:|---|---:|---:|---:|---:|
| 131,072 | cpu / 12 | 33.86 ms | 8.11 ms | 51.21 ms | 68.13 ms |
| 131,072 | gpu / 12 | 43.70 ms | 2.73 ms | 52.46 ms | 61.73 ms |
| 131,072 | gpu / 14 | 15.97 ms | 2.80 ms | 26.04 ms | 30.66 ms |
| 262,144 | gpu / 14 | 31.35 ms | 2.84 ms | 41.81 ms | 49.84 ms |

The initial app default is now binary depth **14**, based on these runs and the sweep, not a universal constant. 131k depth 14 measured 26.04 ms versus 52.46 ms at depth 12 in separate long runs. This is an observed configuration comparison, not an interleaved/replayed-state speedup guarantee. At 262k, depth 14 completes the long run; depth 10 twice failed during warmup with a Metal `Internal Error (0000000e:Internal Error)`. A 2-warmup/3-sample depth-10 run succeeded at ~220 ms/frame. Root cause is not established. See the preserved failure JSON and reproduction script.

### Exploratory depth sweep

30 warmup / 90 measured frames per row.

| Agents | Depth | Simulation median | Frame median |
|---:|---:|---:|---:|
| 65,536 | 10 | 24.51 ms | 32.53 ms |
| 65,536 | 12 | 10.37 ms | 19.86 ms |
| 65,536 | 14 | 4.93 ms | 14.50 ms |
| 131,072 | 10 | 63.34 ms | 73.07 ms |
| 131,072 | 12 | 23.99 ms | 33.57 ms |
| 131,072 | 14 | 10.01 ms | 20.11 ms |
| 262,144 | 12 | 82.77 ms | 92.15 ms |
| 262,144 | 14 | 28.03 ms | 38.58 ms |

## Cruising-speed correction

The previous tables describe the original dynamics, whose headings decayed
toward rest. The current demo clamps speed to 20–60 world units/s. This changes
the evolving scene and its candidate workload; the following numbers are not
an isolated speedup/regression comparison of the same state. Both runs used
120 warmups and 600 samples, binary depth 14, with no concurrent demo process.

| Agents | Simulation median | Render median | Frame median | Frame p95 |
|---:|---:|---:|---:|---:|
| 131,072 | 27.05 ms | 2.76 ms | 36.32 ms | 40.87 ms |
| 262,144 | 88.88 ms | 2.93 ms | 98.67 ms | 115.63 ms |

Raw records: `results/cruise-gpu-131072-d14.{csv,json}` and
`results/cruise-gpu-262144-d14.{csv,json}`. Both completed without a GPU error.
The larger moving swarm is substantially more expensive than the old settled
scene. No real-time claim is made for 262k, and timing still excludes HUD/display.

The longer default-population soak (`cruise-long-gpu-131072-d14`) also completed:
120 warmups + 1800 measured frames, no GPU error, 42.27 ms frame median and
47.82 ms p95. The increased time again reflects the evolving dense flock.
This is 1920 successful steps, not a guarantee against every input/population
or the historical depth-10 failure.

## Generic Spatial API and cloth (2026-09-25)

All new numbers below are headless pipeline measurements on the same Apple M2
Pro, ten CPU workers. They exclude the HUD, window, display synchronization and
startup GPU compilation. The scene evolves at fixed simulation steps.

| 131072 boids, depth 14, 120 warmup + 600 samples | Simulation median | Full frame median |
|---|---:|---:|
| Preserved specialized executable | 28.792 ms | 38.605 ms |
| Generic API and index adapter | 23.229 ms | 33.114 ms |

The executables ran sequentially in isolation. Candidate order is unspecified,
so trajectories are numerically close initially but can diverge over time.
These are measured results for this paired workload, not a general guarantee.
The original stopping-flock/cruising-flock data above are preserved.
`results/spatial-api-comparison.json` records hashes and raw CSV names.

Cloth uses 1024 vertices, 1922 triangles, two 1/120-second substeps, twelve
constraint passes per substep, a 32³ spatial grid, and a 512² framebuffer.
The CPU path is faster at this scale. Final 120-warmup/600-sample measurements
and their full metadata are in `results/cloth-final-{cpu,gpu}.json`.

| Final cloth | Simulation median | Render median | Full frame median | Frame p95 |
|---|---:|---:|---:|---:|
| Metal | 40.21 ms | 11.82 ms | 52.07 ms | 53.97 ms |
| CPU | 25.70 ms | 3.97 ms | 29.66 ms | 30.23 ms |

The shorter scheduling-depth comparison (60 warmup + 180 samples) found
GPU frame medians of 53.109 ms at depth 6, 53.742 ms at depth 8, and 53.088 ms at
depth 10. The depth changes did not address the main cost of many short passes;
the demo retains depth 10. Development runs and the earlier hanging-sheet
scene remain recorded in `results/cloth-development.json`. The rendered preview
is exported from the native Bend framebuffer, not a mockup.


## Cloth contact and quality correction (2026-09-25)

These replace the older cloth timings above. The solver now checks finite
vertex/face and edge/edge contact, uses a compliant grab, and has CPU execution
plans suited to a 1024-point sheet. Twelve constraint passes and two 1/120 s
substeps remain. Standard is the interactive default. High quality derives
4096 visual vertices from the same 1024 simulated points; it does not simulate
a 64×64 cloth. The static depth/color backdrop is cached in Bend.

| CPU quality, 120 warmup + 600 samples | Simulation median | Draw median | Frame median | Frame p95 |
|---|---:|---:|---:|---:|
| Standard, 512² / 1,922 triangles | 9.349 ms | 3.356 ms | 12.724 ms | 14.262 ms |
| High, 1024² / 7,938 triangles | 9.861 ms | 5.219 ms | 15.081 ms | 18.672 ms |
| High with window/HUD/pacing | 11.577 ms | 6.961 ms | 21.302 ms | 42.715 ms |

Sources: `cloth-responsive-cpu`, `cloth-visual-cache-cpu`, and
`cloth-visual-window` in `results/`, each with raw CSV. The first two rows exclude
HUD/display. Background desktop applications were active (a later snapshot
showed Linear near two CPU cores), so this is not a quiescent-machine guarantee.
The high-quality display test does not sustain 60 FPS. A CPU-physics/Metal-render
headless comparison measured 25.640 ms median and was rejected as the default.
The interactive clock limits catch-up to two steps and drops excess wall time
after stalls; headless tests always simulate both steps.

## Initial spatial filter, meadow and Particle Life (2026-09-25)

These earlier scene runs used 120 warmup frames and 600 samples, 1024², ten CPU workers,
on the M2 Pro. Runs were sequential with no concurrent demo, tests or builds;
ordinary desktop apps remained active. These are complete headless pipelines,
including image reclamation and the selected effects, excluding window/HUD and
presentation. No sustained window-FPS claim follows from them.

| Scene / backend / effects | Simulation median | Draw median | Frame median | Frame p95 |
|---|---:|---:|---:|---:|
| 4,096 grass blades / CPU / off | 0.258 ms | 13.215 ms | 13.499 ms | 24.714 ms |
| Meadow / CPU / edge smoothing | 0.250 ms | 18.918 ms | 19.163 ms | 29.607 ms |
| Meadow / CPU / smoothing + focus | 0.247 ms | 17.565 ms | 17.810 ms | 23.592 ms |
| Meadow / Metal / edge smoothing | 0.935 ms | 19.319 ms | 20.282 ms | 21.992 ms |
| 8,192 Particle Life / CPU / smooth sprites | 2.088 ms | 9.433 ms | 11.484 ms | 13.831 ms |
| Particle Life / Metal / smooth sprites | 4.128 ms | 6.272 ms | 10.422 ms | 11.747 ms |

Records: `meadow-final-{cpu-raw,cpu-aa,cpu-dof,gpu-aa}` and
`life-final-{cpu-aa,gpu-aa}` in `results/`, with raw CSV, machine settings,
source/binary hashes and commands. Life uses preset 2 (chasers), seed 42; the
scene evolves during the run. Meadow uses the breeze preset without pointer
force. GPU numerical reduction order can change Life trajectories over time.

At this stage meadow started on CPU with effects **off** because the filtered 1024² pipeline
already exceeds the 16.67 ms budget before presentation. A/D enable the effects
explicitly. Life starts on Metal with analytic sprite coverage enabled. These
are choices for this machine and scene, not general backend rankings. The focus
pass replaces edge filtering at blurred pixels; it is not an extra serial blur
after AA. Its lower median here is not proof that enabling focus saves time,
given desktop variability and different work per pixel.

Retaining current depth/color for effects also changes the raw cloth renderer.
With both effects disabled, standard cloth measured **14.717 ms median / 18.892
ms p95** (simulation 11.319, draw 3.391); high measured **16.509 / 20.125 ms**
(simulation 10.920, draw 5.539). See `cloth-depth-{cpu,high-cpu}`. The physics
algorithm is unchanged from the previous section. These are separate runs
under desktop load, so the higher simulation timings do not establish an
effect-induced physics regression. High quality still does not guarantee 60 FPS.

Earlier 120-sample meadow runs are preserved in `meadow-exploratory.json` and
their CSV files. They used a different scene layout; one Metal run overlapped
builds/tests, and an attempted branch-based filter change was reverted. They
are not used for the final defaults or a claimed speedup.


## Four-sample geometry coverage and 2048² (2026-09-25)

A now selects four independently depth-tested samples per pixel for cloth and
meadow. Q switches meadow and Particle Life from 1024² to 2048² while retaining
the simulation state. Life retains analytic sprite-edge coverage. The previous
spatial-filter table describes an earlier implementation, not the current A key.

These runs use 120 warmups and 600 samples, ten CPU workers, and include the
complete headless pipeline with image reclamation. They exclude window/HUD and
presentation. Other Bend Turn demos and substantial unrelated background jobs
were active; these are **loaded-desktop measurements**, not idle-machine results.
This task ran no tests or builds concurrently. Small differences across runs
should not be interpreted as stable backend rankings.

| Scene / output / backend / effects | Frame median | Frame p95 |
|---|---:|---:|
| Meadow / 1024² / CPU / off | 15.856 ms | 30.392 ms |
| Meadow / 1024² / CPU / four-sample AA | 28.494 ms | 65.020 ms |
| Meadow / 1024² / Metal / four-sample AA | 25.288 ms | 29.270 ms |
| Meadow / 2048² / CPU / off | 39.143 ms | 61.216 ms |
| Meadow / 2048² / Metal / off | 46.448 ms | 58.435 ms |
| Particle Life / 1024² / Metal / analytic edges | 10.794 ms | 12.029 ms |
| Particle Life / 2048² / Metal / analytic edges | 17.765 ms | 22.945 ms |

Records: `meadow-quality-{cpu-raw,cpu-2048,gpu-2048}`,
`meadow-coverage-{cpu-aa,gpu-aa}`, and `life-quality-gpu-{1024,2048}`.
Each has raw CSV plus command, source/binary hash and machine metadata. The
small final cleanup removes an always-disabled resolve wrapper; these recorded
hashes identify the measured executable before that nonfunctional cleanup.

An initial supersampling route built a complete 2048² intermediate Image before
resolving to 1024². It measured 83.662 ms median / 190.304 ms p95 on CPU
(`meadow-quality-cpu-ssaa`) and was rejected for interactive AA. Direct coverage
uses the selected output-size buffers and resolves four samples locally. The
independent four-to-one Image resolver remains available for exports.

Neither meadow AA nor 2048² quality establishes sustained 60 FPS. Meadow retains
1024² with effects off by default; Life retains 1024² with analytic edges on.
