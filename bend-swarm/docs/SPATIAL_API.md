# Spatial API

`engine/spatial.bend` is the application-facing API. Both the swarm and cloth
use it. The implementation is a reusable atomic histogram, exclusive scan and
scatter index plus a template-specialized neighborhood fold. Application
callbacks know nothing about cell offsets or the chosen index representation.

## Lifecycle

1. Choose a constant `Layout` and allocate `Spatial.create(~space, capacity_bits)`.
2. `Spatial.build` consumes the index and the source, returning a `Snapshot`.
3. `Spatial.stencil` reads that snapshot, folds each point's neighbors, and writes
   a separate output. It returns a `Step` with the unchanged snapshot, output,
   candidate count and accepted-neighbor count.
4. `Spatial.unpack` retains the snapshot for another query. `Spatial.release`
   returns source, output, reusable index and statistics. Swap the application
   buffers and rebuild before querying changed positions.
5. `Spatial.recycle` releases a snapshot without a query.

The layout is an erased parameter of `Index`, `Snapshot` and `Step`, so a
well-typed caller cannot silently query an index with a different layout.
Source ownership moves into the snapshot: normal affine code cannot mutate it
while the index exists. Callbacks must also honor the read-only contract below.

All allocation/build/query operations return `Result<String,T>`. Optional
`Spatial.require(~T,result)` turns an error into an application-level IO exit.
**A failed operation consumes its arguments**, consistent with Bend's affine
ownership. Validate user settings before moving live state into a call if the
application needs to preserve that state after an error.

## Layout and query semantics

Import `engine/spatial/layout.bend` for the value constructors:

```bend
# 32 x 32 x 32 bounded cells, each 0.25 m wide; origin (-4,-2,-4).
def space() -> L.Layout:
  L.Layout{3,5n,5n,5n,0.25,F32.neg(4.0),F32.neg(2.0),F32.neg(4.0),False{}}
```

- Dimensions are 2 or 3. A 2D layout requires `z_bits = 0` and ignores point.z.
- Axis sizes are powers of two. The total cell depth and capacity depth are at
  most 20. Active count may be zero, odd, or less than allocated capacity.
- Cell size must be positive. Layout origins and cell size are restricted to
  finite magnitudes below 1e9. Query radius is finite, nonnegative and below 1e9.
- Bounded layouts clamp **cell addresses**, not positions. Points outside the
  domain still use ordinary Euclidean distances. Edge buckets can become
  crowded, but nearby points outside the domain are not omitted.
- Periodic layouts use each axis extent as its period and shortest wrapped
  displacement. Positions need not already be wrapped. At half a period the
  displacement chooses the negative direction.
- Membership is the open ball `distance_squared < radius * radius`. Radius
  zero has no members, even with `include_self = True`.
- Radii larger than a cell or the entire domain are supported. Each cell is
  visited at most once, including one-cell axes and tiny periodic domains.
- `include_self` controls equal IDs. Distinct coincident points are included.
- `Delta` contains neighbor-minus-self x/y/z and squared distance. All accepted
  neighbors are visited; there is no cap, truncation, or sampling.
- Atomic scatter order is unspecified. Floating-point reductions can differ
  slightly between runs/backends. Do not depend on neighbor visit order.
- `Statistics.candidates` includes rejected candidates and self checks.
  `Statistics.neighbors` counts accepted visits before application filtering.

Positions supplied by callbacks must be finite and on a numerically sensible
scale relative to cell size. The API does not scan arbitrary user state to
validate coordinates or backing-array lengths. Single-precision arithmetic
sets the accuracy limits; tiny separations at very large coordinates lose
precision.

## Callback contract

Source `S` and output `O` may be unrelated user-defined buffer types. Sample `T`,
accumulator `A` and uniform context `C` are `Data`. Use flat numeric records in
hot paths; allocating lists or trees in callbacks defeats the engine's layout.
Callbacks are closed `~` templates, specialized by the pinned Bend compiler:

| Callback | Responsibility |
|---|---|
| `position(+id, source) -> source & Point` | Build-time read-only position access |
| `read(+id, source) -> source & T` | Query-time read-only sample access |
| `point(T) -> Point` | Must return the same positions used by build |
| `begin(id, self, context) -> A` | Initialize one output point's accumulator |
| `visit(id, self, neighbor_id, neighbor, delta, context, acc) -> A` | Fold one accepted neighbor |
| `finish(id, self, context, acc, output) -> output` | Write only this ID's output slots |
| `join_source(a,b)` / `join_output(a,b)` | Rejoin aliases of the same original storage |

Backing arrays must have at least `active_count` slots. Source and output must
not alias. Reads must return the same source handles without changing values.
`finish` may not inspect output written by other IDs, perform overlapping writes,
or retain/escape handles. Joins must not join unrelated allocations.

These are trusted programming contracts, **not a proof of race freedom**.
`engine/parallel/regions.bend` is the documented unsafe sharing boundary;
only disjoint output regions and the index's atomic count/cursor operations
may be written concurrently. Generic callbacks have the same obligations as
other parallel engine primitives. Internal constructors are implementation
modules, not a supported way to manufacture snapshots.

## Cloth example

`demos/cloth/world.bend` supplies three persistent coordinate arrays and read,
write and alias-join operations. `demos/cloth/physics.bend` supplies a collision
accumulator and these callbacks:

```bend
def collide(gpu: Bool, depth: Nat, c: Controls,
  s: Spatial.Snapshot(space(),W.Positions), out: W.Positions)
  -> Result<String,Spatial.Step(space(),W.Positions,W.Positions)>:
  Spatial.stencil(~space(),~W.Positions,~W.Positions,~L.Point,~Correction,~Controls,
    ~W.read,~point,~begin,~collision,~collision_finish,~W.join,~W.join,
    gpu,depth,0.035,False{},c,s,out)
```

The simulation builds a snapshot after solving stretch constraints. The query
finds nearby vertices in 3D; the callback excludes connected mesh neighbors and
accumulates separation. The finish callback writes the next positions and
reapplies pins and obstacle contact. Releasing the step recovers the index for
the next substep. There is no per-vertex allocation or whole-world clone.

The swarm example uses the same API with 2D periodic distances, velocity samples,
and separation/alignment/cohesion accumulators. `engine/spatial/grid.bend` is a
compatibility adapter for particle-renderer bins and stage timings; its build
stages delegate to the same generic index. The old `Boids.execute` kernel remains
as a specialized reference for tests and historical comparisons, while the live
swarm uses `Boids.run` and `Spatial.stencil`.

## Execution and validation

`gpu` selects a bang at each parallel root. `depth` controls region subdivision
and is clamped to the active population; zero-count snapshots are valid. CPU
and GPU use identical callbacks and equations. The exclusive scan is currently
sequential and native. The backend and root depth are execution choices, not
spatial layout or simulation semantics.

`scripts/test` covers 120 independent all-pairs query cases, arbitrary radii,
2D/3D bounded and periodic domains, tiny axes, empty/partial populations,
input rejection, index permutations, source preservation and both boids kernels.
`scripts/test --native` also checks the compiled CPU and Metal query outputs,
boids crossings, cloth dynamics and triangle rendering.
