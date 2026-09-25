# GPU-Native Bend Game / Simulation Engine

## Mission

Build a small, extremely fast, GPU-native game/simulation engine in **Bend 2**, designed around Bend's actual execution model rather than copying the architecture of Unity, Unreal, Bevy, Flecs, or a traditional ECS.

The first deliverable is an interactive **massive boids/swarm demo** capable of simulating and rendering as many genuinely interacting agents as possible in real time.

The broader objective is to establish a reusable engine architecture for workloads such as:

- boids and swarms
- particle life
- crowds
- RTS units
- cellular automata
- fluids
- cloth
- vegetation
- destruction
- voxel simulations
- physics
- games with very large numbers of similar entities

The central hypothesis to validate is:

> A game engine designed around Bend's affine ownership, balanced fork/join execution and GPU execution can expose an extremely simple high-level API while achieving unusually high simulation throughput.

Do **not** optimize for feature count.

Optimize for:

1. throughput,
2. simple programming model,
3. predictable GPU execution,
4. minimal memory contention,
5. correctness,
6. measurable performance.

The engine should ultimately make code resembling this possible:

```bend
def update(dt: F32, world: World) -> World:
  grid = Spatial.build!(world.positions)
  world = Spatial.stencil!(grid, world, ~flock(dt))
  Parallel.map!(world, ~integrate(dt))

def frame(world: World) -> Image:
  Renderer.particles!(world.positions)
```

The exact syntax will depend on what Bend currently permits. Preserve the **semantic shape** even if the implementation API needs to differ.

---

# 1. First rule: learn current Bend before implementing

Bend is changing rapidly.

Before writing engine code:

```text
bend version
bend guide
bend guide shaders
bend guide effects
bend base Array
```

Inspect the current upstream repository, in particular:

```text
bendlang/bend/guide/GUIDE.md
bendlang/bend/bend2/base.bend
bendlang/bend/demos/app_slash_boss_3d/
bendlang/bend/demos/app_pong_game_2d/
bendlang/bend/AGENTS.md
bendlang/bend/CHANGELOG.md
```

Record the exact Bend version in:

```text
docs/ENVIRONMENT.md
```

Pin development against that version once the first working baseline exists.

Do not rely on Bend 1 tutorials or old HVM-era behavior.

Do not modify the Bend compiler/runtime as part of the engine unless absolutely unavoidable.

If a Bend limitation is encountered:

1. reduce it to a tiny reproduction,
2. place that reproduction under `repros/`,
3. document it,
4. work around it at engine level if reasonably possible.

The engine should demonstrate Bend, not become a fork of Bend.

---

# 2. Non-negotiable architectural principles

## 2.1 GPU first

The simulation architecture should be designed for thousands of parallel GPU lanes from the beginning.

CPU execution is important primarily because:

- the same code should run there,
- it provides a correctness/debug baseline,
- it demonstrates Bend's CPU/GPU portability.

Do not build a CPU architecture and then "GPU accelerate" it afterward.

---

## 2.2 Same algorithm on CPU and GPU

The flagship capability should be:

```text
same Bend implementation
        ↓
CPU execution
        or
GPU execution
```

The game author must not maintain:

```text
boids_cpu.bend
boids_cuda.cu
boids_metal.metal
```

Ideally there is one core function:

```bend
def Boids.step(...):
  ...
```

and thin wrappers decide whether its parallel root is invoked normally or with `!`.

For example, conceptually:

```bend
def step_cpu(world):
  Boids.step(world)

def step_gpu(world):
  Boids.step!(world)
```

Do not duplicate the algorithm merely to benchmark CPU versus GPU.

---

## 2.3 Do not build a conventional ECS first

Do not begin with:

```text
Entity ID
Archetype
Component registry
Dynamic query planner
Sparse sets
Runtime reflection
System scheduler
```

Those are solutions to constraints from other engines.

The fundamental engine representation should instead be:

> **dense, owned, parallel data blocks**

Expose an ECS-like API later if useful.

The runtime architecture should be able to specialize systems at compile time and operate directly on dense memory.

---

## 2.4 Prefer Structure of Arrays

The flagship workload should use something conceptually equivalent to:

```text
World
  count
  capacity

  position_x[]
  position_y[]

  velocity_x[]
  velocity_y[]

  species[]
```

rather than:

```text
Boid {
  position
  velocity
  species
}

Boid[]
```

unless benchmarking demonstrates that Bend's representation changes this conclusion.

Reasons:

- contiguous numeric access,
- fewer unnecessary fields loaded,
- simpler partitioning,
- easier double buffering,
- easier GPU access,
- better specialization.

Because Bend arrays are power-of-two shaped, maintain:

```text
capacity = power of two
active_count <= capacity
```

as distinct concepts.

---

## 2.5 Ownership boundaries should correspond to parallelism boundaries

Design data such that a parallel task owns what it mutates.

Ideal pattern:

```text
              WORLD
                 |
          +------+------+
          |             |
       chunk A       chunk B
          |             |
       worker         worker
          |             |
      writes A       writes B
```

Avoid architectures where thousands of lanes continuously mutate a shared object.

A system should normally:

```text
read previous state
write exclusively owned next state
```

This naturally suggests double buffering for many simulation operations.

---

## 2.6 Avoid shared `+Data` in inner GPU loops

