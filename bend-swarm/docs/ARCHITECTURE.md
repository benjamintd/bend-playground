# Architecture

The unit of work is an **owned parallel region**, not an entity. A boid is an index across dense numeric buffers. CPU and GPU invoke the same Bend definitions; only the root bang differs.

## Current executable

World has active_count, power-of-two capacity and four F32 arrays (x, y, vx, vy). Color derives from index. Seed 42 and independent hash streams initialize the state. Two worlds are allocated once. Every flocking step reads old state and writes separate next state, then moves the handles; there is no world clone or per-agent allocation. Initialization and movement use scalar hot parameters.

The first spatial backend is a 128×128 periodic grid over a 1024² world, with cell size and interaction radius 8. Histogram → exclusive scan → atomic cursor scatter produces contiguous ranges of agent IDs. The sentinel offset is stored at index 16384 in a 32768-slot array, avoiding Bend's wrapped array indexing. Histogram counts are reset during the scan. Scatter order is intentionally unspecified.

A task walks nine cells for each output agent. Squared distances reject candidates; accepted neighbors contribute separation, alignment and cohesion. The minimal-image displacement handles the torus seam. Steering acceleration is capped at 80; after integration, propulsion clamps speed to 20–60 world units/s while retaining heading. Near-zero velocity (magnitude ≤ 1e-6) uses a deterministic +X heading. The speed floor is a separate propulsion constraint, so it can change velocity faster than the steering acceleration cap. Fixed simulation dt is 1/60 s. This fixed dt means simulation slows with low frame rate; it is not a wall-clock accumulator yet. Mouse force is bounded by the same acceleration cap. All accepted neighbors participate; no caps, sampling or decorative agents.

The reference uses identical forces/integration but enumerates every agent. An independent JavaScript equation implementation checks it. Dense clustered fixtures also check optimized neighborhoods, periodic boundaries, CPU and Metal outputs.

## Rendering

The updated positions are re-binned so the image represents the new frame. Each 8×8 tile owns its pixels and reads only its packed candidate range. Overlapping points use a deterministic maximum color, independent of atomic scatter order. A quadtree of 4^7 tile tasks fills Bend's 16384-lane cube. Pixel blocks are statically unrolled; no per-pixel forks or scene lists. Previous images are reclaimed down the same tree. The principal renderer is Bend.

The native loop uses existing Window effects because App.run frees the image in a separate GPU launch. The window presents a pure Image. A small Bend bitmap HUD is composed on the host, outside benchmark timing. G switches all main stages between CPU and GPU; SPACE pauses, R resets, [ and ] change count, H toggles HUD, left/right mouse attracts/repels. The current native HUD is regenerated each frame; a safe cache/4 Hz refresh is still an optimization opportunity.

## Unsafe boundary

`engine/parallel/regions.bend` shares an internal state down a balanced tree. It accepts only statically supplied leaves/joins. Every leaf must write a disjoint interval, or use array atomics. Every join rejoins aliases of exactly the same allocation. No input to neighbor lookup may be concurrently written. These obligations are documented, runtime-tested contracts, **not proven by Bend's type checker**. A project public API that accepts arbitrary callbacks is not finalized.

Atomic overlap is limited to histogram increments and scatter cursors. A returned cursor uniquely grants one ID slot. Boids inner loops contain no atomics. Tile rendering shares read-only arrays and disjoint pixel ranges. No handle survives beyond its fork/join tree.

## Costs and limitations

Bend scalar array cells use 8-byte runtime words. Double-buffered x/y/vx/vy = approximately 64 bytes per capacity slot; sorted IDs add 8 bytes/slot. Grid counts/offsets/cursors add 512 KiB. The 1024² pixel buffer adds 8 MiB. Images, scheduling metadata and runtime allocator overhead are additional; the runtime defaults to a 2 GiB Metal heap. These are payload estimates, not measured peak heap use.

The grid is built twice per step (old-state neighbors and updated-state rendering). The second build can potentially seed the next step. The scan is a safe sequential native loop (~tens of microseconds for 16384 cells); parallel scan is not yet justified by a measured win. Shared-array neighbor reads are the first working architecture, not a completed comparison against cell-owned and halo variants.

Current proofs cover buffer swap involution, partition reassembly and positive/doubling capacity. They do not certify floating-point dynamics, unsafe races, scatter permutation or grid bounds; those have numerical/property tests instead.
