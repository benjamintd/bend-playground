# TURN / engine interface

The current cleanup shares triangle ownership without changing TURN's puzzle
projection or visual rules. The game uses the existing mesh rasterizer, coverage
kernels and tile scheduler. It does not implement a second rasterizer.

## Current contract

| Responsibility | Owner |
| --- | --- |
| Triangle allocation, count, capacity, growth and reuse | `engine/render/batch.bend` |
| Screen bins, depth resolution, pixel buffers and coverage kernels | Engine mesh, coverage and tiles modules |
| World geometry, HUD layout, outline font shapes and font metrics | TURN view and generated font |
| Selecting text tiles for four-sample coverage | TURN `text-coverage.bend` |
| Camera rotation, framing and synthetic depth convention | TURN `projection.bend` |
| Simulation, collisions, chapter progression, time scale and bindings | TURN |
| Event-only polling, focus/visibility notifications and generic frame cadence | Engine platform modules |
| Pause behavior, held-key reset and static/30/60 Hz choices | TURN schedule |

`View.scene(play, batch)` clears the previous frame and returns an engine
`Batch`. Shape helpers and `Font.text` append directly to that same owner.
`Font.text` never clears preceding world or HUD geometry. `View.scenery` is an
independent scene constructor and also clears its supplied batch.
The initial reserve remains 32,768 triangles. `Batch.push` grows before an array
write can wrap, and the renderer returns the resulting count and capacity
alongside storage for reuse on the next frame. The old game `Geometry` record,
font `(array, count)` tuple, lettering adapters and two unchecked append
implementations are gone. Regenerate font code through `assets/generate-font.py`.

`Render.frame(gpu, play, renderer, old_image)` consumes and returns the owned
renderer/image pair. It preserves the engine bin-index metadata across the
raster pass. The native game selects CPU rendering, at 1024² with a 760-point
window; `Viewport.resolution` keeps presentation and framebuffer sizes coherent.

The [event-driven window contract](../../docs/WINDOW_LOOP.md) lets TURN wait
without rendering or presenting. `schedule.bend` chooses static menus and frozen view selection, 30 Hz
decoration and 60 Hz active play. Camera turns keep animating while the world
clock is frozen; a half-second resume curve retains the fixed physics step. Losing focus or visibility freezes game time
and clears held controls. The engine supplies activity changes, input wakeup
and pure frame-cadence decisions; puzzle-specific suspension stays in TURN.

## Why the specialized renderer remains

`engine/render/scene.bend` now owns resolution and actual backend selection for
the camera demos. TURN needs a procedural gradient backdrop, selective text
coverage and its existing synthetic depth encoding. Substituting `Scene.draw`
would change those behaviors. Adding callbacks or a general render graph to
cover one custom renderer would increase the interface and implementation.
The current 28-line TURN adapter is the smaller integration.

The same applies to cameras: TURN's XY/YZ/ZX cycle uses a fixed-world rotation
and `900 / (30 + z)` depth. Projection and depth migration must happen together;
simply replacing coordinate projection with the shared orthographic camera
would break depth agreement between faces and painted sub-quads. Collision
projection and intersection settling remain puzzle rules regardless of the
rendering camera.

There is no new input framework, overlay system, text atlas, material system,
audio API or packaging in this cleanup. Revisit an abstraction when another
caller needs the same behavior and it can remove real duplication. In
particular, moving the existing text-tile selector into the engine unchanged
would relocate code without simplifying it.

## Regression gates

- Engine batch tests cover capacity rounding, several growth steps, retention
  of every triangle, clear and reuse.
- TURN visual tests cover all 806 decorated scenes plus game/menu frames grown
  from one triangle; those must exactly equal preallocated geometry.
- Font tests compare covered and ordinary tiles with independent raster oracles.
- Projection tests cover full unit faces, 390 camera poses and three-turn cycles.
- Native tests compare persistent buffers grown from one triangle with a fresh
  renderer; saved menu, world and rotation images check the migration pixelwise.
- Before/after native timings track the cost of the shared batch. Frame-time
  evidence and source hashes are recorded in `results/api-cleanup-validation.json`.

