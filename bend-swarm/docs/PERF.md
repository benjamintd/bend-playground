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


## Four-pixel mesh candidate reuse (2026-09-28)

The regular mesh rasterizer now loads each tile candidate once per 2×2 pixel
block. Each of the four pixels still resolves its own background, depth,
lighting and ties. Triangle/index reads are divided by four; sample count,
geometry, simulation and image quality are unchanged. This applies to the
regular raster path and the raster stage before depth of field. Four-sample AA
uses a separate path and has no claimed speedup here.

Apple M2 Pro, ten CPU workers, 120 warmups and 600 measured frames **per run**.
Each row summarizes three pairs, alternating AB/BA/AB; numbers are medians of
the three run medians. Meadow also has an A/A baseline control. All effects
were off. Every run restarts the same scene; meadow uses preset 1 and seed 42.
These are complete headless frames, including old Image reclamation, excluding
window/HUD/display and startup.

| Workload | Draw median, before → after (ms) | Frame median, before → after (ms) |
|---|---:|---:|
| Meadow 1024² / CPU | 18.922 → 17.180 | 19.496 → 17.791 |
| Meadow 1024² / Metal | 16.483 → 11.232 | 17.583 → 12.241 |
| High cloth 1024² / CPU | 8.495 → 6.016 | 24.463 → 17.562 |

The Metal meadow frame improved in all three pairs: **18.444 → 12.670**,
**17.583 → 12.241**, and **15.642 → 12.111 ms**, reductions of 31.3%, 30.4%
and 22.6%. The median-of-run-medians reduction is **30.4%** for the full frame
and **31.9%** for drawing in this measured workload. This does not establish
a sustained window frame rate or the same gain on other hardware/scenes.

**CPU results are noisy observations, not stable speedup claims.** The meadow
CPU pairs changed by +27.6%, +15.1%, and −10.1% (positive means faster), while
the A/A baseline moved from 12.566 to 15.064 ms. Cloth drawing improved in each
pair, but unmodified physics varied markedly: its median across baseline runs
was 15.897 ms versus 11.389 ms across updated runs. The apparent cloth total
gain therefore cannot be attributed entirely to rendering. During these runs,
a separate Bend Turn snapshot job and macOS services consumed CPU. No builds
or tests from this task ran concurrently with timed samples.

Raw samples, per-run p95, machine details, source/binary hashes, timestamps and
commands are in `results/blocks-final-{meadow-cpu,meadow-gpu,cloth-cpu}.json`
and their named CSVs. Short exploratory comparisons are preserved as
`blocks-exploratory-{cpu,gpu}`. Rejected alternatives are documented in
FINDINGS.md; their measurements are not used as the baseline for this claim.

### Reproduce the paired comparison

Keep binaries built before and after the edit. The recorded baseline is the
renderer from `f819d30`; its complete workspace source hash is below. Use the
corresponding source hash if capturing another baseline.

```sh
# Compile these on the before and after source versions, respectively:
scripts/bend benches/meadow.bend -o build/meadow-before
scripts/bend benches/meadow.bend -o build/meadow-frame
python3 scripts/compare-showcase.py \
  --before build/meadow-before --after build/meadow-frame \
  --before-source-sha256 784c8a7f35219db349bfe4b0571ee2e747de2df4f838f928cd627f9812cf8544 \
  --demo meadow --backend gpu --effects raw --pairs 3 --control \
  --tag meadow-paired-local
```

The helper also supports CPU, high resolution and the cloth benchmark. For
cloth use `--demo cloth --effects raw`; `--quality high` selects the 1024²
visual mesh with the same 1024-point physics. It launches runs sequentially
and saves each CSV and metadata immediately, including failed native runs.

Validation: the full JS suite and structural proofs pass, including 22,272
block/scalar fragment comparisons and a 512² raster with independently varying
background depth/color. Rebuilt native CPU/Metal fixtures pass at 512², 1024²
and 2048², including complete Image/array comparisons and thin-line coverage.
See `results/blocks-validation.json`. `scripts/build` rebuilt the demo binaries
and macOS app bundles; the rebuilt Meadow window was also inspected.


## Antialiasing and defocus quality pass (2026-09-28)

These changes prioritize coverage and blur continuity. They do **not** establish
60 FPS with effects. Same Apple M2 Pro, 10 workers, 120 warmup + 600 samples,
seed 42 / preset 1, 1024-square Meadow, no window or HUD. Runs are sequential
and pair order alternates. Raw CSVs and binary/source metadata are retained.

| Comparison, Metal, median of two run medians | Before frame | After frame |
| --- | ---: | ---: |
| Old rounded defocus → continuous 25-texel filter | 26.307 ms | 32.339 ms |
| New rotated AA, copying finish → Image-only finish | 30.485 ms | 30.524 ms |

