import Base
import ../demos/swarm/world.bend as W
import ../demos/swarm/boids.bend as B
import ../demos/swarm/points.bend as P
import ../engine/spatial/grid.bend as G

# Two tight clusters straddle the periodic seam. Scalar fixture is shared with
# the host test oracle, with dy variation to exercise all 3x3 neighbor cells.
def fixture(n: Nat, +i: U32, w: W.World) -> W.World:
  match n:
    case 0n: w
    case 1n+p:
      fixture(p,(i + 1 : U32),W.write(i,w,W.Sample{
        F32.mod((1020.0 + U32.to_f32((i % 8 : U32)) : F32),1024.0),
        F32.mod((1020.0 + U32.to_f32((i / 8 : U32)) : F32),1024.0),
        (U32.to_f32((i % 5 : U32)) * 3.0 - 6.0 : F32),
        (U32.to_f32((i % 7 : U32)) * 2.0 - 6.0 : F32)}))

def output_row(r: W.World & W.Sample) -> IO(W.World):
  (w,W.Sample{x,y,vx,vy}) = r
  do IO<W.World>:
    Unit <- IO.print(F32.show(x) ++ "," ++ F32.show(y) ++ "," ++ F32.show(vx) ++ "," ++ F32.show(vy))
    return w

def output(n: Nat, +i: U32, w: W.World) -> IO(Unit):
  match n:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+p:
      do IO<Unit>:
        w : W.World <- output_row(W.read(i,w))
        output(p,(i + 1 : U32),w)

def finished(b: B.Buffers) -> IO(Unit):
  B.Buffers{_,next,_,_,_,_,_,_} = b
  output(128n,0,next)

def simulate(s: P.Scene) -> IO(Unit):
  P.Scene{w,G.Grid{_,offsets,_,ids}} = s
  finished(B.execute(True{},5n,128,B.Buffers{w,W.empty(7n,128),offsets,ids,0n,0.0,0.0,0.0}))

def main() -> IO(Unit):
  do IO<Unit>:
    s : P.Scene = P.Scene{fixture(128n,0,W.empty(7n,128)),G.empty(7n)}
    barrier : Nat <- IO.now()
    s : P.Scene = P.histogram(True{},5n,s)
    barrier : Nat <- IO.now()
    s : P.Scene = P.scan(s)
    barrier : Nat <- IO.now()
    s : P.Scene = P.scatter(True{},5n,s)
    barrier : Nat <- IO.now()
    simulate(s)
