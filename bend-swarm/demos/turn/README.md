# TURN

A native Bend puzzle game with 26 compact worlds. Each contains fixed, full
1×1×1 cubes in a 10×10×10 grid. Rotate **XY → YZ → ZX → XY** to change the
visible plane and gravity. The world geometry never depends on player depth.

**Every visible cube is solid in the current 2D projection, at every depth.**
You cannot walk in front of or behind a projected staircase. Covering the
center of the green door's projected (9,9) cell wins, regardless of depth.
Optional amber seals and turn targets never lock the door.

```sh
scripts/run-turn
```

Or build with `scripts/build-turn` and open `build/Bend Turn.app` on macOS.
Rendering, simulation, collisions and game rules execute in Bend. All puzzle
rules and authoring tools are game-local. World geometry and outline text use
the engine's shared growable triangle batch. The specialized projection and
text coverage adapter are documented in [ENGINE_NOTES.md](ENGINE_NOTES.md).

## Controls

- **A / D, Left / Right:** move. **Space / W / Up:** jump.
- **S / Down:** fast fall. **R:** rotate 120 degrees and freeze time.
  Press **R** again to choose another view; a fresh movement or jump press
  resumes time smoothly over half a second.
- **Backspace / Mac Delete:** restart this chapter, preserving completed
  chapter marks. It also cancels an unfinished turn or automatic settling.
- **Tab:** pause and choose a chapter. Arrows/WASD select, **Q / E** changes
  pages, **Enter / Space** plays, **Tab / Escape** returns. All chapters are
  available immediately; **1–9** are shortcuts to the first nine.
- Winning advances after one second. **N** advances immediately after victory
  or restarts the campaign after its final chapter. **Escape** quits in-game.

## Rotation and intersections

A turn freezes physics immediately and animates the camera for 0.7 seconds.
Time then stays frozen until a **fresh movement or jump key press**. Holding a
key from before the turn or operating-system key repeat does not release it.
Press R again to chain another turn at exactly the same 3D position, including
through an intersecting intermediate view. XY → YZ → ZX needs no intervening
fall. Each turn counts separately. A movement press during the animation queues
resumption for its end.

On release, time eases from zero to full speed over 0.5 seconds. The fixed
120 Hz collision steps retain their original size; only their frequency changes.
The HUD shows **TIME FROZEN** with a reminder, then **TIME RESUMING** with a
speed bar. World effects share the frozen/fading clock; the camera is independent.

A turn always completes when rotation is available. There is no “view blocked”
rule. Once time resumes, if the selected silhouette intersects the character:

1. The camera switch preserves the exact position.
2. The character turns mint and automatically falls through the intersecting
   column toward the first opening below. Steering and jump are suspended.
3. At the first position where the whole body is clear, ordinary gravity and
   solid collisions resume. The next platform catches the fall normally.
4. If there is no opening below before the world boundary, the character
   slides to the closest free cell instead—usually above a floor or beside a
   wall. This correction is animated, never a teleport.

The fallback minimizes Manhattan distance to free cell centers; equal-distance
choices prefer the higher row, then the rightmost column. Hidden depth is
preserved throughout settling. During the frozen view selection, R remains
available even inside a wall.
After time resumes, turns are unavailable until the body is clear. Seals and
victory cannot trigger while the character is inside a wall. The HUD reads **SETTLING VIEW**.

The last eight chapters add violet **turn rings**: the complete projected
body must fit inside a ring's cell before starting a turn chain. Depth does
not affect ring contact. The ring permits choosing any view while time remains
frozen; moving releases that permission. Intersecting views settle on resume.
The first 18 chapters allow turns anywhere.

## Rebuilt campaign

All layouts were rechecked against projected collisions and automatic
settling. These are sparse 8–21-cube worlds, progressing from ordinary steps
and gaps to shared supports, blocked exit approaches, return routes, deliberate
falls and ring transfers. No additional mechanics were introduced. Amber seals
use projected contact too; collecting all of them within par is an optional
challenge. Every chapter has a verified native input route doing both.

| Chapter | Name | Difficulty | Cubes | Rings | Turn target |
| --- | --- | --- | ---: | ---: | ---: |
| 01 | Paper Steps | Gentle | 9 | 0 | 0 |
| 02 | Distant Steps | Gentle | 9 | 0 | 0 |
| 03 | Missing Tooth | Gentle | 8 | 0 | 0 |
| 04 | Borrowed Height | Curious | 10 | 0 | 2 |
| 05 | Bent Ladder | Curious | 12 | 0 | 2 |
| 06 | Shared Support | Curious | 12 | 0 | 3 |
| 07 | Over The Wall | Curious | 12 | 0 | 2 |
| 08 | Second Thought | Curious | 17 | 0 | 3 |
| 09 | The Balcony | Curious | 12 | 0 | 3 |
| 10 | Return Path | Tricky | 12 | 0 | 4 |
| 11 | Low Ceiling | Tricky | 20 | 0 | 4 |
| 12 | Ribbon Walk | Tricky | 15 | 0 | 6 |
| 13 | Sideways Stair | Tricky | 21 | 0 | 4 |
| 14 | The Long Drop | Expert | 20 | 0 | 7 |
| 15 | Split Horizon | Expert | 18 | 0 | 6 |
| 16 | Switchback | Expert | 18 | 0 | 9 |
| 17 | Negative Space | Expert | 16 | 0 | 5 |
| 18 | Three Acts | Expert | 14 | 0 | 6 |
| 19 | First Station | Tricky | 18 | 3 | 3 |
| 20 | Transfer | Tricky | 13 | 3 | 3 |
| 21 | Hinge Point | Tricky | 21 | 3 | 3 |
| 22 | Detour | Expert | 21 | 4 | 5 |
| 23 | The Crossing | Master | 21 | 6 | 6 |
| 24 | Counterweight | Master | 17 | 4 | 5 |
| 25 | Afterimage | Master | 17 | 4 | 5 |
| 26 | Final Fold | Master | 12 | 5 | 5 |

