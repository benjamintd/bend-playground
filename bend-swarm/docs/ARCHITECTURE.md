# Architecture

The unit of work is an **owned parallel region**, not an entity. A boid is an index across dense numeric buffers. CPU and GPU invoke the same Bend definitions; only the root bang differs.

## Swarm executable

World has active_count, power-of-two capacity and four F32 arrays (x, y, vx, vy). Color derives from index. Seed 42 and independent hash streams initialize the state. Two worlds are allocated once. Every flocking step reads old state and writes separate next state, then moves the handles; there is no world clone or per-agent allocation. Initialization and movement use scalar hot parameters.

The first spatial backend is a 128×128 periodic grid over a 1024² world, with cell size and interaction radius 8. Histogram → exclusive scan → atomic cursor scatter produces contiguous ranges of agent IDs. The sentinel offset is stored at index 16384 in a 32768-slot array, avoiding Bend's wrapped array indexing. Histogram counts are reset during the scan. Scatter order is intentionally unspecified.

Histogram and scatter share one interval traversal specialized with a closed
point operation. Each active ID still performs one position read and one
atomic increment; scatter uses the returned cursor to own a unique ID slot.
The depth clamp, empty/odd active counts, separate stage entry points and scan
remain unchanged. There is no runtime callback or added shared configuration.

A task walks nine cells for each output agent. Squared distances reject candidates; accepted neighbors contribute separation, alignment and cohesion. The minimal-image displacement handles the torus seam. Steering acceleration is capped at 80; after integration, propulsion clamps speed to 20–60 world units/s while retaining heading. Near-zero velocity (magnitude ≤ 1e-6) uses a deterministic +X heading. The speed floor is a separate propulsion constraint, so it can change velocity faster than the steering acceleration cap. Fixed simulation dt is 1/60 s. This fixed dt means simulation slows with low frame rate; it is not a wall-clock accumulator yet. Mouse force is bounded by the same acceleration cap. All accepted neighbors participate; no caps, sampling or decorative agents.

The reference uses identical forces/integration but enumerates every agent. An independent JavaScript equation implementation checks it. Dense clustered fixtures also check optimized neighborhoods, periodic boundaries, CPU and Metal outputs.

## Rendering

The updated positions are re-binned so the image represents the new frame. Each 8×8 tile owns its pixels and reads only its packed candidate range. Overlapping points use a deterministic maximum color, independent of atomic scatter order. A quadtree of 4^7 tile tasks fills Bend's 16384-lane cube. Pixel blocks are statically unrolled; no per-pixel forks or scene lists. Previous images are reclaimed down the same tree. The principal renderer is Bend.

The native loop uses existing Window effects because App.run frees the image in a separate GPU launch. The window presents a pure Image. A small Bend bitmap HUD is composed on the host, outside benchmark timing. G switches all main stages between CPU and GPU; SPACE pauses, R resets, [ and ] change count, H toggles HUD, left/right mouse attracts/repels. The current native HUD is regenerated each frame; a safe cache/4 Hz refresh is still an optimization opportunity.

## Unsafe boundary

`engine/parallel/regions.bend` shares an internal state down a balanced tree.
`engine/render/tiles.bend` does the same for square pixel regions. These are
the engine's only two unsafe definitions. Both accept statically supplied
leaves/joins. Every leaf must write a disjoint region, or use array atomics.
Every join rejoins aliases of exactly the same allocation. No input to
neighbor lookup may be concurrently written. These obligations are documented,
runtime-tested contracts, **not proven by Bend's type checker**. The public
Spatial API exposes these callback contracts explicitly; see
[SPATIAL_API.md](SPATIAL_API.md).

Atomic overlap is limited to histogram increments and scatter cursors. A returned cursor uniquely grants one ID slot. Boids inner loops contain no atomics. Tile rendering shares read-only arrays and disjoint pixel ranges. No handle survives beyond its fork/join tree.

## Costs and limitations

Bend scalar array cells use 8-byte runtime words. Double-buffered x/y/vx/vy = approximately 64 bytes per capacity slot; sorted IDs add 8 bytes/slot. Grid counts/offsets/cursors add 512 KiB. The 1024² pixel buffer adds 8 MiB. Images, scheduling metadata and runtime allocator overhead are additional; the runtime defaults to a 2 GiB Metal heap. These are payload estimates, not measured peak heap use.

