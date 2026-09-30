# Execution policy and frame profiler

Cloth and Meadow now route their work through a shared, explicit execution
policy. Their interactive defaults are unchanged: CPU drawing at startup;
**G** switches drawing for Cloth and the whole pipeline for Meadow. Cloth's
interactive simulation stays on CPU. **H** shows/hides the stage profiler.
Particle Life keeps its existing two-counter HUD.

## Policy API

`engine/parallel/policy.bend` defines a small host-side record:

```bend
Policy.Policy{simulation, geometry, binning, raster, post, simulation_depth}
```

Each Boolean independently requests GPU (`True{}`) or CPU (`False{}`). The
last field controls Cloth's simulation fork depth; CPU simulation uses depth
zero. Meadow retains its existing fixed simulation scheduling.

Presets:

| Constructor | Simulation | Geometry | Binning | Raster | Post |
| --- | --- | --- | --- | --- | --- |
| `Policy.all(False{},0n)` | CPU | CPU | CPU | CPU | CPU |
| `Policy.hybrid()` | CPU | CPU | CPU | GPU | GPU |
| `Policy.cloth(True{})` | CPU | GPU | GPU | GPU | GPU |
| `Policy.all(True{},10n)` | GPU | GPU | GPU | GPU | GPU |

These are choices, not an automatic performance tuner. The all-GPU solver is
still available for experiments and is a poor interactive Cloth default on the
measured M2 Pro. No new preset is claimed to be universally faster.

Use `Cloth.step_policy(settings,policy,paused,substeps,controls,frame)` to receive
`IO(Frame & Profile.Sample)`. `Meadow.frame_policy(policy,input,state,image)`
returns the existing frame tuple with `Player.Measured` metrics. Existing Cloth
`step_effects` / `step_render` calls still work; `Player.summary(metrics)` reads
the common simulation/render/count fields from either metrics constructor.

Both entry points resolve the requested policy against Bend's runtime before
running a frame. `--gpu off` and CPU-only builds clear every GPU stage and reset
the simulation depth. The sample records the resolved choices. The small foreign
effect reads only Bend's `io_gpu` metadata; all computation remains Bend code.
This effect is tied to the pinned 2.0.27 runtime and must be rechecked on upgrade.

The policy is destructured outside kernels. No policy/profile record enters a
per-particle or per-pixel loop. Real IO timing boundaries separate stages so a
GPU stage after CPU parallel work gets a new evaluation root.

## Reading the profiler

The overlay shows elapsed **host** milliseconds for simulation, geometry,
binning, raster, and post. `C` and `G` identify each stage's resolved processor
choice. These timings include dispatch and synchronization; they are not GPU
hardware timestamps. `WORK` is the sum of the five stages.

Raw rendering retains the fused raster + Image assembly path: its entire cost
is under `RAST`, and `POST` is zero. With AA, raster includes coverage resolve;
post includes Image assembly and optional depth of field. A processor flag for
a skipped stage still describes the selected policy, not evidence of a dispatch.
Timers run even when the overlay is hidden. They also establish the stage
boundaries needed for mixed execution. There is no separate profiler-off path.

Work timing excludes window presentation, HUD generation, pacing, resets, and
resolution changes. Headless `frame_us` additionally includes policy resolution,
resize checks/allocation and orchestration; `other = frame - work`. These are
not presented FPS measurements. Use the existing finite window benchmark for
presentation/pacing measurements.

## Capture and compare

`scripts/build` also builds `build/profile`. For example:

```sh
build/profile --gpu on --threads 10 -- cloth hybrid dof standard 120 600 > results/cloth-profile.csv
python3 scripts/profile-report.py results/cloth-profile.csv
build/profile --gpu on --threads 10 -- meadow cpu aa high 120 600 > results/meadow-profile.csv
```

Arguments are scene (`cloth`, `meadow`), policy (`cpu`, `hybrid`, `render`, `gpu`),
effect (`raw`, `aa`, `dof`), resolution (`standard`, `high`), warmup frames and
sample frames. `render` uses CPU simulation and GPU geometry/bin/raster/post.
`dof` enables AA too. Standard/high means 512/1024 for Cloth and 1024/2048 for
Meadow. Each count is capped at 100,000. CSV output is outside the measured frame.

The report validates stage accounting and shows median, nearest-rank p95 and
maximum for every stage, work, other, and total frame time. Preserve captures
with scene/settings and runtime arguments. Warm the scene, run alternatives
sequentially in alternating orders, and account for other desktop workloads.
One loaded-desktop run does not establish a speedup.

## Validation

`tests/policy.js` checks all 32 stage selections, CPU fallback, CSV accounting,
compatibility summaries and HUD bounds. `tests/policy-native.bend` checks all
eight bin/raster/post combinations against the original pure rendering path
with raw, AA, DoF-only and AA+DoF effects. It reuses both buffers and the prior
Image, verifies every presented pixel, and includes 512, 1024 and 2048 targets.
It allows at most one channel value of CPU/Metal blur rounding difference;
raw and AA-only outputs must match exactly. `scripts/test --native` runs it on
both runtime backends. Existing physics, input, rendering and proof tests remain.
