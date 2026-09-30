import Base
import ./hints.bend as H
import ./model.bend as M
import ./rules.bend as R
import ./physics.bend as F
import ./levels.bend as L
import ./collision.bend as C
import ./tempo.bend as T
import ./play.bend as P

law three_turns_restore_plane:
  for p: M.Plane
  {M.cycle(M.cycle(M.cycle(p))) == p : M.Plane}
law projection_round_trip:
  for p: M.Plane
  for q: M.Point
  {M.world(p,M.local(p,q)) == q : M.Point}
# A rotation may change the eventual resting cell, but its camera switch
# never teleports the continuous body, whether the new view is clear or solid.
law rotation_starts_in_place:
  for free: Bool
  for level: U32
  for p: M.Plane
  for b: F.Body
  {F.position(F.rotate_body(free,level,p,b)) == F.position(b) : M.Point}
law excessive_motion_is_rejected:
  for safe: Bool
  for old: F.Body
  for next: F.Body
  {F.admit(False{},safe,old,next) == old : F.Body}
law accepted_motion_is_unchanged:
  for old: F.Body
  for next: F.Body
  {F.admit(True{},True{},old,next) == next : F.Body}
law rejected_move_stays_put:
  for old: M.Point
  for next: M.Point
  {M.accept(False{},old,next) == old : M.Point}
law east_stays_in_slice:
  for p: M.Plane
  for x: U32
  for y: U32
  for z: U32
  for n: U32
  {M.local(p,M.candidate(p,M.world(p,M.Point{x,y,z}),M.East{},n)) == M.Point{(x + n : U32),y,z} : M.Point}
# Constructive reachability, including every intermediate collision/bounds
# check. These are the cell-space planning contract. Continuous native
# replay tests separately verify realizability with the actual collider.
law paper_steps_possible:
  exs actions: List<M.Action>
  {R.valid(0,actions,M.origin()) == True{} : Bool}
law distant_steps_possible:
  exs actions: List<M.Action>
  {R.valid(1,actions,M.origin()) == True{} : Bool}
law missing_tooth_possible:
  exs actions: List<M.Action>
  {R.valid(2,actions,M.origin()) == True{} : Bool}

law movement_preserves_slice:
  for p: M.Plane
  for q: M.Point
  for d: M.Direction
  for n: U32
  {M.depth(M.local(p,M.candidate(p,q,d,n))) == M.depth(M.local(p,q)) : U32}
law goal_ignores_hidden_coordinate:
  for p: M.Plane
  for depth: U32
  {M.won(M.State{M.world(p,M.Point{9,9,depth}),p}) == True{} : Bool}

law standing_jump_is_vertical:
  {M.position(R.step(0,M.origin(),M.Jump{M.North{}})) == M.Point{0,1,0} : M.Point}
law diagonal_jump_lands_on_block:
  {M.position(R.step(0,M.origin(),M.Jump{M.East{}})) == M.Point{1,1,0} : M.Point}
law cannot_walk_through_first_step:
  {M.position(R.step(0,M.origin(),M.Walk{M.East{}})) == M.Point{0,0,0} : M.Point}
law unsupported_player_falls:
  {M.position(R.step(0,M.State{M.Point{0,1,0},M.XY{}},M.Wait{})) == M.Point{0,0,0} : M.Point}
law grounded_player_stays_on_block:
  {M.position(R.step(0,M.State{M.Point{1,1,0},M.XY{}},M.Wait{})) == M.Point{1,1,0} : M.Point}


law rejected_physics_step_stays_put:
  for old: F.Body
  for next: F.Body
  {F.commit(False{},old,next) == old : F.Body}
law large_physics_step_is_rejected:
  {F.checked(0,M.XY{},F.initial(),F.Body{M.Point{4000,9000,512},2048,2048,0,0,0}) == F.initial() : F.Body}
law exit_requires_center_contact:
  {F.exit(M.XY{},M.Point{9300,9450,9670}) == False{} : Bool}
law exit_is_a_projection:
  {F.exit(M.XY{},M.Point{9472,9472,512}) == True{} : Bool}
law rising_two_cell_gap_jump:
  {M.position(R.run(2,[M.Jump{M.East{}},M.Walk{M.East{}}],M.State{M.Point{3,3,0},M.XY{}})) == M.Point{5,4,0} : M.Point}