Treat shared/refcounted structures inside hot GPU loops as suspicious until benchmarked.

In particular:

- do not pass a boxed world/config/tree into every boid update,
- do not have each particle traverse shared linked structures,
- do not create shared lists per pixel,
- avoid repeatedly opening shared nodes.

Prefer hot parameters as scalars:

```text
dt
radius
alignment_strength
cohesion_strength
separation_strength
world_width
world_height
```

Small immutable configuration should ideally ride through calls as scalar values.

---

## 2.7 `@unsafe` must be surgical

Recent Bend versions provide:

```text
Array.fork
Array.join
Array.atomic.*
```

for shared arrays.

These are potentially extremely useful.

They are not permission to abandon the affine architecture.

Every unsafe operation must live in a narrowly scoped primitive such as:

```text
Spatial.AtomicHistogram
Spatial.AtomicScatter
Render.AtomicCounter
```

Do not leak unsafe handles through the public API.

For every unsafe primitive:

- explain why it is necessary,
- provide a correctness test,
- provide a safe/reference implementation where practical,
- benchmark the benefit,
- state the invariant expected by callers.

---

# 3. What we are actually building

The v0 project consists of four layers:

```text
Application / Demo
        |
Simulation primitives
        |
Spatial + Parallel primitives
        |
Bend runtime / GPU
```

Specifically:

```text
Engine
├── Core
│   ├── Math
│   ├── Time
│   └── Random
│
├── Parallel
│   ├── Map
│   ├── Reduce
│   ├── Scan
│   ├── Partition
│   └── ExecutionPlan
│
├── Spatial
│   ├── Cell mapping
│   ├── Grid construction
│   ├── Neighbor iteration
│   └── Stencil
│
├── Render
│   ├── Screen bins
│   ├── Tiles
│   ├── Particles
│   └── HUD
│
└── Demo
    └── Swarm
```

Do not add:

- asset pipelines
- scene serialization
- scripting
- editors
- skeletal animation
- networking
- fancy UI
- physics APIs
- plugins

until the swarm architecture is proven.

---

# 4. Repository structure

Start approximately with:

```text
/
├── AGENTS.md
├── README.md
├── LAWS.bend
├── PROOF.bend
│
├── engine/
│   ├── core/
│   │   ├── math.bend
│   │   ├── random.bend
│   │   └── time.bend
│   │
│   ├── parallel/
│   │   ├── map.bend
│   │   ├── reduce.bend
│   │   ├── scan.bend
│   │   ├── partition.bend
│   │   └── plan.bend
│   │
│   ├── spatial/
│   │   ├── cell.bend
│   │   ├── grid.bend
│   │   ├── histogram.bend
│   │   ├── scan.bend
│   │   ├── scatter.bend
│   │   └── stencil.bend
│   │
│   └── render/
│       ├── camera.bend
│       ├── screen_grid.bend
│       ├── particles.bend
│       ├── tiles.bend
│       └── hud.bend
│
├── demos/
│   └── swarm/
│       ├── main.bend
│       ├── world.bend
│       ├── boids.bend
│       ├── controls.bend
│       └── config.bend
│
├── tests/
│   ├── parallel/
│   ├── spatial/
│   ├── boids/
│   └── render/
│
├── benches/
│   ├── map.bend
│   ├── grid.bend
│   ├── boids.bend
│   ├── render.bend
│   └── full_frame.bend
│
├── repros/
│
├── scripts/
│   └── bench.sh
│
└── docs/
    ├── ARCHITECTURE.md
    ├── ENVIRONMENT.md
    ├── PERF.md
    └── FINDINGS.md
```

Adjust if Bend module/import constraints make another layout more practical.

---

# 5. AGENTS.md

Create an `AGENTS.md` immediately.

It should explicitly tell future code agents:

```text
When editing this project:

1. Read `bend guide`.
2. Read `bend guide shaders`.
3. Inspect the current relevant Base definitions instead of guessing APIs.
4. Run correctness tests after every structural change.
5. Run `bend PROOF.bend` whenever code covered by laws changes.
6. Do not introduce per-agent heap allocations in frame loops.
7. Do not introduce shared +Data into an inner GPU loop without benchmarking it.
8. Keep unsafe array sharing isolated.
9. Do not use foreign C/Metal/CUDA code for simulation or rendering computation.
10. Benchmark before and after every performance-oriented architectural change.
11. Prefer simpler data layouts over abstraction layers.
12. Never claim a performance improvement without numbers.
```

---

# 6. Core public programming model

Do not obsess over exact syntax during the first implementation.

Aim for an API semantically similar to:

```bend
def tick(dt: F32, world: World) -> World:
  grid = Spatial.build!(world.positions)

  world =
    Spatial.stencil!(
      grid,
      world,
      ~Boids.flock(dt)
    )

  Parallel.map!(
    world,
    ~Boids.integrate(dt)
  )
```

An eventual game-facing API might look like:

```bend
type Game<S>:
  Game{
    init: S,
    tick: List<Event> -> S -> IO(Maybe<S>),
    view: S -> S & Image
  }
```

or wrap Bend's existing `App` abstraction.

Do not reimplement window management if `App.run` already provides the needed event/render loop.

The engine should be primarily a **library**, not an editor/application.

---

# 7. Parallel abstraction