The smoother defocus adds about **6 ms** in these paired measurements. This is
a quality/cost tradeoff, not a performance improvement. The 25-texel filter has
the same weights as nine bilinear samples while gathering at most 25 texels
instead of 36; zero weights skip reads. The earlier 36-fetch prototype measured
35.871 ms/frame in a separate two-pair comparison, but that is not an isolated
claim about the savings from collapsing duplicate texels.

The defocus data (`quality-final-dof-gpu`) was collected before adding the
Image-only AA specialization; the specialization changes only the AA-without-
defocus route. `quality-aa-present-final` compares that final specialization
with the same rotated pattern and original copying finish. There is **no clear
GPU timing improvement**: both versions shifted from about 26 to 35 ms between
pairs, with simulation timing shifting too. Keeping the simpler Image-only
route avoids unnecessary buffer reads/writes without claiming an FPS gain.

A more invasive single-pass coverage/Image fusion was rejected: one pair was
slightly faster and another slower (`quality-fusion-gpu` and
`quality-fusion-rejected.patch`). `quality-aa-exploratory`,
`quality-final-aa-gpu` (before Image-only specialization), and `quality-dof-gpu`
(the earlier 36-fetch prototype) are exploratory records, not the final paths.

The single CPU AA comparison (`quality-aa-cpu-final`) measured 55.383 ms before
and 59.727 ms after (p95 87.682 / 97.693 ms). This noisy single pair does not
support a speedup claim. All quality-pass timing records above used 2.0.27.

The final source passes the proof suite, all JS correctness suites, native
CPU/Metal geometry/Image checks, and 1021 native depth-filter oracle probes.
`quality-validation.json` records the checked source files and image exports.
The frozen visual comparison is [quality-comparison.html](../results/quality-comparison.html).

## Active Cloth routing and desktop load (2026-09-28)

The interactive Cloth app now always runs its 1024-point physics on CPU.
G selects only the renderer. The solver still uses twelve constraint passes
per substep, up to two substeps per frame, and the same surface contacts.
No reduction in physical resolution or collision work was used for this change.

A short active 512² probe (12 warmup, 30 samples, raw rendering, 10 workers)
measured 9.312 ms CPU physics versus 91.566 ms Metal physics. The corresponding
whole-frame medians were 12.486 and 97.001 ms. These early probes excluded a
window and are not sustained interactive FPS claims.

Longer routing comparisons used 120 warmup + 600 samples, alternating order,
512² raw rendering, Metal drawing in both versions, and the same 2.0.27 pin.
The saved pre-fix binary uses Metal physics; the updated one uses CPU physics.

| Pair | Before frame median / p95 | After frame median / p95 |
| --- | ---: | ---: |
| 0, before then after | 128.924 / 145.339 ms | 87.727 / 320.390 ms |
| 1, after then before | 279.154 / 565.827 ms | 114.242 / 290.587 ms |

Both medians favor CPU physics, but these are **loaded-desktop results**.
A separate Bend Turn window, virtualization and Python work were active;
Turn was relaunched during the measurements. Swap occupancy was 18.4 GB, and
a one-second paging probe observed 16,737 swap-in and 6,916 swap-out pages.
The large change between baseline runs and the worse first-pair p95 prevent
claiming a stable speedup ratio or that all stutters are solved.

The native standard window completed 600 samples with HUD, two active substeps
and display pacing: 54.259 ms median (about 18.4 FPS), 166.586 ms p95. This
particular run used `--gpu off`, not the GPU-enabled app launcher's runtime.
The subsequent Metal/AA window exited with status 0 after 469 samples, so it
is recorded as incomplete, not as a crash or a complete benchmark. High-quality
window timings and the CPU-drawing/GPU-enabled default window were not completed.
Native correctness and Image tests at all supported resolutions did pass.

Raw samples, commands, binary hashes and partial-run status are in
`results/cloth-routing-final.json`; the load observations are in
`cloth-routing-load-note.json`. No builds, tests or other demo instances from
this task ran concurrently with the timed processes. The pre-existing desktop
workloads were left running. `scripts/bench-cloth-interactive.py` reproduces the
comparison using `--before <saved-cloth-frame>`, and `--window --window-default`
measures presentation. Close a test window to stop a window run early.

The global Bend install is 2.0.32. The project remains on 2.0.27 by user choice
because even its small GPU smoke test fails to compile on Metal with 2.0.32;
see `results/bend-upgrade-validation.json` and `repros/metal-2.0.32-issue.md`.

## Per-stage policy and profiler (2026-09-28)

Two alternating orders compared the saved pre-change binaries with the new
policy/timing path, using the same raw settings and ten runtime threads. Cloth
used 12 warmup + 30 measured frames per run; Meadow used 120 + 600. No
concurrent builds/tests or verification windows were running during these runs;
other desktop work was not stopped. These measure headless frame cost.