The grid is built twice per step (old-state neighbors and updated-state rendering). The second build can potentially seed the next step. The scan is a safe sequential native loop (~tens of microseconds for 16384 cells); parallel scan is not yet justified by a measured win. Shared-array neighbor reads are the first working architecture, not a completed comparison against cell-owned and halo variants.

Current proofs cover buffer swap involution, partition reassembly and positive/doubling capacity. They do not certify floating-point dynamics, unsafe races, scatter permutation or grid bounds; those have numerical/property tests instead.

## Generic spatial API and cloth

`engine/spatial.bend` exposes typed layouts, reusable indices, source-owning snapshots and template-specialized neighbor folds. See [SPATIAL_API.md](SPATIAL_API.md) for the complete ownership/error contract. The former grid module delegates construction to the generic backend. Swarm and cloth use the same stencil with independent sample, accumulator and output types.

Cloth has 32×32 vertices, three persistent x/y/z buffer sets, one reusable flat
surface-sample buffer, and two diagonal pinned corners. Fixed 1/120-second steps
use damped Verlet integration and twelve Jacobi passes over structural, shear
and bending constraints. A compliant mouse spring is applied during prediction;
constraint relaxation is allowed to move the grabbed vertex. Prediction limits
motion to 2 cm per step. An elapsed-time accumulator decouples physics from the
60 Hz presentation cap. Catch-up is capped at two fixed substeps per displayed
frame; excess wall time is dropped after a stall to avoid a workload spiral.

The generic 3D stencil reads cached current/previous positions of six incident
edges and two outgoing triangles per vertex. It applies two-sided vertex/face
and edge/edge repulsion with 18 mm thickness, excluding the connected one-ring.
Previous separation supplies the contact side; finite triangle/segment tests
replace the old vertex-only radius test. AABB rejection avoids expensive contact
math for separated features. These are discrete, approximate contacts, not a
continuous-collision guarantee. Broad-phase reach is based on the regular mesh
spacing and intended bounded stretch; arbitrarily stretched meshes require a
primitive-bounds index. No per-vertex allocation or array clone occurs in a step.

CPU uses one solver region, 64 contact regions, serial projection/binning and
8×8 raster work units. Metal retains the same math with parallel solver roots
and 4×4 raster work units (16,384 leaves). The demo selects CPU initially because
this small cloth workload is faster there on the measured M2 Pro. Backend changes
remain explicit and visible; no CPU work is labeled as Metal simulation.

Standard quality projects 1,922 triangles into a 512² framebuffer, bins screen bounds
into 4×4 cells, and resolves perspective-correct depth. Central-difference vertex
normals and interpolated lighting remove flat triangle shading. CPU work units
combine four adjacent bins. The analytic sphere/floor background supplies camera
depth. Flat triangle records occupy packed arrays; bin storage grows as needed.
The old Image is reclaimed through the same tile tree. A 1024² window scales the
framebuffer; the Bend HUD is separate. Near-plane-crossing triangles are rejected;
the fixed camera keeps the normal demo volume in view.

High quality keeps the same 32×32 physical grid and derives a 64×64 visual grid
using `engine/geometry/grid_surface.bend`. This callback-specialized Catmull–Rom
sampler reads a bounded 4×4 neighborhood and returns analytic derivatives for
smooth normals. `engine/core/vec3.bend` supplies shared scalar vector operations.
The visual points are projected onto the cloth obstacles before rendering.
This is visual tessellation, not a claim of finer physical folds or collision
resolution. High quality draws 7,938 triangles at 1024² with 8×8 bins and 16×16
CPU work units. Both modes retain 128² bins and 4,096 CPU raster leaves.

Projected high-quality vertices are cached in triangle slots 8192–12287;
assembly writes only slots 0–7937. The 16,384-element buffer therefore keeps
source and destination disjoint through the entire fork/join tree. No extra
per-frame vertex allocation occurs. Q replaces the rendering buffers while
preserving the scene, pause state and grab; it never selects a 64×64 physics workload.

Mouse presses are resolved at their position in the event sequence, before a
later move in the same batch can change the pick location. The tiny host-only
viewport effect queries actual logical window dimensions, because macOS can
constrain a requested window to the available display. Bend performs coordinate
conversion, picking, simulation, interpolation and rendering. The host effect
contains no simulation or rendering computation.