Create a small `Parallel` module.

The goal is not to hide Bend parallelism completely.

The goal is to provide reusable **balanced execution shapes**.

Conceptually support:

```text
Parallel.map
Parallel.reduce
Parallel.scan
Parallel.partition
```

and execution plans:

```text
ExecutionPlan {
    fork_depth
    leaf_size
}
```

Do not hard-code a universal fork depth.

---

# 8. ExecutionPlan and fork-depth tuning

This is important.

Bend GPU performance can change dramatically depending on how deep work is recursively forked before leaves begin doing sequential work.

Therefore implement explicit tuning infrastructure early.

For every major kernel-like operation:

```text
Spatial.build
Boids.update
Renderer.tiles
```

allow a plan resembling:

```text
ExecutionPlan {
  fork_depth
  leaf_items
}
```

Initially these can be constants.

Then add a benchmark sweep.

For example:

```text
boids/update
N = 262144

depth 4     4.84 ms
depth 5     2.77 ms
depth 6     1.93 ms
depth 7     1.41 ms
depth 8     1.48 ms
depth 9     1.92 ms
```

Select:

```text
depth 7
```

Eventually create:

```text
Autotune
```

which benchmarks a handful of plans at startup or offline and records the fastest one.

Do not make autotuning a prerequisite for the first demo.

But design so that execution geometry isn't encoded throughout simulation code.

---

# 9. World representation

Initial swarm world:

```text
World
  active_count : U32
  capacity     : U32

  pos_x        : Array<F32>
  pos_y        : Array<F32>

  vel_x        : Array<F32>
  vel_y        : Array<F32>

  species      : Array<U32>
```

If color can be derived cheaply from species, do not store it.

If heading can be derived from velocity, do not store it.

Keep the initial hot state extremely small.

Use deterministic initialization from a seed.

Support powers of two from small test sizes upward:

```text
2^10
2^12
2^14
2^16
2^18
2^20
```

Do not allocate all capacities simultaneously.

---

# 10. Double buffering

Boids require every agent to observe the same logical old frame.

Do not update positions in place and then let later agents read already-updated positions.

Use logically separate:

```text
current
next
```

buffers.

Conceptually:

```text
FrameState
  current_position
  current_velocity

  next_position
  next_velocity
```

After the step, swap them.

Do not physically copy the whole world simply to swap state if affine ownership allows buffers to be moved/rebound cheaply.

---

# 11. Build the naive reference first

Before spatial optimization, implement mathematically straightforward boids for small N:

```text
for each boid:
    inspect every other boid
```

Yes, this is O(N²).

It is not the production algorithm.

It is the **reference implementation**.

Use perhaps:

```text
N <= 1024
```

for correctness tests.

This version establishes the expected behavior for:

- separation
- alignment
- cohesion
- boundary handling
- attraction
- repulsion

The optimized implementation must be testable against it.

---

# 12. Boids behavior

Each boid should have three canonical forces.

## Separation

Repel agents that are too close.

```text
force += position_self - position_neighbor
```

weighted strongly at short distance.

## Alignment

Steer toward average local velocity.

```text
force += avg_neighbor_velocity - velocity_self
```

## Cohesion

Steer toward the center of nearby agents.

```text
force += avg_neighbor_position - position_self
```

Use configurable radii/weights.

Do not use expensive operations unnecessarily.

In particular benchmark avoiding:

```text
sqrt
normalize
division
```

inside the deepest neighbor loop.

Prefer squared distance:

```text
dx*dx + dy*dy < radius_squared
```

Normalize only where visibly necessary.

Cap acceleration and speed.

---

# 13. Spatial grid

This is the project's most important algorithmic subsystem.

A boid should inspect only nearby spatial cells.

Choose:

```text
cell_size ≈ interaction_radius
```

so a boid normally considers the surrounding:

```text
3 × 3 cells
```

in 2D.

Conceptually:

```text
+------+------+------+
|      |      |      |
+------+------+------+
|      | SELF |      |
+------+------+------+
|      |      |      |
+------+------+------+
```

This turns practical neighbor lookup from O(N²) toward O(N*k), with `k` representing local density.

---

# 14. Do not assume the best grid construction algorithm

Implement and benchmark at least two approaches if Bend permits them cleanly.

## Approach A — safe/reference organization

Use an affine/pure data transformation such as sorting or partitioning agents by cell.

Its purpose is:

- correctness,
- understanding Bend's ownership model,
- providing comparison.

It does not need to become the final fastest implementation.

## Approach B — histogram + prefix scan + scatter

Investigate a GPU-style pipeline:

```text
positions
    ↓
cell IDs
    ↓
atomic histogram
    ↓
exclusive scan
    ↓
cell offsets
    ↓
scatter agent IDs
```

This is the likely performance-oriented algorithm.

Potential unsafe operations should be restricted to:

```text
histogram increment
scatter cursor increment
```

not the entire simulation.

Pipeline:

```text
1. Compute cell_id[i]
2. counts[cell_id[i]]++
3. offsets = exclusive_scan(counts)
4. cursors = offsets
5. slot = atomic_increment(cursors[cell_id[i]])
6. sorted_agent_ids[slot] = i
```

Then:

```text
cell c occupies
sorted_agent_ids[
  offsets[c]
  ..
  offsets[c+1]
]
```

