import Base
import ./model.bend as M
import ./collision.bend as C
import ../../engine/core/math.bend as Math

# Continuous position at 1/1024-cell precision, fixed 120 Hz simulation.
# Velocities are signed fixed point biased by 2048 (2048 is zero).
# The character has a half-cell projected box. Every cube in the active
# silhouette is solid, regardless of its depth or the character's depth.
type Body is Data:
  Body{position: M.Point, vx: U32, vy: U32, coyote: U32, buffer: U32, escape: U32}
type Input is Data:
  Input{left: Bool, right: Bool, fast: Bool}
def initial() -> Body: Body{M.Point{512,256,512},2048,2048,8,0,0}
def position(b: Body) -> M.Point:
  Body{q,_,_,_,_,_} = b
  q
def cells(q: M.Point) -> M.Point:
  M.Point{x,y,z} = q
  M.Point{U32.shrn(x,10n),U32.shrn(y,10n),U32.shrn(z,10n)}
def bounded(q: M.Point) -> Bool: C.bounded(q)
def clear(level: U32, p: M.Plane, q: M.Point) -> Bool: C.clear(level,p,q)
def settled(b: Body) -> Bool:
  Body{_,_,_,_,_,escape} = b
  U32.is_eq(escape,0)
def decay(+n: U32) -> U32: (n - U32.min(n,1) : U32)
def approach(+v: U32, +target: U32, +amount: U32) -> U32:
  Math.word((v < target : U32),(v + U32.min((target - v : U32),amount) : U32),
    (v - U32.min((v - target : U32),amount) : U32))
def shift(+x: U32, +velocity: U32) -> U32:
  Math.word((velocity >= 2048 : U32),(x + velocity - 2048 : U32),(x - U32.min(x,(2048 - velocity : U32)) : U32))
def ground(+level: U32, +p: M.Plane, +q: M.Point) -> Bool:
  Bool.not(clear(level,p,M.candidate(p,q,M.South{},1)))
def request(b: Body) -> Body:
  Body{q,vx,vy,c,buffer,+escape} = b
  Body{q,vx,vy,c,Math.word(U32.is_eq(escape,0),12,buffer),escape}
def pack(q: M.Point) -> U32:
  M.Point{x,y,_} = q
  (1 + x + 16384 * y : U32)
def rotate_body(free: Bool, level: U32, +p: M.Plane, b: Body) -> Body:
  match free:
    case True{}:
      Body{q,_,vy,_,buffer,_} = b
      Body{q,vy,2048,0,buffer,0}
    case False{}:
      Body{+q,_,_,_,_,_} = b
      Body{q,2048,2048,0,0,pack(C.local_target(level,p,M.local(p,q)))}
# The camera switch never moves the character. An intersecting silhouette
# starts a bounded, animated escape; normal collisions resume at first air.
def rotated(+level: U32, +p: M.Plane, +b: Body) -> Body:
  rotate_body(clear(level,p,position(b)),level,p,b)
def component(vertical: Bool, q: M.Point) -> U32:
  M.Point{x,y,_} = q
  Math.word(vertical,y,x)
def replaced(vertical: Bool, q: M.Point, value: U32) -> M.Point:
  match vertical:
    case False{}:
      M.Point{_,y,z} = q
      M.Point{value,y,z}
    case True{}:
      M.Point{x,_,z} = q
      M.Point{x,value,z}
# Speeds are capped below one eighth of a voxel per tick, so a collision
# cannot cross a whole obstacle. Resolve exactly to the contacted voxel face.
def contact(positive: Bool, candidate: U32) -> U32:
  match positive:
    case True{}: (U32.shln(U32.shrn((candidate + 255 : U32),10n),10n) - 256 : U32)
    case False{}: (U32.shln((U32.shrn((candidate - 256 : U32),10n) + 1 : U32),10n) + 256 : U32)
def resolved(hit: Bool, +positive: Bool, +candidate: U32) -> U32:
  Math.word(hit,contact(positive,candidate),candidate)
def axis(+level: U32, +p: M.Plane, +vertical: Bool, +q: M.Point, +velocity: U32) -> M.Point:
  +local = M.local(p,q)
  +candidate = U32.min(9984,U32.max(256,shift(component(vertical,local),velocity)))
  +destination = M.world(p,replaced(vertical,local,candidate))
  M.world(p,replaced(vertical,local,resolved(Bool.not(clear(level,p,destination)),(velocity >= 2048 : U32),candidate)))
def vertical_step(+level: U32, +p: M.Plane, +before: M.Point, +q: M.Point, vx: U32, +vy: U32, coyote: U32, buffer: U32) -> Body:
  Body{q,vx,Math.word(U32.is_eq(component(True{},M.local(p,q)),shift(component(True{},M.local(p,before)),vy)),vy,2048),coyote,buffer,0}
