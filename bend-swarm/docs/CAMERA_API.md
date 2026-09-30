# Camera API and stress-test demos

Implemented with the pinned, working Metal toolchain (Bend 2.0.27).

## Run

Build both apps and the headless runner with `scripts/build-camera`.
Run `scripts/run-monochrome` or `scripts/run-voxels`, or open the corresponding
`build/Bend Monochrome.app` / `build/Bend Voxels.app` on macOS.

| Control | Action |
| --- | --- |
| O | Perspective / orthographic |
| F | Orbit / free flight, preserving the current eye and look direction |
| W / S | Dolly in orbit mode; forward / backward in flight mode |
| A / D | Pan / strafe |
| E / C | Move up / down |
| I / J / K / L | Look up / left / down / right |
| Drag | Orbit/look in Monochrome; middle-button drag in Voxels |
| Left / right click | Carve a crater / add a voxel at the hit face |
| Space | Pause animation; camera controls remain active |
| Q | 1024 / 2048 framebuffer; world state is preserved |
| G | CPU / Metal rendering, with runtime CPU fallback |
| R / Escape | Reset / close |

The title reports actual projection, controls, resolution, execution backend,
triangle count, frame stage times and rebuilt chunks. Stage times are elapsed
host time including dispatch/synchronization, not GPU timestamps or total FPS.
The content has no text overlay; Monochrome uses exactly black/white pixels.

## Shared interface