This gives contiguous neighbor ranges.

---

# 15. Critical research spike: shared grid reads

Before committing to the production spatial design, explicitly benchmark how read-only neighborhood access behaves with the current Bend implementation.

Try at least these architectures:

### Variant 1: shared sorted arrays

Workers access shared position/index arrays while owning their output ranges.

Validate current `Array.fork/join` semantics and actual GPU cost.

### Variant 2: cell-owned blocks

Partition boids into cell/chunk structures and operate cell-by-cell.

### Variant 3: local halo

Construct chunks with a local neighborhood/halo so hot loops avoid remote/shared structures.

For example:

```text
central cell + 8 neighbor cells
```

may be copied/packed once, then reused by many interactions.

Measure:

```text
memory overhead
grid-build cost
neighbor throughput
total frame cost
```

Do not decide based on theoretical elegance.

Pick the fastest measured architecture.

Record all results in:

```text
docs/FINDINGS.md
```

This document should become one of the project's valuable outputs.

---

# 16. Spatial API

The user-facing abstraction should eventually hide the chosen grid implementation.

Target semantics:

```bend
grid = Spatial.build!(positions, cell_size)

result =
  Spatial.stencil!(
    grid,
    state,
    ~Boids.update
  )
```

`stencil` means:

> each owned output region may inspect a bounded neighborhood of the previous state.

This abstraction should later generalize to:

- particle life
- collision broadphase
- cellular automata
- crowd simulation
- fluid grids
- vegetation
- RTS proximity queries

Treat `Spatial.stencil` as a potential core engine concept.

---

# 17. Rendering architecture

Do not rasterize each boid directly into one shared framebuffer with arbitrary writes unless benchmarks show it is superior.

Prefer ownership by **screen tile**.

Conceptually:

```text
boids
   ↓
screen-space binning
   ↓
tile lists
   ↓
parallel tile renderer
   ↓
Image quadtree
```

Each rendering task should own its tile/pixels.

This mirrors the simulation architecture.

---

# 18. First renderer

The first renderer does not need textured meshes.

It needs to render an enormous number of agents cheaply and attractively.

Start with:

```text
2D points / tiny oriented triangles / short streaks
```

Each boid can be visualized using velocity direction.

Useful visual modes:

```text
point
velocity streak
triangle
density
```

Color by:

```text
species
speed
neighbor count
```

The renderer should support hundreds of thousands of visible agents before sophisticated geometry is considered.

---

# 19. Pure Bend rendering requirement

For the flagship demo:

> simulation and principal rendering computation must be Bend.

Do not hide performance-critical code in:

```text
C
Metal shaders
CUDA kernels
Rust
```

Host FFI is acceptable for truly host-level functionality if needed:

- window integration,
- timing,
- platform information.

But the demonstration loses its purpose if the "fast Bend engine" delegates the real work to a hand-written GPU shader.

Use Bend's existing `Image`, `Window`, `App`, and GPU execution mechanisms as far as reasonably possible.

---

# 20. Tile renderer

The screen should be recursively subdivided into tiles.

For example:

```text
1920 × 1080
       ↓
tile grid
       ↓
each worker owns one tile
       ↓
render all particles intersecting tile
```

Choose power-of-two geometry where it fits Bend/Image naturally.

Investigate:

```text
8×8
16×16
32×32
```

tile sizes.

Benchmark them.

The optimal tile size may vary with GPU and particle density.

Make it part of `ExecutionPlan`.

---

# 21. Avoid per-pixel shared lists

Do not construct:

```text
one linked list per pixel
```

or let every pixel repeatedly inspect a shared global particle collection.

Bin work at a coarser granularity.

For example:

```text
one particle range/list per tile
```

and then perform local pixel work.

Keep shared structure traversal outside the innermost pixel loop.

---

# 22. Frame pipeline

The final frame should look roughly like this:

```text
INPUT
  ↓
SIMULATION PARAMETERS
  ↓
SPATIAL CELL IDS
  ↓
GRID BUILD
  ↓
NEIGHBOR / FLOCK UPDATE
  ↓
INTEGRATION
  ↓
SCREEN BINNING
  ↓
TILE RENDER
  ↓
HUD
  ↓
WINDOW
```

Every stage must be measurable independently.

---

# 23. Timing

Collect at minimum:

```text
grid build ms
simulation ms
integration ms
render binning ms
render ms
total frame ms
FPS
```

Do not compute/display expensive text every frame if it affects benchmark results.

Update the HUD perhaps:

```text
4 times/second
```

while internal timers continue sampling every frame.

Strings should stay outside hot paths.

---

# 24. Flagship Swarm demo

The visual goal is a demo that someone immediately understands in a short video.

Default scene:

```text
dark background
hundreds of thousands of luminous agents
fluid flocking motion
very high apparent responsiveness
minimal UI
```

The demo should open directly into the simulation.

No menus.

---

# 25. Interaction

Implement as many of these as the current Bend input API permits cleanly:

```text
mouse move        attractor position
left mouse        attract
right mouse       repel

Space             pause
R                 reset deterministic seed
G                 switch CPU/GPU execution
H                 HUD
B                 benchmark mode

Up / ]            double agent count
Down / [          halve agent count

1                 points
2                 streaks
3                 triangles
4                 density visualization
```

