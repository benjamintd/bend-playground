import Base
import ./hints.bend as H
import ./LAWS.bend as Laws
import ./model.bend as M
import ./solutions.bend as S
import ./physics.bend as F

def Laws.three_turns_restore_plane(p):
  match p:
    case M.XY{}: {==}
    case M.YZ{}: {==}
    case M.ZX{}: {==}
def Laws.projection_round_trip(p,q):
  match p:
    case M.XY{}: {==}
    case M.YZ{}:
      M.Point{x,y,z} = q
      {==}
    case M.ZX{}:
      M.Point{x,y,z} = q
      {==}
def Laws.rotation_starts_in_place(free,level,p,b):
  match free:
    case True{}:
      F.Body{q,vx,vy,c,buffer,escape} = b
      {==}
    case False{}:
      F.Body{q,vx,vy,c,buffer,escape} = b
      {==}
def Laws.excessive_motion_is_rejected(safe,old,next): {==}
def Laws.accepted_motion_is_unchanged(old,next): {==}
def Laws.rejected_move_stays_put(old,next): {==}
def Laws.east_stays_in_slice(p,x,y,z,n):
  match p:
    case M.XY{}: {==}
    case M.YZ{}: {==}
    case M.ZX{}: {==}
def Laws.paper_steps_possible(): (S.level0(),{==})
def Laws.distant_steps_possible(): (S.level1(),{==})
def Laws.missing_tooth_possible(): (S.level2(),{==})

def Laws.movement_preserves_slice(p,q,d,n):
  match p:
    case M.XY{}:
      M.Point{x,y,z} = q
      match d:
        case M.East{}: {==}
        case M.North{}: {==}
        case M.West{}: {==}
        case M.South{}: {==}
    case M.YZ{}:
      M.Point{x,y,z} = q
      match d:
        case M.East{}: {==}
        case M.North{}: {==}
        case M.West{}: {==}
        case M.South{}: {==}
    case M.ZX{}:
      M.Point{x,y,z} = q
      match d:
        case M.East{}: {==}
        case M.North{}: {==}
        case M.West{}: {==}
        case M.South{}: {==}
def Laws.goal_ignores_hidden_coordinate(p,depth):
  match p:
    case M.XY{}: {==}
    case M.YZ{}: {==}
    case M.ZX{}: {==}

def Laws.standing_jump_is_vertical(): {==}
def Laws.diagonal_jump_lands_on_block(): {==}
def Laws.cannot_walk_through_first_step(): {==}
def Laws.unsupported_player_falls(): {==}
def Laws.grounded_player_stays_on_block(): {==}

def Laws.rejected_physics_step_stays_put(old,next): {==}
def Laws.large_physics_step_is_rejected(): {==}
def Laws.exit_requires_center_contact(): {==}
def Laws.exit_is_a_projection(): {==}
def Laws.rising_two_cell_gap_jump(): {==}

def Laws.world_occupancy_is_rotation_invariant(level,p,q):
  match p:
    case M.XY{}: {==}
    case M.YZ{}:
      M.Point{x,y,z} = q
      {==}
    case M.ZX{}:
      M.Point{x,y,z} = q
      {==}

def Laws.live_exit_ignores_depth(plane,depth):
  match plane:
    case M.XY{}: {==}
    case M.YZ{}: {==}
    case M.ZX{}: {==}

def Laws.projected_collision_ignores_hidden_depth(level,p,x,y,a,b):
  match p:
    case M.XY{}: {==}
    case M.YZ{}: {==}
    case M.ZX{}: {==}
def Laws.first_step_blocks_every_depth_xy(depth): {==}
def Laws.first_step_blocks_every_depth_yz(depth): {==}
def Laws.first_step_blocks_every_depth_zx(depth): {==}
def Laws.rotation_into_a_floor_settles_above(): {==}
def Laws.intersecting_step_falls_to_first_open_cell(): {==}
def Laws.free_turn_needs_no_correction(): {==}
def Laws.settling_preserves_hidden_depth(depth): {==}
def Laws.jump_during_settling_is_ignored(q): {==}
def Laws.ring_contact_ignores_depth(x,y,a,b): {==}
def Laws.first_act_has_no_ring_gate(p,q): {==}
def Laws.free_cell_resolution_stays_put(level,p,q): {==}
def Laws.invalid_solution_certificate_is_rejected(): {==}
def Laws.frozen_clock_has_no_physics_tick(phase): {==}
def Laws.camera_turn_has_no_physics_tick(pace,phase): {==}
def Laws.zero_time_preserves_body(level,plane,keys,body): {==}
def Laws.movement_releases_frozen_time(): {==}
def Laws.frozen_time_stays_frozen(): {==}
def Laws.resume_finishes_in_half_a_second(): {==}
def Laws.resume_reaches_full_speed(): {==}

def Laws.at_most_three_hint_uses(budget):
  match budget:
    case H.Three{}: {==}
    case H.Two{}: {==}
    case H.One{}: {==}
    case H.Empty{}: {==}
def Laws.three_uses_exhaust_hints(): {==}
def Laws.exhausted_hints_stay_exhausted(): {==}
def Laws.rereading_a_hint_is_free(budget): {==}
def Laws.hints_start_unused(): {==}