def horizontal_step(+level: U32, +p: M.Plane, +old: M.Point, +q: M.Point, +vx: U32, +vy: U32, coyote: U32, buffer: U32) -> Body:
  vertical_step(level,p,q,axis(level,p,True{},q,vy),Math.word(U32.is_eq(component(False{},M.local(p,q)),shift(component(False{},M.local(p,old)),vx)),vx,2048),vy,coyote,buffer)
def integrate(+level: U32, +p: M.Plane, input: Input, b: Body) -> Body:
  Input{left,right,fast} = input
  Body{+q,vx,+vy,coyote,+buffer,_} = b
  +supported = ground(level,p,q)
  +grace = Math.word(supported,8,decay(coyote))
  +jump = (buffer > 0 : U32) && (grace > 0 : U32)
  +target = (2048 + 26 * Bool.to_u32(right) - 26 * Bool.to_u32(left) : U32)
  +speed = approach(vx,target,Math.word(supported,6,3))
  +vertical = Math.word(jump,2128,U32.max(1948,(vy - Math.word(fast && (vy < 2048 : U32),4,2) : U32)))
  horizontal_step(level,p,q,axis(level,p,False{},q,speed),speed,vertical,Math.word(jump,0,grace),Math.word(jump,0,decay(buffer)))
# The half-cell character must touch the center of the visible (9,9) exit
# cell: 9.5 cells = 9728 units, within its 256-unit half extent on both axes.
# The hidden coordinate is irrelevant.
def exit_local(q: M.Point) -> Bool:
  M.Point{+x,+y,_} = q
  (x >= 9472 : U32) && (x <= 9984 : U32) && (y >= 9472 : U32) && (y <= 9984 : U32)
def exit(p: M.Plane, q: M.Point) -> Bool:
  exit_local(M.local(p,q))
def difference(+a: U32, +b: U32) -> U32:
  Math.word((a >= b : U32),(a - b : U32),(b - a : U32))
def nearby(a: M.Point, b: M.Point) -> Bool:
  M.Point{x,y,z} = a
  M.Point{u,v,w} = b
  (difference(x,u) <= 128 : U32) && (difference(y,v) <= 128 : U32) && (difference(z,w) <= 128 : U32)
def commit(ok: Bool, old: Body, next: Body) -> Body:
  match ok:
    case False{}: old
    case True{}: next
def admit(local: Bool, safe: Bool, old: Body, next: Body) -> Body:
  commit(local && safe,old,next)
def checked(level: U32, p: M.Plane, +old: Body, +next: Body) -> Body:
  admit(nearby(position(old),position(next)),clear(level,p,position(next)),old,next)
def step_if(won: Bool, +level: U32, +p: M.Plane, input: Input, +b: Body) -> Body:
  match won:
    case True{}: b
    case False{}: checked(level,p,b,integrate(level,p,input,b))
# Only a camera switch can enable escape. Ignore steering/jump while inside
# the newly projected wall; accelerate downwards to its first opening. If
# there is no opening below, slide to the closest free cell at 64 units/tick.
def escape_body(+level: U32, +p: M.Plane, +next: M.Point, +vy: U32, escape: U32) -> Body:
  Body{next,2048,vy,0,0,Math.word(clear(level,p,next),0,escape)}
def settling_local(+level: U32, +p: M.Plane, +b: Body, local: M.Point) -> Body:
  Body{+q,_,vy,_,_,+escape} = b
  M.Point{+x,+y,z} = local
  +tx = ((escape - 1) % 16384 : U32)
  +ty = ((escape - 1) / 16384 : U32)
  +falling = (ty < y : U32) && U32.is_eq(tx,x)
  +vertical = Math.word(falling,U32.max(1948,(vy - 2 : U32)),2048)
  +next = M.world(p,M.Point{approach(x,tx,64),approach(y,ty,Math.word(falling,(2048 - vertical : U32),64)),z})
  admit(nearby(q,next),bounded(next),b,escape_body(level,p,next,vertical,escape))
def settling(+level: U32, +p: M.Plane, +b: Body) -> Body:
  settling_local(level,p,b,M.local(p,position(b)))
def mode(normal: Bool, level: U32, +p: M.Plane, input: Input, +b: Body) -> Body:
  match normal:
    case True{}: step_if(exit(p,position(b)),level,p,input,b)
    case False{}: settling(level,p,b)
def step(level: U32, p: M.Plane, input: Input, +b: Body) -> Body:
  mode(settled(b),level,p,input,b)