If current Bend input doesn't expose one of these cleanly, use the closest equivalent rather than adding major host infrastructure.

---

# 26. Particle-count scaling

The user must be able to change population by powers of two.

Suggested levels:

```text
4,096
16,384
65,536
131,072
262,144
524,288
1,048,576
2,097,152
```

Do not guarantee the largest sizes will fit all GPUs.

Gracefully reject unsupported capacities.

Display the active count prominently.

---

# 27. Visual payoff

The swarm should have enough behavioral variation that it visibly demonstrates interaction rather than merely drawing independent particles.

Add, in order:

1. flocking,
2. mouse attractor,
3. mouse repulsor,
4. multiple species,
5. predator,
6. obstacles.

Do not implement all of these before the main pipeline is fast.

Performance comes first.

---

# 28. Species / Particle Life extension

Once basic boids are successful, use the same engine to implement a second demo:

```text
Particle Life
```

Each species has an interaction matrix:

```text
          R      G      B      Y
R       +0.2   -0.8   +0.4   ...
G       +0.7   +0.1   -0.6   ...
B       ...
```

Local forces emerge from these values.

This is valuable because it tests exactly the same engine primitive:

```text
Spatial.stencil
```

while producing dramatically different emergent behavior.

Do not build Particle Life until Swarm is benchmarked and stable.

---

# 29. Correctness tests

Every performance primitive needs a small correctness version.

## Parallel

Test:

```text
map
reduce
scan
partition/reassembly
```

with tiny arrays where results are obvious.

## Grid

For random small scenes:

```text
N = 8
N = 32
N = 128
```

compare grid neighborhood lookup against brute force.

For every boid:

```text
bruteforce_neighbors == grid_neighbors
```

modulo exactly specified distance/cell semantics.

## Boids

Compare one optimized step against the O(N²) reference on small deterministic inputs.

## Renderer

For tiny known scenes, verify stable image/checksum output where possible.

---

# 30. CPU/GPU equivalence

Create a deterministic benchmark scene.

Run one or more steps through:

```text
CPU
GPU
```

Compare resulting state.

Because floating point and GPU math may not always be bit-identical, design a robust comparison.

Possible strategies:

```text
quantized positions
bounded absolute error
bounded velocity error
aggregate checksums after quantization
```

Do not hide genuine divergence behind excessively loose tolerances.

---

# 31. LAWS.bend

Use Bend proofs for structural invariants.

Do not waste time trying to formally prove complicated F32 dynamics; Bend currently treats F32 axiomatically.

Good laws include things such as:

### Population preservation

```text
step does not change active_count
```

### Partition preservation

```text
partition followed by merge preserves element count
```

### Grid index range

```text
cell IDs produced from valid integer coordinates lie within grid capacity
```

### Prefix-scan structure

```text
final offset equals total item count
```

where practical.

### Reordering

If implementing a permutation/reordering primitive:

```text
reordering preserves length
```

and perhaps a tractable symbolic property of membership/index mapping.

### Capacity

```text
active_count <= capacity
```

where represented with proof-friendly integers.

---

# 32. PROOF.bend

Every law must have its corresponding proof.

`PROOF.bend` should be part of the normal development gate:

```text
bend PROOF.bend
```

Do not let proofs grow into a research project that blocks the first performance prototype.

Prioritize laws around primitives where an AI-generated bug would be especially dangerous:

```text
partitioning
indexing
grid construction
scan
buffer swaps
```

---

# 33. Unsafe correctness strategy

Anything using `@unsafe`, array aliasing or atomics must have a reference oracle.

For example:

```text
Spatial.build_safe
Spatial.build_fast
```

For random small inputs:

```text
normalize(build_safe(input))
==
normalize(build_fast(input))
```

Run many deterministic seeds.

If ordering differs but semantics do not, compare canonicalized outputs rather than raw storage order.

---

# 34. Performance benchmark harness

Do not benchmark by staring at FPS.

Create dedicated benchmarks for:

```text
parallel map
grid cell-id computation
histogram
scan
scatter
grid total
boid neighbor update
integration
screen binning
rendering
full frame
```

Sizes:

```text
2^10
2^12
2^14
2^16
2^18
2^20
```

where applicable.

---

# 35. Benchmark methodology

For each result record:

```text
date
git commit
Bend version
OS
CPU
GPU
agent count
window resolution
simulation parameters
fork depth
leaf size
warmup frames
sample frames

mean
median
p95
minimum
maximum
```

Use milliseconds as the primary metric.

FPS is secondary.

---

# 36. Warmup

GPU compilation/startup/allocation must not contaminate steady-state measurements.

Use:

```text
warmup frames
then measured frames
```

For example:

```text
120 warmup
600 measured
```

Adjust if necessary.

Report the methodology.

---

# 37. Benchmark mode

Add a noninteractive CLI benchmark mode if possible.

Conceptually:

```text
./swarm --bench --agents 262144 --frames 600
```

Output something simple and machine-readable, for example:

```text
agents=262144
grid_ms=0.82
sim_ms=2.14
render_ms=1.73
frame_ms=4.91
```

Optionally emit CSV.

Keep benchmark output simple enough that shell tooling can collect it.

---

# 38. Fork-depth sweeps

Add a dedicated benchmark script for:

```text
fork_depth × agent_count
```

For each major stage.

Example table:

