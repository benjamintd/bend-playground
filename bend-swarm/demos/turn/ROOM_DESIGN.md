# Projected-world campaign design

Every chapter is designed around the union of all cubes in each 2D view.
A far-away cube blocks exactly as much as a nearby one. Rotation can intersect
that union; on resuming time, the character escapes downward, with a
nearest-opening fallback at the boundary. This rule is useful puzzle geometry, not a failed input.

There are only two optional challenges: seals and a turn target. The final
eight chapters require a violet ring to begin a rotation chain. Time remains
frozen while selecting further views; movement or jump resumes it smoothly. No keys, switches, moving
walls, hazards, or exit locks were added. All worlds remain fixed full cubes.

## Progression and intent

| Chapter | Discovery / hint | Minimum exit turns in cell model | Verified all-seal turns |
| --- | --- | ---: | ---: |
| 01 · Paper Steps | Jump onto the cubes. reach the green door. | 0 | 0 |
| 02 · Distant Steps | A visible step is solid at every depth. | 0 | 0 |
| 03 · Missing Tooth | Carry your jump across the missing step. | 0 | 0 |
| 04 · Borrowed Height | Walk far. turn twice. distance becomes height. | 2 | 2 |
| 05 · Bent Ladder | The ladder continues in another view. | 2 | 2 |
| 06 · Shared Support | A wall in one view can support the next. | 2 | 3 |
| 07 · Over The Wall | Gain height before you cross the ridge. | 2 | 2 |
| 08 · Second Thought | Leave the balcony. come back from above. | 3 | 3 |
| 09 · The Balcony | The low shelf can become a high landing. | 3 | 3 |
| 10 · Return Path | One circuit is only the beginning. | 3 | 4 |
| 11 · Low Ceiling | A low roof asks for a different approach. | 4 | 4 |
| 12 · Ribbon Walk | The stair bends. follow its other shadow. | 4 | 6 |
| 13 · Sideways Stair | The exit above the wall needs a side route. | 4 | 4 |
| 14 · The Long Drop | Turn into the wall. fall out below it. | 5 | 7 |
| 15 · Split Horizon | Two broken stairs can make one route. | 4 | 6 |
| 16 · Switchback | Sometimes progress means turning back. | 5 | 9 |
| 17 · Negative Space | Look for the opening, not the obstacle. | 2 | 5 |
| 18 · Three Acts | Trade height for distance, then trade back. | 5 | 6 |
| 19 · First Station | Jump into a violet ring. then press r. | 2 | 3 |
| 20 · Transfer | Visit the low ring before the high one. | 3 | 3 |
| 21 · Hinge Point | The same ring connects different ledges. | 3 | 3 |
| 22 · Detour | Follow the rings through the long way round. | 5 | 5 |
| 23 · The Crossing | Leave the first view. return from above. | 6 | 6 |
| 24 · Counterweight | Let one fall set up your next climb. | 5 | 5 |
| 25 · Afterimage | Turn again at a familiar station. | 5 | 5 |
| 26 · Final Fold | Spend your height. rebuild it in another view. | 5 | 5 |

The first two chapters deliberately share an XY staircase while placing cubes
at different depths: visible steps stay solid. The missing step then teaches
an actual two-cell jump. Borrowed Height isolates the core coordinate exchange
with a single beam. Later layouts combine stairs, ceilings, voids and returns;
the last eight demand choosing where to turn. Ring approaches include standing
and jumping into a station. Ring contact tolerates the full central half of a
cell, and the transition anchors the character.

Negative Space has a shorter exit than its all-seal tour. Shortcuts are allowed;
difficulty ratings include route discovery and optional collection, not just
minimum rotations. The ring introduction lowers the demand before the final
rooms combine the rules. The continuous witnesses take roughly 5–27 seconds
without deliberation; these timings are route fixtures, not player time limits.

## Authoring and validation

The old depth-based campaign was audited again under projected collisions.
Layouts that were blocked, redundant, or reliant on walking through a visible
wall were replaced. The catalog now stores explicit 8–21-cube arrangements,
not seed-dependent runtime generation. Design provenance records candidate
families, but only the written coordinates determine a level.

Each chapter has a cell-space witness and a native keyboard replay that reaches
the projected exit with all seals within par. The independent solver also
measures the cheapest cell-space rotation count; it is not an optimality proof
for continuous controls. The cell planner releases time and resolves overlap
after each turn; it does not enumerate frozen chains. Its counts describe that
restricted planning model, not lower bounds for all live solutions. Every projected cell has a checked resolution law,
and continuous tests exercise embedded starts throughout all views.

These checks prove the authored solutions and resolver properties, not that
every possible mistake remains recoverable or that a hint will be obvious to
every player. Backspace is always available. Human playtesting remains useful
for readability, ring timing and subjective difficulty.

Authoritative layouts: `catalog.json`. Proof witnesses: `solutions.bend`.
Keyboard plans: `tests/turn/projected-plans.json`. All are deterministic, and
none of the solution data is read by the running game.