| Scene / dispatch | Pair 0 before → after (ms) | Pair 1 before → after (ms) |
| --- | ---: | ---: |
| cloth / cpu | 12.070 → 12.310 | 12.258 → 12.223 |
| cloth / hybrid | 16.049 → 16.668 | 15.919 → 15.934 |
| meadow / cpu | 10.943 → 10.284 | 10.746 → 10.821 |
| meadow / gpu | 12.293 → 11.899 | 12.033 → 12.082 |

Here `cloth / hybrid` means the pre-existing CPU simulation + all-GPU drawing
policy (`Policy.cloth(True{})`), not the new CPU-geometry `Policy.hybrid()`
preset. The first pair ran before then after; the second ran after then before.
Variation between orders is comparable to the observed changes; this does not
establish a speedup or a precise timer-only overhead. It measures the combined
policy, stage-boundary and timing change. Timers remain active with H hidden.

The native mixed-policy checks were pixel-exact in this run, including all eight
bin/raster/post choices, all four effect combinations, repeated Image reuse, and
512/1024/2048 targets on both CPU and Metal. The proof/JS suite passed. Cloth,
Meadow, Particle Life and profiler binaries rebuilt successfully. Live Cloth
checks covered G/A/D/Q/H and pause; live Meadow verified H/G labels. These were
functional window checks, not a sustained interactive FPS benchmark.

Short profiler captures (12 warmup + 30 samples) show where work goes:
CPU-physics/geometry Cloth with Metal AA+DoF had 17.892 ms median frame time;
CPU-physics/geometry Meadow with Metal AA had 23.966 ms. These are different
quality settings from the raw comparisons above. See `results/policy-profile-*.csv`
and their text reports for individual stages. Forced CPU fallback and a genuine
CPU-only executable both reported all CPU stage choices.

Raw paired captures and command/binary hashes: `results/policy-comparison.json`.
Validation scope: `results/policy-validation.json`. API and timing definitions:
[EXECUTION.md](EXECUTION.md).

## Shared engine simplification (2026-09-28)

The image/tile/spatial consolidation and depth-filter experiment have separate
raw captures under `results/engine-*`. The [engine review](ENGINE_REVIEW.md)
records source counts, paired measurements, controls and validation. Reproduce
selected cases with `python3 scripts/bench-engine.py --help`; keep builds and
other tests stopped during the timed runs. These are headless frame and
host-elapsed stage measurements, not hardware GPU timestamps or window FPS.


## Camera demos and compatibility (2026-09-28)

The new 1024² scenes use CPU geometry/binning and selectable CPU/Metal raster.
Twenty warmup frames and sixty measured frames follow a deterministic moving
camera; the voxel run edits a four-chunk boundary after warmup. Times below are
median / p95 host-elapsed work, excluding window presentation and pacing.

| Scene | Metal work (ms) | CPU work (ms) |
| --- | ---: | ---: |
| Monochrome | 14.694 / 20.527 | 25.434 / 30.161 |
| Voxels | 12.112 / 14.627 | 19.959 / 23.177 |

The retained legacy Meadow renderer was compared against a saved pre-camera
binary in before/after/after/before order, with 30 warmup + 120 measured frames.

| Pair | Frame before → after (ms) | Raster before → after (ms) |
| --- | ---: | ---: |
| 0 | 14.877 → 13.741 | 7.489 → 7.915 |
| 1 | 16.851 → 13.813 | 9.616 → 7.747 |

This task's builds/tests had finished during timing. Separate Turn campaign tests
and builds, plus ordinary desktop work, remained active. Baseline variation is
large enough that these runs do not establish a precise speedup or overhead.
The corrected legacy raster timings are within the observed baseline range.
Commands, binary hashes and all raw captures: `results/camera-performance.json`.

An initial shared dynamic sampler added camera work to the old pixel path;
preliminary raster captures rose from about 9.7–9.9 ms to 12.4–12.5 ms. Its
rejected patch is `results/camera-unified-raster-rejected.patch`. A subsequent
curried-function selector accidentally left per-pixel closure allocation in
generated code and failed the real Meadow all-GPU workload. The final selector
uses a first-order conditional and restores scalar calls with constant camera
mode. See [the preserved reproduction](../repros/camera-closure-selector.md).
These intermediate binaries are not the final apps.

Final validation passed the proof/JS engine suite, native mesh checks, all eight
execution policies and four effect combinations on CPU/Metal, and twelve full
camera framebuffers. CPU and Metal were pixel-identical in all six paired
captures; Monochrome contained only black and white, including at 2048². The
image-export helper now prepends fixed-size pixel strings in reverse traversal,
avoiding quadratic row copying; an old/new full export compared byte-for-byte.
Scope and source/binary hashes: `results/camera-validation.json`.