```text
N=262144

depth    grid     sim      render
4        2.91     4.13     3.84
5        1.80     2.77     2.34
6        1.10     1.91     1.72
7        0.91     1.45     1.62
8        0.94     1.52     1.81
```

This should directly inform defaults.

---

# 39. Memory measurement

Performance isn't just FPS.

Track approximate:

```text
bytes / agent
grid overhead
render-bin overhead
total GPU heap requirement
```

Avoid a design that reaches fantastic FPS for 100k agents but exhausts memory at 500k because every stage clones the world repeatedly.

---

# 40. Optimization order

When the initial version works, optimize in this order:

### 1. Algorithm

Eliminate O(N²).

### 2. Memory layout

Remove pointer chasing, boxing, unnecessary structures.

### 3. Shared-data contention

Identify shared/refcount/atomic hotspots.

### 4. Fork geometry

Tune depth and leaf size.

### 5. Allocations

Reuse buffers where Bend semantics make that possible.

### 6. Arithmetic

Only then micro-optimize distance math etc.

Do not spend hours shaving an instruction from the boid force equation while the architecture performs millions of unnecessary neighbor checks.

---

# 41. Profiling without a mature profiler

Bend currently has limited profiling tooling.

Therefore instrument stage boundaries manually.

Change one thing at a time.

Keep a log in:

```text
docs/PERF.md
```

Example:

```text
## 2026-xx-xx — replace shared cell lists with packed ranges

Hardware:
Bend:
Commit:

262k agents:

before:
grid 2.4 ms
sim 6.1 ms

after:
grid 1.9 ms
sim 2.7 ms

Conclusion:
shared cell-list traversal was dominant.
```

Never delete old findings merely because an optimization supersedes them.

---

# 42. Avoid abstraction-induced regressions

A reusable abstraction is only accepted if it compiles to approximately the same performance as the specialized version.

For example, before replacing:

```text
Boids.specialized_update
```

with:

```text
Spatial.stencil(~callback)
```

benchmark both.

If the generic abstraction costs 40%, keep the specialized implementation and investigate why.

The engine exists to make fast code ergonomic, not merely elegant.

---

# 43. No per-agent closures unless proven cheap

Higher-order functions make the API appealing.

They may or may not compile optimally in a hot Bend path.

Benchmark:

```text
specialized direct call
```

versus:

```text
callback / closure
```

If compile-time templates can eliminate abstraction overhead, use them.

Otherwise public APIs can remain higher-level while specialized internal implementations handle performance-critical paths.

---

# 44. Public engine API target

Once the performant primitives exist, shape them into something like:

```bend
def Game.tick(dt: F32, game: Game) -> Game:
  game.world
    |> Spatial.index!(game.grid)
    |> Spatial.stencil!(~Boids.flock(dt))
    |> Parallel.map!(~Boids.integrate(dt))

def Game.view(game: Game) -> Image:
  Renderer.begin(game.camera)
    |> Renderer.particles!(game.world)
    |> Renderer.finish!()
```

Do not sacrifice performance merely to achieve method chaining.

This is a design target, not a syntax requirement.

---

# 45. The key abstraction is not "Entity"

If the implementation succeeds, document this clearly:

> The fundamental unit of the engine is an **owned parallel region**, not an entity.

An "entity" may simply correspond to an index across dense component buffers.

A "system" is a parallel transformation of those buffers.

A "spatial system" is a bounded stencil transformation.

This is the conceptual contribution of the project.

---

# 46. The three foundational primitives

Try to reduce most of the engine to three concepts:

## Map

```text
one input → one output
```

Examples:

```text
integration
color computation
cell ID
```

## Reduce / Scan

```text
many values → aggregate / offsets
```

Examples:

```text
histograms
prefix sums
statistics
```

## Stencil

```text
one owned output
+
bounded neighborhood read
```

Examples:

```text
boids
particle life
collision
cell automata
fluid neighborhoods
```

If these three become extremely fast and ergonomic, the project has already succeeded.

---

# 47. Autotuning

After static execution plans work, implement a simple autotuner.

Do not use machine learning.

Try perhaps:

```text
fork_depth ∈ [5, 6, 7, 8, 9]
leaf_size  ∈ reasonable powers of two
```

Warm each configuration.

Measure a handful of iterations.

Select fastest.

Cache by:

```text
GPU/backend
agent-count bucket
operation
```

Example:

```text
Metal / sim / 2^18 -> depth 7
Metal / render / 2^18 -> depth 6
```

If querying GPU identity is inconvenient, cache only for the current run initially.

---

# 48. CPU/GPU toggle

The demo should visibly demonstrate Bend's execution model.

HUD:

```text
Backend: GPU / Metal
```

Press:

```text
G
```

and switch to:

```text
Backend: CPU / 10 workers
```

The simulation continues using the same algorithm.

This is arguably the most important feature for explaining the project.

---

# 49. HUD

Minimal HUD:

```text
BEND SWARM

Agents            262,144
Backend        GPU / Metal

Grid               0.82 ms
Simulation         2.14 ms
Render             1.73 ms
Frame              4.91 ms

FPS                  203

Fork depth             7
```

Optional:

```text
Neighbor checks/s
Average neighbors
Memory
```

Do not compromise performance to draw the HUD.

---

# 50. Neighbor throughput