The mesh renderer retains a persistent `Array<Fragment>` backdrop alongside
pixels. `Mesh.backdrop` fills color and camera depth once using a caller-supplied
Bend callback; the caller must refill it when the camera or static scene changes.
Raster workers read the first half and exclusively write resolved color/depth
to the second half. This removes repeated analytic sphere/floor calculations
without weakening occlusion and makes current depth available to effects.
At 2048² the two-word Fragment buffer costs 128 MiB for both halves.
At 1024² it costs 32 MiB; at 512² it
costs 8 MiB. The static-backdrop-only version used half this payload.
Pixels, Image nodes and runtime overhead are additional. This is a payload
estimate, not measured peak heap use.

## Shared demo and rendering components

`engine/render/image.bend` assembles pixel buffers into Images with one family
of statically unrolled 2×2 through 32×32 blocks. Width and child operations are
template arguments, so this consolidation introduces no runtime callback or
per-pixel recursive scheduler.

`engine/render/tiles.bend` owns the quadtree scheduling shared by particles,
meshes, sprites, postprocessing and image resolve. Callers supply a closed leaf
and merge operation, tile size, backend and depth. Tile size and operations
are specialized before execution. CPU/GPU dispatch stays explicit in each
renderer; an additional generic dispatch wrapper failed on the pinned Metal
runtime (see [the reproduction](../repros/tiles-indirect-dispatch.md)).
The render state is shared, but the four
Image children remain separate affine values: resolve reads them, whereas
other passes reclaim their previous frame. A compressed `Pix` expands into
four same-color children without losing its source value. Particle/sprite
passes retain depth seven on both backends; mesh/post/resolve use depth six
with larger CPU leaves and depth seven on Metal.

`engine/platform/player.bend` owns native presentation, normalized pointer input,
presets, pause/reset, backend selection, HUD and pacing for the meadow and
Particle Life. The caller supplies state creation and a frame callback. State
is affine and persists across frames. Each displayed frame advances one fixed
1/60-second step; below 60 FPS simulation time slows. Cloth retains its separate
bounded elapsed-time accumulator because its solver requires substeps.

`engine/render/camera.bend` provides perspective projection and matching camera
rays. `engine/geometry/curve.bend` provides quadratic curves and tangents.
`engine/fields/wind.bend` samples coherent traveling gusts. The meadow stores
four floats per blade, updates independent bounded springs, and emits six
ribbon triangles plus two optional flower triangles per blade. Root phase is
wrapped with integer arithmetic before float conversion to avoid CPU/Metal
large-angle rounding differences. Wind and pointer forces do not move roots.

Particle Life has two persistent flat particle arrays and two reusable indices:
a simulation grid with 32-world-unit cells and a screen index with 8-world-unit
cells. At 2048² the screen index is unchanged; output tiles and sprite radii double. Six species
select an attraction coefficient; a short-range repulsion core prevents collapse.
The generic stencil sums every neighbor inside the radius. Screen rebuilding
uses updated positions. No per-particle allocations occur in either demo.

The shared mesh finish pass and periodic sprite renderer are documented in
[RENDERING.md](RENDERING.md). Effects run in Bend on either backend. Their
immutable source and disjoint output ownership are runtime-tested contracts,
with unsafe sharing confined to the engine's region/tile trees.

The new world-space interface in `engine/camera.bend` prepares perspective or
orthographic views for projection, normalized picking rays and conservative
visibility tests. Pure orbit/fly controls are separate from event bindings.
`engine/render/project.bend` clips world triangles before projection into
`engine/render/batch.bend`, the same growable triangle owner used directly by
TURN's world geometry and font. `engine/render/scene.bend` owns frame buffers,
resolution dispatch, actual backend selection and stage timing. The target's
stored level is the sole resolution input at draw time.
Mesh entry points statically select camera interpolation or the existing legacy
equations, so existing demos avoid extra camera work inside their pixel loops.
The old render camera adapter remains compatible. See [CAMERA_API.md](CAMERA_API.md).

`engine/voxel/world.bend` owns bounded occupancy and nearest-hit grid traversal.
The voxel demo owns terrain generation, edit semantics and sixteen cached chunk
meshes. An edit rebuilds only affected chunks; camera movement projects the
cached world-space faces. Platform input capture, reusable controls and game
bindings are separate responsibilities; native wheel/pinch/focus capture is
the next platform extension.
