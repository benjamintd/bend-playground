import Base
import ../demos/cloth/world.bend as W
import ../demos/cloth/physics.bend as P
import ../demos/cloth/simulation.bend as S
import ../engine/spatial.bend as Spatial
import ../engine/spatial/layout.bend as L


def row(r: W.Positions & L.Point) -> IO(W.Positions):
  (p,L.Point{x,y,z}) = r
  do IO<W.Positions>:
    Unit <- IO.print(F32.show(x) ++ "," ++ F32.show(y) ++ "," ++ F32.show(z))
    return p

def output(n: Nat, +i: U32, p: W.Positions) -> IO(W.Positions):
  match n:
    case 0n: IO.pure(W.Positions,p)
    case 1n+k:
      do IO<W.Positions>:
        p : W.Positions <- row(W.read(i,p))
        output(k,(i + 1 : U32),p)

def snapshot(on: Bool, state: S.State) -> IO(S.State):
  match on:
    case False{}: IO.pure(S.State,state)
    case True{}:
      S.State{+side,p,prev,scratch,index,samples,checks,neighbors} = state
      do IO<S.State>:
        p : W.Positions <- output(U32.to_nat((side * side : U32)),0,p)
        return S.State{side,p,prev,scratch,index,samples,checks,neighbors}
def frames(n: Nat, +tick: U32, s: S.State) -> IO(S.State):
  match n:
    case 0n: IO.pure(S.State,s)
    case 1n+k:
      +time = (U32.to_f32(tick) / 60.0 : F32)
      +grabbing = (tick >= 180 : U32) && (tick < 480 : U32)
      do IO<S.State>:
        s : S.State <- S.step(False{},0n,P.Controls{32,L.word(grabbing,528,4294967295),
          (F32.sin((time * 1.5 : F32)) * 1.4 : F32),(0.8 + F32.sin(time) * 0.8 : F32),
          (F32.cos(time) * 1.4 : F32),time,1.5},s)
        s : S.State <- snapshot(U32.is_eq((tick % 30 : U32),29),s)
        frames(k,(tick + 1 : U32),s)
def main() -> IO(Unit):
  do IO<Unit>:
    s : S.State <- Spatial.require(~S.State,S.create(5n))
    s : S.State <- frames(600n,0,s)
    return Unit{}