Track a meaningful simulation metric:

```text
neighbor candidates evaluated / second
```

This is more informative than FPS alone.

For example:

```text
Neighbor checks: 1.8 billion/s
```

Count candidate interactions from spatial cells, not merely accepted neighbors.

This makes optimization work easier to evaluate.

---

# 51. Benchmark target

Do not define success as one arbitrary FPS figure on unknown hardware.

Instead optimize for scaling.

However, use the following aspirational milestones:

```text
65k agents:
should be trivially interactive

262k agents:
should remain highly interactive on a modern GPU

1,048,576 agents:
stretch target for ≥60 Hz complete simulation if architecture/runtime permit
```

Rendering and simulation must be reported separately.

If one million true boids cannot reach 60 Hz:

- do not cheat,
- identify the bottleneck,
- document it,
- optimize systematically.

A well-understood 350k-agent engine is more valuable than a fake "million particle" demo where particles do not actually interact.

---

# 52. What counts as a boid

For benchmark claims, every active boid must actually participate in:

```text
spatial insertion
neighbor candidate lookup
separation
alignment
cohesion
integration
rendering
```

Do not count decorative particles that only move ballistically.

---

# 53. Reference demos are inspiration, not benchmarks

The visual benchmark is demos such as Gabriel Dechichi's large-boid engine demonstrations:

```text
huge visible population
simple scene
clear performance number
instant visual comprehension
```

Do not state:

```text
X times faster than engine Y
```

unless the comparison uses:

- same machine,
- same number of agents,
- same interaction rules,
- same neighbor algorithm,
- same output resolution,
- same benchmark methodology.

Web/native results are not directly comparable.

---

# 54. Optional external baseline

Only after Bend is working well, consider implementing a very small independent reference implementation in:

```text
C / CUDA / Metal
```

solely to answer:

> How far is Bend from an expert low-level implementation of the same algorithm?

This code must remain under:

```text
reference/
```

and must never be linked into the Bend demo.

It is a benchmark oracle, not part of the engine.

This is a later milestone.

---

# 55. Development phases

## Phase 0 — Bend reconnaissance

Deliver:

```text
docs/ENVIRONMENT.md
docs/FINDINGS.md
```

Confirm:

- current array API,
- App/window API,
- GPU invocation,
- F32 operations,
- timing functions,
- `Array.fork/join`,
- atomic API,
- Image representation,
- relevant existing demos.

Write tiny experiments for anything uncertain.

Do not start the full engine until GPU compilation works.

---

## Phase 1 — parallel microbenchmarks

Implement:

```text
map
reduce
scan
```

Measure:

```text
CPU
GPU
multiple fork depths
```

Goal:

understand Bend execution geometry before adding boids.

---

## Phase 2 — minimal renderer

Display:

```text
thousands → hundreds of thousands
```

of static/moving points.

No flocking yet.

Benchmark tile sizes and fork depths.

Goal:

establish maximum particle rendering throughput.

---

## Phase 3 — naive boids reference

Implement O(N²) boids.

Keep population small.

Test deterministic behavior.

Goal:

create correctness oracle.

---

## Phase 4 — spatial grid

Implement:

```text
cell IDs
grid construction
neighbor ranges
```

Compare neighborhoods to brute force.

Goal:

correct O(N*k) interactions.

---

## Phase 5 — GPU swarm

Integrate:

```text
grid
flocking
integration
rendering
```

Support at least:

```text
65k
262k
```

agents interactively where hardware allows.

Goal:

first shareable demo.

---

## Phase 6 — spatial architecture shootout

Benchmark alternatives:

```text
shared arrays
owned cells
halo/local packing
safe sort
atomic histogram/scatter
```

Select architecture based on complete frame time.

Goal:

remove the largest structural bottleneck.

---

## Phase 7 — autotuning

Sweep:

```text
fork depth
leaf size
tile size
```

Goal:

avoid hardware-specific magic constants.

---

## Phase 8 — laws and proof hardening

Formalize structural invariants.

Goal:

demonstrate that Bend is not merely fast; important transformations are mechanically constrained.

---

## Phase 9 — Particle Life

Reuse:

```text
Parallel
Spatial
Renderer
```

with a different simulation.

Goal:

prove this is an engine architecture, not hard-coded boids.

---

# 56. First shareable milestone

Do not wait for every planned feature.

The first public-quality milestone should require only:

```text
✓ native Bend window
✓ GPU simulation
✓ spatial grid
✓ genuine flocking
✓ 100k+ agents
✓ interactive attractor
✓ GPU/CPU switch
✓ live performance HUD
✓ source code readable enough to show
```

Capture a short demo where:

1. swarm begins at ~65k,
2. user increases population,
3. swarm remains fluid,
4. user attracts/repels it with mouse,
5. HUD shows GPU,
6. user toggles CPU,
7. performance changes visibly,
8. user toggles back to GPU,
9. population increases again.

That tells the whole Bend story in seconds.

---

# 57. Stretch visual moment

Once everything else works, add a deterministic target-position mode.

Agents temporarily form:

```text
BEND
```

on screen.

Then release back into flocking.

This is purely visual polish and should never precede core optimization.

---

# 58. Performance anti-pattern checklist

During reviews, explicitly search for:

