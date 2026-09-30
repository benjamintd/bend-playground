import Base
import ./model.bend as M
import ./hint-routes.bend as Route

# The finite budget cannot represent more than three uses.
type Budget is Data:
  Three{}
  Two{}
  One{}
  Empty{}
type Hints is Data:
  Hints{budget: Budget, target: U32, note: U32}
def empty() -> Hints: Hints{Three{},0,0}
def remaining(b: Budget) -> U32:
  match b:
    case Three{}: 3
    case Two{}: 2
    case One{}: 1
    case Empty{}: 0
def spend(b: Budget) -> Budget:
  match b:
    case Three{}: Two{}
    case Two{}: One{}
    case One{}: Empty{}
    case Empty{}: Empty{}
def count(h: Hints) -> U32:
  Hints{b,_,_} = h
  (3 - remaining(b) : U32)
# Re-reading the displayed hint is free; requests that cannot show a rotation
# do not consume a use. 100 = no rotation remains; 101 = off the reference route.
def request_if(fresh: Bool, +target: U32, hints: Hints) -> Hints:
  match fresh hints:
    case False{} Hints{b,old,_}: Hints{b,old,Bool.pick(U32,(target >= 100 : U32),target,0)}
    case True{} Hints{b,_,_}: Hints{spend(b),target,0}
def request(+target: U32, hints: Hints) -> Hints:
  Hints{+b,+old,_} = hints
  request_if((target > 0 : U32) && (target < 100 : U32) && U32.is_ne(target,old) && U32.is_ne(remaining(b),0),target,Hints{b,old,0})
def depth(q: M.Point) -> U32:
  M.Point{_,_,z} = q
  z
def same_plane(a: M.Plane, b: M.Plane) -> Bool:
  M.equal(M.local(a,M.Point{1,2,3}),M.local(b,M.Point{1,2,3}))
# The next turn on a keyboard-verified route is meaningful only while the
# player's hidden coordinate still agrees with that route. Do not invent a
# reachable marker after an arbitrary earlier turn has changed the slice.
def at_end(+plane: M.Plane, q: M.Point, turns: U32, ending: Route.End) -> U32:
  Route.End{pos,+p,total} = ending
  Bool.pick(U32,U32.is_eq(turns,total) && same_plane(plane,p) && U32.is_eq(depth(M.local(plane,q)),depth(M.local(p,pos))),100,101)
def next(spots: List<Route.Spot>, +plane: M.Plane, +q: M.Point, +turns: U32, +ending: Route.End) -> U32:
  match spots:
    case Nil{}: at_end(plane,q,turns,ending)
    case Route.Spot{+p,pos,+order,_} <> rest:
      Bool.pick(U32,(order > turns : U32),
        Bool.pick(U32,same_plane(p,plane) && U32.is_eq(depth(M.local(plane,q)),depth(M.local(p,pos))),order,101),
        next(rest,plane,q,turns,ending))
