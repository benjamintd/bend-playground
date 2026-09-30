import Base
import ./model.bend as M
import ./levels.bend as L
import ./collision.bend as C

# One cell-space planning beat. Live continuous collision is in physics.bend.
# Only the plane's horizontal coordinate is walkable.
# Gravity points down its vertical coordinate. The cube boundary is a floor.
def grounded(+level: U32, +plane: M.Plane, +q: M.Point) -> Bool:
  Bool.not(L.projected_free(level,plane,M.candidate(plane,q,M.South{},1)))
def displace(level: U32, +plane: M.Plane, +q: M.Point, d: M.Direction) -> M.Point:
  +next = M.candidate(plane,q,d,1)
  M.accept(L.projected_free(level,plane,next),q,next)
def horizontal(level: U32, p: M.Plane, q: M.Point, d: M.Direction) -> M.Point:
  match d:
    case M.East{}: displace(level,p,q,M.East{})
    case M.West{}: displace(level,p,q,M.West{})
    case _: q
def fall(level: U32, +plane: M.Plane, q: M.Point) -> M.State:
  M.State{displace(level,plane,q,M.South{}),plane}
def walking(+level: U32, +p: M.Plane, q: M.Point, d: M.Direction) -> M.State:
  fall(level,p,horizontal(level,p,q,d))
def jump_if(ok: Bool, +level: U32, +p: M.Plane, q: M.Point, d: M.Direction) -> M.State:
  match ok:
    case False{}: walking(level,p,q,d)
    case True{}: M.State{horizontal(level,p,M.candidate(p,q,M.North{},1),d),p}
def jump(+level: U32, +p: M.Plane, +q: M.Point, d: M.Direction) -> M.State:
  jump_if(grounded(level,p,q) && L.projected_free(level,p,M.candidate(p,q,M.North{},1)),level,p,q,d)
# A planning turn includes the automatic escape to the first free cell.
# Live physics animates that escape and resumes gravity at the first opening.
def rotate(ok: Bool, level: U32, +p: M.Plane, q: M.Point) -> M.State:
  match ok:
    case False{}: M.State{q,p}
    case True{}: M.State{C.cell(level,M.cycle(p),q),M.cycle(p)}
def step(+level: U32, s: M.State, a: M.Action) -> M.State:
  match s:
    case M.State{+q,+p}:
      match a:
        case M.Rotate{}: rotate(L.turn_allowed(level,p,q),level,p,q)
        case M.Walk{d}: walking(level,p,q,d)
        case M.Jump{d}: jump(level,p,q,d)
        case M.Wait{}: fall(level,p,q)
def same(a: M.State, b: M.State) -> Bool:
  M.State{q,p} = a
  M.State{r,t} = b
  M.equal(q,r) && M.equal(M.local(p,M.Point{1,2,3}),M.local(t,M.Point{1,2,3}))
def run(+level: U32, actions: List<M.Action>, s: M.State) -> M.State:
  match actions:
    case Nil{}: s
    case a <> rest: run(level,rest,step(level,s,a))
# Every visited projection is empty and bounded; each action makes progress, and
# the final projected cell is (9,9). Depth does not constrain the exit.
def clear(level: U32, s: M.State) -> Bool:
  M.State{+q,p} = s
  M.inside(q) && L.projected_free(level,p,q)
def valid(+level: U32, actions: List<M.Action>, +s: M.State) -> Bool:
  match actions:
    case Nil{}: clear(level,s) && M.won(s)
    case a <> rest:
      +next = step(level,s,a)
      clear(level,s) && Bool.not(M.won(s)) && Bool.not(same(s,next)) && valid(level,rest,next)

# A proof witness carries its intermediate states explicitly. Each link is
# checked against step, so certificates cannot invent a move. Using the
# certified next value avoids repeatedly normalizing an entire prefix while
# checking a later rotation's intersection resolver.
type Beat is Data:
  Beat{action: M.Action, after: M.State}
def certified(+level: U32, beats: List<Beat>, +s: M.State) -> Bool:
  match beats:
    case Nil{}: clear(level,s) && M.won(s)
    case Beat{a,+next} <> rest:
      clear(level,s) && Bool.not(M.won(s)) && Bool.not(same(s,next))
        && same(step(level,s,a),next) && certified(level,rest,next)