```text
[ ] boxed data shared by every GPU lane
[ ] linked lists in hot loops
[ ] per-agent allocation per frame
[ ] per-pixel shared structures
[ ] repeated Array.clone
[ ] accidental O(N²) loops
[ ] unnecessary sqrt
[ ] unnecessary normalization
[ ] strings inside simulation loops
[ ] callbacks that defeat specialization
[ ] atomics inside neighbor inner loops
[ ] giant monolithic GPU leaf
[ ] excessively fine fork tree
[ ] divergent work assigned to balanced GPU workers
```

Any one of these can invalidate the architecture.

---

# 59. Commit discipline

Prefer small commits corresponding to measurable milestones:

```text
parallel map baseline
GPU map benchmark
naive boids
spatial cell IDs
grid histogram
grid scan
grid scatter
neighbor correctness
GPU flock
tile renderer
HUD
autotuning
```

Performance commits should mention results.

Example:

```text
spatial: packed cell ranges reduce 262k sim 5.8ms → 2.9ms
```

---

# 60. When encountering surprising performance

Do not immediately rewrite everything.

Create the smallest benchmark that reproduces the issue.

Examples:

```text
shared record vs scalar args
array read vs copied chunk
depth 6 vs depth 8
closure vs direct call
atomic histogram vs sort
```

The goal is to learn the Bend cost model.

Put surprising discoveries into:

```text
docs/FINDINGS.md
```

with runnable reproductions where practical.

The project should become a useful body of knowledge about writing high-performance Bend.

---

# 61. README story

The eventual README should explain the project in this order:

## What

A GPU-native simulation/game engine written in Bend.

## Why

Game engines normally require explicitly separate CPU/GPU code and complex synchronization.

This engine investigates whether Bend's parallel execution model can remove those distinctions.

## Example

Show the tiny swarm update API.

## Demo

Animated swarm screenshot/video.

## Numbers

Present reproducible benchmark tables.

## Architecture

Explain:

```text
dense buffers
balanced fork/join
spatial stencil
tile rendering
```

## Proofs

Explain structural laws.

## Run it

Minimal commands.

Avoid grand claims unsupported by reproducible benchmarks.

---

# 62. Definition of success for v0

v0 is complete when all of these are true:

### Engine

- reusable `Parallel` module exists,
- reusable `Spatial` module exists,
- reusable particle renderer exists,
- no conventional ECS is required,
- no hand-written CUDA/Metal kernels perform the simulation.

### Simulation

- boids use a spatial neighbor structure,
- separation/alignment/cohesion work,
- results have a brute-force correctness oracle,
- CPU and GPU paths use the same core algorithm.

### Demo

- interactive native window,
- ≥100k genuine boids supported on suitable modern hardware,
- scalable powers-of-two population,
- attract/repel interaction,
- backend displayed,
- frame-stage timings displayed.

### Performance engineering

- fork-depth sweep exists,
- grid benchmark exists,
- sim benchmark exists,
- render benchmark exists,
- complete-frame benchmark exists,
- results and machine configuration documented.

### Correctness

- deterministic small tests exist,
- optimized grid agrees with reference implementation,
- unsafe primitives have tests,
- useful structural laws exist,
- `PROOF.bend` passes.

### Documentation

- architecture documented,
- important Bend performance findings documented,
- benchmark methodology documented.

---

# 63. Stretch definition of success

The project becomes especially compelling if:

```text
1M true interacting agents
+
60+ complete frames/second
+
pure Bend simulation
+
pure Bend principal renderer
+
same algorithm runnable on CPU/GPU
```

is achieved on a high-end contemporary GPU.

Treat that as a performance research goal, not a number to fake.

---

# 64. Longer-term engine API

Only after the above works, consider layering an ECS-like facade over the dense architecture.

For example:

```bend
type World:
  ...

def Movement.system(...):
  ...

def World.query(~Position & Velocity, ~Movement.system):
  ...
```

but this facade must compile into:

```text
dense specialized transformations
```

rather than runtime archetype/query machinery wherever possible.

Potential future engine systems:

```text
Transform
Spatial
Collision
Physics
Particles
Animation
Rendering
Audio
Input
```

But the foundational API should remain:

```text
Parallel
Spatial
Render
```

---

# 65. Architectural thesis to preserve

Every implementation decision should be evaluated against this idea:

> Traditional engines organize around objects/entities and then figure out how to parallelize them.

This project should do the reverse:

> Organize the world around naturally parallel owned regions, then present entities as a convenient view of that data.

If the final architecture looks like Bevy/Flecs rewritten in Bend, reconsider it.

---

# 66. Final design criterion

A game developer using the finished engine should be able to think:

```text
WHAT happens to each part of my world?
```

not:

```text
Which GPU thread owns this?
Which buffer lives on the device?
Which kernel launches here?
Where is the synchronization barrier?
Which mutex protects this?
How do I upload this data?
```

The engine and Bend runtime should answer those questions automatically.

That is the core product.

---

# Start here

Perform Phase 0 first.

Then create the smallest program that proves this pipeline:

```text
100k positions
      ↓
GPU parallel update
      ↓
tile rendering
      ↓
native Bend window
```

Measure it.

Only after that works add the naive boids reference, spatial grid and neighbor interactions.

Do not spend the first week designing abstractions.

Get a measured GPU frame on screen as early as possible, then let the measurements determine the architecture.