The public modules are [camera](../engine/camera.bend) and
[camera controls](../engine/camera_controls.bend). They borrow Three.js's
separation of [projection](https://threejs.org/docs/pages/PerspectiveCamera.html),
[controls](https://threejs.org/docs/pages/OrbitControls.html), and
[picking rays](https://threejs.org/docs/pages/Raycaster.html), using Bend records
and pure functions.

- `Camera`: lens, eye/target/up, zoom and principal-point offsets.
- `Viewport`: logical content rectangle and framebuffer dimensions.
- `View`: prepared basis, lens and projection constants, shared by geometry,
  picking and visibility checks. It stays on the CPU and never enters a GPU
  vertex/pixel loop.
- `Ray`: origin, unit direction, minimum/maximum distance in world units.

Use `perspective(fov, near, far)` or `orthographic(span, near, far)`, then
`look_at`, `zoom` and `offset` to set the camera. `prepare(camera, viewport)`
returns `Maybe<View>`: invalid lenses, zero dimensions, coincident eye/target,
non-finite poses and zero up vectors return `None`. The derived projection scale
and viewport extents must also remain finite and invertible in F32. A forward
vector parallel to up selects a deterministic fallback basis.
`prepare_unchecked` is an explicitly unchecked internal fast path for callers
that already enforce the same invariants. Application code should use `prepare`.
Both `prepare` and `pointer` reject invalid logical or framebuffer dimensions.

FOV is vertical, in degrees, strictly between 0.1 and 179. Near must be at least
0.0001, far must exceed near and be at most 100,000. Orthographic span is positive
and greater than 0.0001; zoom is between 0.0001 and 10,000, exclusive. Positions
use F32, so nearby coordinates at very large world origins still lose precision.
Principal-point offsets are fractions of framebuffer width/height.

`project(view, point)` returns screen X/Y, positive view depth and a visible
flag. `unproject_at_depth` takes view depth, not distance along a ray.
`screen_ray` takes framebuffer coordinates; `pointer(viewport, x, y)` converts
logical window coordinates and rejects points outside the content rectangle.
`intersects_bounds` conservatively tests an AABB's bounding sphere against all
six planes: it may retain an invisible chunk but never deliberately rejects a
partially visible one.

World up is +Y; framebuffer origin is top-left and Y grows down. Perspective
rays originate at the eye. Orthographic ray origins vary across the camera
plane and directions are parallel. Ray distance limits correctly account for
the difference between view-plane depth and distance along the ray.

Orbit and fly controls accept rates and elapsed time in seconds; their angles
are radians. The demo converts drag displacement into a single control update
and uses elapsed time for held keys. Camera motion is separate from world time.

## Renderer integration

[Project](../engine/render/project.bend) accepts world triangles, transforms
vertices into view space, clips against all six planes before division, and
triangulates the result into a reusable growing batch. Fully visible triangles
avoid polygon clipping allocations. Attributes are interpolated at clipped
edges.

[Batch](../engine/render/batch.bend) owns screen-triangle storage independently
of camera projection. Its supported interface is `create(capacity)`, `clear(batch)`
and `push(triangle, batch)`. Creation clamps the initial request to 1..2^30 and
rounds up to a power of two; choose a realistic reserve for available memory.
Append doubles storage when full, preserving order and existing triangles.
`clear` resets the count and retains storage. Only the prefix `[0, count)` is
live. Use these functions rather than fabricating inconsistent count/capacity
records. The low-level renderer consumes and returns the same owned storage.
Turn's world geometry and outline font use this batch directly, while camera
demos append through `Project.triangle` / `Project.triangles`.

[Scene](../engine/render/scene.bend) owns reusable pixel, depth and triangle-index
buffers at 512/1024/2048. It profiles binning and raster stages with an IO boundary
before GPU dispatch. The demos use CPU geometry/binning and selectable CPU/Metal
rasterization. Call `create(level, background)`, optionally `resize(level, target)`,
then `draw(request_gpu, simulation_us, geometry_us, batch, target, old_image)`.
Levels 0/1/2 select 512/1024/2048; larger levels clamp to 2. The target is the
sole resolution source: `draw` cannot dispatch a different size than its buffers.
It resolves actual Metal availability and reports the selected backend. The
returned `Frame` owns the next target, batch and image plus timing data; thread
those values into the following frame. Unchanged size preserves all buffers;
a resize retains the reusable bin index and recreates pixels/background.
A constant backdrop can be cached across camera motion; callers
using a world-space backdrop must regenerate it when the view changes.

Camera triangles use RGB's unused high bits internally: bit 25 marks clipped
geometry and bit 24 selects orthographic depth. Perspective depth and attributes
are perspective-correct; orthographic depth is affine. Difference-form lighting
preserves constant colors exactly, including white. `Mesh.sample_camera` and
`Mesh.render_camera_level` consume these batches. Legacy entry points remain
statically specialized to their original equations, avoiding camera-mode work
in existing demos' pixel loops.

The existing `engine/render/camera.bend` adapter remains compatible: its rays
are unnormalized and its `along` argument is view depth. Cloth, Meadow and Turn
retain their existing framing/picking conventions; this change does not silently
normalize those rays or replace Turn's synthetic depth encoding. Rectangular
camera math is supported; mesh framebuffer storage remains square.

The supported application surface is documented here; allocation, clipping,
validation and dispatch helpers in these modules are implementation details.
Bend currently exposes definitions without a separate private visibility marker.
During this cleanup `Project.Batch/empty/clear` moved to `Batch.Batch/create/clear`,
`prepared` became `prepare_unchecked`, and the redundant level argument was
removed from `Scene.draw`. All repository callers have migrated.

## Demos and limits

Monochrome animates a twisting stack, orbiting cubes and a checkerboard floor.
Solid white/black faces use unit light and no grayscale antialiasing or defocus.
A small host presentation adapter selects nearest filtering on macOS; all
geometry and pixel generation remain in Bend.

Voxels is a bounded 32x16x32 landscape with caves, stored as host-owned occupancy.
The engine voxel module implements bounded read/write and nearest-hit grid
traversal. Its `create` returns `Maybe<World>` and rejects zero/oversized dimensions
(each axis at most 1024, at most 16,777,216 cells), before allocating storage. Sixteen 8x16x8 chunk meshes cache exposed faces. A local edit invalidates
its chunk and neighbors whose shared faces may change. Camera motion projects
cached faces and rejects definitely invisible chunks; it does not remesh them.
This is not an infinite streamed world, a greedy mesher, or a voxel physics demo.
Edits are session-local and R regenerates the terrain.

## Input ownership and next extension

The engine should own platform input normalization and reusable camera controls;
games should choose bindings and whether an interface consumes an action.
Bend's current native `Event` exposes keys, mouse buttons and motion, but no wheel,
scroll phase, pinch, focus-loss or touch events. These demos therefore use the
keyboard/drag controls above; scroll and touchpad gestures are not implemented.

The engine now supplies event-only polling plus focus and visibility metadata
through [Events and Cadence](WINDOW_LOOP.md). TURN uses them to sleep without
presenting and to clear held keys after interruption. Camera demos still use
their existing loop; the gesture API below remains a separate future extension.

The next input adapter should preserve precise deltas, gesture phases, momentum,
logical coordinates and focus changes. Interpret pinch as zoom and two-finger
scroll as pan, with configurable mouse-wheel zoom. Consume displacement events
once rather than multiplying them by frame time; integrate held controls using
dt. Clear held inputs on focus loss. Picking rays supply cursor-anchored zoom.
Record the normalized event stream for deterministic gesture regression tests.
No Bend compiler patch is needed: host code captures events, Bend interprets them.

Keep three boundaries explicit:

1. A per-window platform adapter emits ordered events with timestamps, logical
   positions, modifiers, scroll units/phases and pinch scale. Preserve fractional
   deltas and native momentum; do not synthesize another inertia layer over it.
2. Reusable input state tracks held/pressed/released controls, focus and pointer
   capture. UI gets first opportunity to consume events; an active drag retains
   capture until release or cancellation, even outside the viewport.
3. Configurable bindings turn remaining events into orbit, pan and zoom actions.
   Controllers update a Camera. Games choose bindings, speed limits and actions
   such as voxel carving; the Camera itself has no OS or key-binding dependency.

Start with one adapter and one orbit controller shared by both demos, rather
than introducing a global event bus. Cursor-anchored zoom uses a scene hit, or
a stable target plane when the pointer is over empty space. Test a recorded
gesture at different frame rates, viewport sizes and framebuffer resolutions,
plus focus loss and UI consumption.

## Validation and profiling

`scripts/test` includes camera round trips, degenerate poses, clipping, depth and
lighting interpolation, binary colors, batch growth/reuse, voxel DDA against an
independent nearest-box oracle, chunk boundaries and input/resolution behavior.
`tests/camera-native-check.py` compares full CPU/Metal framebuffers and verifies
strict colors at multiple resolutions. See `results/camera-native-validation.json`
and `results/camera-validation.json` for the completed native checks and captures.
The native suite also runs the real Meadow workload; small fixtures alone missed
the [rejected sampler closure selector](../repros/camera-closure-selector.md).

The headless runner records a deterministic moving-camera path; the voxel
benchmark carves a chunk boundary after warmup and records remeshing separately:

```sh
./build/camera --gpu on --threads 10 -- bench voxel perspective 1024 30 120
./build/camera --gpu off --threads 10 -- snapshot mono ortho 512 0 80
```

Benchmark arguments are mode, scene (`mono`/`voxel`), projection, resolution,
warmup count and sample count (or animation tick for `snapshot`). Snapshot output
is a P3 framebuffer. Performance results are measurements on the current desktop,
not a portable frame-rate guarantee.
