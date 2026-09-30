import Base
import ./model.bend as M
import ./levels.bend as L
import ../../engine/core/math.bend as Math

# One immutable 2D silhouette per view, shared by movement and turn settling.
def bounded(q: M.Point) -> Bool:
  M.Point{+x,+y,+z} = q
  (x >= 256 : U32) && (x <= 9984 : U32) && (y >= 256 : U32) && (y <= 9984 : U32)
    && (z >= 256 : U32) && (z <= 9984 : U32)
def local_clear(+level: U32, +p: M.Plane, q: M.Point) -> Bool:
  M.Point{+x,+y,_} = q
  +lo_x = U32.shrn((x - 256 : U32),10n)
  +lo_y = U32.shrn((y - 256 : U32),10n)
  +hi_x = U32.shrn((x + 255 : U32),10n)
  +hi_y = U32.shrn((y + 255 : U32),10n)
  L.projected_local(level,p,M.Point{lo_x,lo_y,0}) && L.projected_local(level,p,M.Point{lo_x,hi_y,0})
    && L.projected_local(level,p,M.Point{hi_x,lo_y,0}) && L.projected_local(level,p,M.Point{hi_x,hi_y,0})
def clear(level: U32, +p: M.Plane, +q: M.Point) -> Bool:
  bounded(q) && local_clear(level,p,M.local(p,q))
def difference(+a: U32, +b: U32) -> U32:
  Math.word((a >= b : U32),(a - b : U32),(b - a : U32))
type Target is Data:
  Target{point: M.Point, distance: U32}
def down(+n: Nat, +level: U32, +p: M.Plane, +q: M.Point, best: Target) -> Target:
  match n:
    case 0n: best
    case 1n+k:
      M.Point{+x,+y,+z} = q
      +v = (U32.from_nat(k) * 1024 + 512 : U32)
      +next = {M.Point{x,v,z} : M.Point}
      Bool.pick(Target,(v < y : U32) && local_clear(level,p,next),Target{next,difference(y,v)},down(k,level,p,q,best))
# A balanced minimum keeps proof reduction shallow. Candidate order and
# tie breaking are identical to scanning cells 99 down to 0.
def better(a: Target, b: Target) -> Target:
  Target{qa,+da} = a
  Target{qb,+db} = b
  Bool.pick(Target,(da < db : U32),Target{qa,da},Target{qb,db})
def candidate(+i: U32, +level: U32, +p: M.Plane, q: M.Point) -> Target:
  M.Point{x,y,z} = q
  +u = ((i % 10) * 1024 + 512 : U32)
  +v = ((i / 10) * 1024 + 512 : U32)
  +next = {M.Point{u,v,z} : M.Point}
  Target{next,Math.word((i < 100 : U32) && local_clear(level,p,next),(difference(x,u) + difference(y,v) : U32),1000000)}
def nearest(+depth: Nat, +first: U32, +level: U32, +p: M.Plane, +q: M.Point) -> Target:
  match depth:
    case 0n: candidate(first,level,p,q)
    case 1n+k: better(nearest(k,first,level,p,q),nearest(k,(first + U32.shln(1,k) : U32),level,p,q))
def fallback(found: Bool, level: U32, p: M.Plane, q: M.Point, best: Target) -> Target:
  match found:
    case True{}: best
    case False{}: nearest(7n,0,level,p,q)
def target_point(t: Target) -> M.Point:
  Target{point,_} = t
  point
def resolved(level: U32, p: M.Plane, q: M.Point, +best: Target) -> M.Point:
  Target{_,distance} = best
  target_point(fallback((distance < 1000000 : U32),level,p,q,best))
# Prefer dropping out of the intersecting column. At the bottom boundary,
# choose the nearest free cell: usually onto a floor or sideways out of a wall.
# All authored projections contain free cells, checked by catalog validation.
def local_target(+level: U32, +p: M.Plane, +q: M.Point) -> M.Point:
  resolved(level,p,q,down(10n,level,p,q,Target{q,1000000}))
def world_target(level: U32, +p: M.Plane, q: M.Point) -> M.Point:
  M.world(p,local_target(level,p,M.local(p,q)))
def scaled(q: M.Point) -> M.Point:
  M.Point{x,y,z} = q
  M.Point{(x * 1024 + 512 : U32),(y * 1024 + 512 : U32),(z * 1024 + 512 : U32)}
def cells(q: M.Point) -> M.Point:
  M.Point{x,y,z} = q
  M.Point{(x / 1024 : U32),(y / 1024 : U32),(z / 1024 : U32)}
# The planner uses the authored cell-center resolution table. Live physics
# still resolves exact subcell coordinates above; tests compare both paths.
def cell_point(+index: U32, depth: U32) -> M.Point:
  M.Point{(index % 10 : U32),(index / 10 : U32),depth}
def cell_local(level: U32, +p: M.Plane, q: M.Point) -> M.Point:
  M.Point{x,y,z} = q
  M.world(p,cell_point(L.escape_cell(level,p,(x + y * 10 : U32)),z))
def cell_if(free: Bool, level: U32, +p: M.Plane, q: M.Point) -> M.Point:
  match free:
    case True{}: q
    case False{}: cell_local(level,p,M.local(p,q))
def cell(+level: U32, +p: M.Plane, +q: M.Point) -> M.Point:
  cell_if(L.projected_free(level,p,q),level,p,q)
