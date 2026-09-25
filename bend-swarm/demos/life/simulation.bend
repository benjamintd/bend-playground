import Base
import ../../engine/core/math.bend as Math
import ../../engine/spatial.bend as Spatial
import ../../engine/spatial/layout.bend as L

type Particle is Data:
  Particle{x: F32, y: F32, vx: F32, vy: F32}
type Controls is Data:
  Controls{preset: U32, seed: U32, mx: F32, my: F32, power: F32}
type Force is Data:
  Force{x: F32, y: F32}
def space() -> L.Layout:
  L.Layout{2,5n,5n,0n,32.0,0.0,0.0,0.0,True{}}
def initial(+i: U32, +seed: U32) -> Particle:
  Particle{(Math.random(i,seed) * 1024.0 : F32),(Math.random(i,(seed + 8713 : U32)) * 1024.0 : F32),0.0,0.0}
def fill(n: Nat, +i: U32, +seed: U32, a: Array<Particle>) -> Array<Particle>:
  match n:
    case 0n: a
    case 1n+k: fill(k,(i + 1 : U32),seed,Array.set(Particle,a,i,initial(i,seed)))
def source(seed: U32) -> Array<Particle>:
  fill(8192n,0,seed,Array.new(Particle,13n,Particle{0.0,0.0,0.0,0.0}))
def point(p: Particle) -> L.Point:
  Particle{x,y,_,_} = p
  L.Point{x,y,0.0}
def positioned(r: Array<Particle> & Particle) -> Array<Particle> & L.Point:
  (a,p) = r
  (a,point(p))
def position(+i: U32, a: Array<Particle>) -> Array<Particle> & L.Point:
  positioned(Array.get(Particle,a,i))
def read(+i: U32, a: Array<Particle>) -> Array<Particle> & Particle:
  Array.get(Particle,a,i)
def begin(i: U32, p: Particle, c: Controls) -> Force:
  Force{0.0,0.0}
def coefficient(preset: U32, seed: U32, +a: U32, +b: U32) -> F32:
  match preset:
    case 0: L.pick(U32.is_eq(a,b),0.85,F32.neg(0.45))
    case 1: L.pick(U32.is_eq(a,b),0.2,L.pick(U32.is_eq(((a + 1) % 6 : U32),b),0.95,
      L.pick(U32.is_eq(((b + 1) % 6 : U32),a),F32.neg(0.7),F32.neg(0.16))))
    case _: L.pick(U32.is_eq(a,b),0.5,((Math.random((a * 6 + b : U32),seed) * 2.0 - 1.0) * 0.9 : F32))
def profile(near: Bool, +r: F32, strength: F32) -> F32:
  match near:
    case True{}: ((r / 0.2 - 1.0) * 2.4 : F32)
    case False{}: (strength * F32.max(0.0,(1.0 - F32.abs((2.0 * r - 1.2 : F32)) / 0.8 : F32)) : F32)
def force(coefficient: F32, dx: F32, dy: F32, +distance: F32) -> Force:
  +r = (distance / 32.0 : F32)
  +m = (profile((r < 0.2 : F32),r,coefficient) * 95.0 / F32.max(distance,0.001) : F32)
  Force{(dx * m : F32),(dy * m : F32)}
def accumulated(a: Force, b: Force) -> Force:
  Force{ax,ay} = a
  Force{bx,by} = b
  Force{(ax + bx : F32),(ay + by : F32)}
def visit(i: U32, self: Particle, j: U32, other: Particle, delta: L.Delta, c: Controls, f: Force) -> Force:
  L.Delta{dx,dy,_,distance2} = delta
  Controls{preset,seed,_,_,_} = c
  accumulated(f,force(coefficient(preset,seed,(i % 6 : U32),(j % 6 : U32)),dx,dy,F32.sqrt(distance2)))
def wrap_delta(+x: F32) -> F32:
  (x - F32.floor((x / 1024.0 + 0.5 : F32)) * 1024.0 : F32)
def integrated(+x: F32, +y: F32, +vx: F32, +vy: F32) -> Particle:
  +scale = F32.min(1.0,(90.0 / F32.sqrt((vx * vx + vy * vy + 0.000001 : F32)) : F32))
  +dx = (vx * scale : F32)
  +dy = (vy * scale : F32)
  Particle{Math.wrap((x + dx * 0.016666667 : F32)),Math.wrap((y + dy * 0.016666667 : F32)),dx,dy}
def integrate(p: Particle, c: Controls, f: Force) -> Particle:
  Particle{+x,+y,vx,vy} = p
  Controls{_,_,mx,my,power} = c
  Force{ax,ay} = f
  +dx = wrap_delta((mx - x : F32))
  +dy = wrap_delta((my - y : F32))
  +pull = (power * 350.0 / F32.sqrt((dx * dx + dy * dy + 144.0 : F32)) : F32)
  integrated(x,y,((vx + (ax + dx * pull) * 0.016666667) * 0.91 : F32),((vy + (ay + dy * pull) * 0.016666667) * 0.91 : F32))
def finish(i: U32, p: Particle, c: Controls, f: Force, out: Array<Particle>) -> Array<Particle>:
  Array.set(Particle,out,i,integrate(p,c,f))
def neighbors(gpu: Bool, depth: Nat, c: Controls, snapshot: Spatial.Snapshot(space(),Array<Particle>), out: Array<Particle>) -> IO(Spatial.Step(space(),Array<Particle>,Array<Particle>)):
  Spatial.require(~Spatial.Step(space(),Array<Particle>,Array<Particle>),Spatial.stencil(~space(),~Array<Particle>,~Array<Particle>,~Particle,~Force,~Controls,
    ~read,~point,~begin,~visit,~finish,~Array.join(Particle),~Array.join(Particle),gpu,depth,32.0,False{},c,snapshot,out))
type State is Type:
  State{current: Array<Particle>, previous: Array<Particle>, index: Spatial.Index(space())}
def created(seed: U32, r: Result<String,Spatial.Index(space())>) -> Result<String,State>:
  match r:
    case Fail{e}: Fail{e}
    case Done{i}: Done{State{source(seed),Array.new(Particle,13n,Particle{0.0,0.0,0.0,0.0}),i}}
def create(seed: U32) -> IO(State):
  Spatial.require(~State,created(seed,Spatial.create(~space(),13n)))
def released(r: Array<Particle> & Array<Particle> & Spatial.Index(space()) & Spatial.Statistics) -> State:
  (old,current,index,_) = r
  State{current,old,index}
def step(+gpu: Bool, c: Controls, s: State) -> IO(State):
  State{current,out,index} = s
  +depth = Bool.pick(Nat,gpu,13n,7n)
  do IO<State>:
    snapshot : Spatial.Snapshot(space(),Array<Particle>) <- Spatial.require(~Spatial.Snapshot(space(),Array<Particle>),
      Spatial.build(~space(),~Array<Particle>,~position,~Array.join(Particle),gpu,depth,8192,current,index))
    result : Spatial.Step(space(),Array<Particle>,Array<Particle>) <- neighbors(gpu,depth,c,snapshot,out)
    return released(Spatial.release(~space(),~Array<Particle>,~Array<Particle>,result))
def advance(paused: Bool, gpu: Bool, c: Controls, s: State) -> IO(State):
  match paused:
    case True{}: IO.pure(State,s)
    case False{}: step(gpu,c,s)