Turn targets describe achievable all-seal routes, not continuous-physics
optimality. Some chapters have clever shorter exits. Falling away from a ring
can still strand a route; Backspace restarts the short room. See
[ROOM_DESIGN.md](ROOM_DESIGN.md) for the intended discoveries and measured
cell-space lower bounds.

`catalog.json` stores every block, seal and ring coordinate explicitly, with
order, titles, hints, difficulty and design provenance. It has no runtime
random generation. `scripts/generate-turn-levels.py` emits the pure Bend
catalog, immutable projection masks, cell-space escape destinations and
campaign law declarations. The escape table is checked against the continuous
resolver at every occupied projected cell center.

## Physics and presentation

The half-cell character uses 1/1024-cell precision at 120 Hz. Jumps are
parabolic, with exact face contacts, jump buffering and coyote time. Every
accepted movement—including settling—is guarded by a maximum displacement of
1/8 cell per axis and world bounds. Ordinary motion additionally requires a
clear projected box. Only the rotation resolver enables temporary overlap.

The 1024² scene uses fixed cube geometry, an animated portal, optional seals,
a character locator and a chapter picker. Proportional outline text is baked
from Rubik Bold (source and OFL license in `assets/`). Four-sample coverage is
limited to text tiles. The native 760-point window scales the image separately.
The game uses the engine's mesh, coverage, tile tree and event-driven window
primitives. [ENGINE_NOTES.md](ENGINE_NOTES.md) records that interface.

Losing focus, hiding or minimizing pauses simulation and rendering. Resuming
keeps progress and discards background elapsed time and held controls. The
chapter picker redraws only when changed; decoration runs at up to 30 Hz at
rest and active play at up to 60 Hz. Physics still uses its fixed 120 Hz step.

## Laws and verification

```sh
scripts/test-turn
```

The built-in Bend checker verifies 96 game and campaign laws:

- A constructive exit witness for each of the 26 chapters, checking every
  intermediate projected cell and world bound. Certificates list their next
  states explicitly; every link must equal the actual rule transition.
- For each chapter, resolution of every cell in all three projected views
  ends in free space. This is a finite cell-space totality proof.
- Frozen and turning clocks never issue a physics step, zero-time updates
  preserve the body, and the resume curve reaches full speed in 60 wall ticks.
- Projection round trips, three-turn plane cycles, immutable occupancy,
  depth-independent collisions and contacts, vertical and diagonal jumps,
  the exit-center rule, rotation without instantaneous displacement,
  downward and floor-edge resolution examples, and rejection by the movement
  limit guard.

The planning model treats rotation, releasing time and its automatic
correction as one abstract action. It remains a sufficient route model; frozen
chains add choices that this planner does not enumerate. It does not claim the intermediate embedded positions are
clear, or formally prove every continuous trajectory. Separate tests check:

- All cell transitions against an independent numerical oracle, including
  minimum-turn searches and routes with rotation or jumping disabled.
- 26 keyboard replays, using only real movement/jump/turn input and explicit
  resume presses; each wins,
  collects every seal, meets par, and matches the native executable exactly.
- Every occupied projected cell's continuous escape, bounded motion, unchanged
  hidden coordinate, finite settling and immediate collision restoration.
- Parabolic flight, walls/ceilings, two-cell gaps, 26,000 mixed-input ticks,
  projected contacts, progression, reset, key aliases, ring anchoring and menus.
- Full unit cube faces, fixed scenery after three camera turns with movement,
  390 camera poses, frozen/resuming scenes, font metrics/coverage and native reused buffers.

The optional separate Lean-kernel recheck requires Lean 4.34.0, which is not
installed here. The reported proofs are Bend checker results.

To regenerate authored witnesses:

```sh
python3 scripts/generate-turn-levels.py
bun --preload ./.toolchain/bend/bend2/main.ts tests/turn/solve.js --write
bun --preload ./.toolchain/bend/bend2/main.ts tests/turn/continuous.js --write
scripts/test-turn
```

`tests/turn/projected-plans.json` and its keyboard controller are validation
fixtures, never consulted by the live game. Reports are written to
`build/turn-solutions.json` and `build/turn-continuous-solutions.json`.
The projection and font timing reports in `results/` are preserved historical
measurements; they predate this collision and campaign revision.

## Hints and browser edition

Press **H** (or the web Hint button) for the next rotation on a verified winning
route. Each level has three hint uses. A blue outline marks the exact projected
player-center position; **JUMP / R** means turn while airborne. Re-reading the
same marker costs nothing. Starting a new chapter restores three uses; restarting
keeps the current hint and budget. Asking during a camera turn does nothing.

Hints are route guidance, not a live solver for every possible detour. A previous
turn may change the hidden coordinate and make that route unavailable; in that
case the game asks you to restart and does not spend a hint. Requests with no
remaining rotations also cost nothing. The first three chapters need no R.

`tests/turn/hint-routes.js` records the exact pre-R positions from all 26 successful
continuous keyboard playthroughs, validates every turn, and checks the generated
`hint-routes.bend`. Five additional checked laws cover the finite three-use budget,
exhaustion, free repeated hints, and the unused initial state.

The web build uses this same Bend controller and scene. See `web/README.md` for
the gallery, build, browser controls, and deployment. **Backspace/Delete** resets;
**Tab** opens chapters; arrow keys work for movement and jumping. Web progress is
saved locally on the device.
