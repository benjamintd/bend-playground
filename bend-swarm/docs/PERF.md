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