## Fixed-world rendering contract

The previous game renderer selected a 100-cell slice using the character's
hidden coordinate, and added the next slice during rotation. That made blocks
appear or disappear after movement between turns even though the voxel layout
was unchanged. This was a game scene-selection bug, not evidence of a broken
shared mesh rasterizer. `world.bend` now enumerates all 1,000 fixed voxel IDs;
`projection.bend` applies a canonical camera to those coordinates each frame.
There is no accumulated vertex rotation and no player input to scenery selection.
Only internal faces and faces pointing away from the camera are culled.

Keep this boundary in a future camera API: world transforms belong to objects,
view transforms belong to the camera, and movement planes belong to the game.
The renderer must never infer world membership from the camera or player.
The new three-turn regressions deliberately move the character between turns;
a transform-only test was insufficient to catch the old selection bug.

## Campaign pass

The first campaign pass introduced 18 chapters, optional seals, turn targets,
a paused chapter picker and completion marks. The current 26-chapter campaign
uses projected contact for both seals and the exit. The exit responds when the character touches the
center of (9,9) in the current plane regardless of depth. These are game rules and presentation;
none requires a new shared engine abstraction. All 26 rebuilt chapters have
native input replays that collect every optional seal while meeting the turn target.

The earlier 18-chapter picker peaked at 17,360 triangles because each font pixel
was a quad. This motivated the priority of a small atlas-backed text/overlay API.
The 3D seal markers and player locator would also benefit from explicit overlay
layers, without adding collectible or puzzle concepts to the renderer.

## The Turning Rooms

The eight new rooms bring the campaign to 26. Fixed violet turn rings add a
game rule without an engine API: entry is a body-in-cell check, the ring holds
the body during rotation, and the existing mesh API draws three intersecting
circles at the ring's immutable world position. The first 18 levels retain
free rotation. Chapter selection now uses two pages; only the visible page is
built. Before the font polish, the scene-capacity test peaked at
17,636 / 32,768 triangles.

This does not change the proposed engine priorities: small text/overlay
support, explicit layer ordering, and simple materials remain sufficient.
Level rules, ring activation, reachability proofs, routing targets and hints
belong in the game. No engine-level puzzle, ring, door or campaign API is needed.

The native replay harness hit an Apple clang 17 backend failure while compiling
a constant `P.steps(120n,p)` after an IO check. The emitted continuation contained
120 expanded simulation calls across 10,745 C lines; clang failed during its
prologue/epilogue pass. The harness now receives the completion duration and
recorded inputs at runtime, retaining the same 120-tick assertion without that
expansion. Both native checks compile with the normal pinned launcher and its
unchanged optimization flags. The toolchain and engine were not patched.

## Font polish and restart discoverability

The game now uses a Rubik-derived outline subset, proportionally measured
labels, larger instructions and an explicit Backspace / Delete restart label.
The baked font is ordinary mesh geometry at the game's text depth of 1.
`text-coverage.bend` checks each tile's existing candidate list, choosing the
engine's four-sample coverage path only where a letter occurs. It uses the
same disjoint tile scheduler, buffers and rasterizers; no shared engine API
or unsafe primitive was added. The latest 806 scenes fit the existing triangle
buffer, peaking at 21,383 / 32,768 after the projected-collision campaign rebuild. Counters and curves are triangulated offline;
the game never parses a font or invokes a foreign renderer.

This improves the shipped game while keeping the atlas/overlay proposal small:
one measured text draw should eventually replace this game-side geometry and
coverage selection. The sample font's OFL license is bundled in the native app.

Four alternating before/after native runs measured median rendering time of
7.25 ms before and 9.97 ms after this polish (25 rotation frames per run,
8 CPU threads, GPU off). This is an added rendering cost, not a speedup or an
end-to-end frame-rate claim; window presentation, simulation and pacing are
excluded, and the engine task was active in the shared workspace. Raw samples
are in `results/turn-font-performance.json`. Rendering the entire scene with
four-sample coverage was more expensive, so only text tiles use it here.