law world_occupancy_is_rotation_invariant:
  for level: U32
  for p: M.Plane
  for q: M.Point
  {L.solid(level,M.world(p,M.local(p,q))) == L.solid(level,q) : Bool}

law live_exit_ignores_depth:
  for plane: M.Plane
  for depth: U32
  {F.exit(plane,M.world(plane,M.Point{9472,9472,depth})) == True{} : Bool}

law projected_collision_ignores_hidden_depth:
  for level: U32
  for p: M.Plane
  for x: U32
  for y: U32
  for a: U32
  for b: U32
  {L.projected_free(level,p,M.world(p,M.Point{x,y,a})) == L.projected_free(level,p,M.world(p,M.Point{x,y,b})) : Bool}
law first_step_blocks_every_depth_xy:
  for depth: U32
  {L.projected_free(0,M.XY{},M.Point{1,0,depth}) == False{} : Bool}
law first_step_blocks_every_depth_yz:
  for depth: U32
  {L.projected_free(0,M.YZ{},M.Point{depth,0,0}) == False{} : Bool}
law first_step_blocks_every_depth_zx:
  for depth: U32
  {L.projected_free(0,M.ZX{},M.Point{1,depth,0}) == False{} : Bool}
law rotation_into_a_floor_settles_above:
  {R.step(0,M.origin(),M.Rotate{}) == M.State{M.Point{0,0,1},M.YZ{}} : M.State}
law intersecting_step_falls_to_first_open_cell:
  {C.cell(0,M.XY{},M.Point{5,4,0}) == M.Point{5,3,0} : M.Point}
law free_turn_needs_no_correction:
  {C.cell(0,M.XY{},M.Point{5,5,0}) == M.Point{5,5,0} : M.Point}
law settling_preserves_hidden_depth:
  for depth: U32
  {C.local_target(0,M.XY{},M.Point{5632,4608,depth}) == M.Point{5632,3584,depth} : M.Point}
law jump_during_settling_is_ignored:
  for q: M.Point
  {F.request(F.Body{q,2048,2048,0,0,1}) == F.Body{q,2048,2048,0,0,1} : F.Body}
law ring_contact_ignores_depth:
  for x: U32
  for y: U32
  for a: U32
  for b: U32
  {L.same_projection(M.Point{x,y,a},M.Point{x,y,b}) == L.same_projection(M.Point{x,y,0},M.Point{x,y,0}) : Bool}
law first_act_has_no_ring_gate:
  for p: M.Plane
  for q: M.Point
  {L.turn_allowed(0,p,q) == True{} : Bool}

law free_cell_resolution_stays_put:
  for level: U32
  for p: M.Plane
  for q: M.Point
  {C.cell_if(True{},level,p,q) == q : M.Point}
law invalid_solution_certificate_is_rejected:
  {R.certified(0,[R.Beat{M.Walk{M.East{}},M.State{M.Point{9,9,0},M.XY{}}}],M.origin()) == False{} : Bool}

law frozen_clock_has_no_physics_tick:
  for phase: U32
  {T.pulse(False{},1,phase) == T.Pulse{False{},0,1} : T.Pulse}
law camera_turn_has_no_physics_tick:
  for pace: U32
  for phase: U32
  {T.pulse(True{},pace,phase) == T.Pulse{False{},0,pace} : T.Pulse}
law zero_time_preserves_body:
  for level: U32
  for plane: M.Plane
  for keys: U32
  for body: F.Body
  {P.simulate(False{},level,plane,keys,body) == body : F.Body}
law movement_releases_frozen_time:
  {T.release(1) == 2 : U32}
law frozen_time_stays_frozen:
  {T.next(1) == 1 : U32}
law resume_finishes_in_half_a_second:
  {T.advance(60n,2) == 0 : U32}
law resume_reaches_full_speed:
  {T.rate(61) == 100 : U32}

law at_most_three_hint_uses:
  for budget: H.Budget
  {U32.is_le(H.remaining(budget),3) == True{} : Bool}
law three_uses_exhaust_hints:
  {H.spend(H.spend(H.spend(H.Three{}))) == H.Empty{} : H.Budget}
law exhausted_hints_stay_exhausted:
  {H.spend(H.Empty{}) == H.Empty{} : H.Budget}
law rereading_a_hint_is_free:
  for budget: H.Budget
  {H.request(1,H.Hints{budget,1,0}) == H.Hints{budget,1,0} : H.Hints}
law hints_start_unused:
  {H.count(H.empty()) == 0 : U32}
