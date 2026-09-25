import Base
import ../demos/cloth/world.bend as W
import ../demos/cloth/physics.bend as P
import ../demos/cloth/simulation.bend as S
import ../engine/spatial.bend as Spatial
import ../engine/spatial/layout.bend as L

def frames(n: Nat, +side: U32, +tick: U32, s: S.State) -> IO(S.State):
  match n:
    case 0n: IO.pure(S.State,s)
    case 1n+k:
      do IO<S.State>:
        s : S.State <- S.step(True{},6n,P.Controls{side,4294967295,0.0,0.0,0.0,(U32.to_f32(tick) / 60.0 : F32),1.5},s)
        frames(k,side,(tick + 1 : U32),s)

def row(r: W.Positions & L.Point) -> IO(W.Positions):
  (p,L.Point{x,y,z}) = r
  do IO<W.Positions>:
    Unit <- IO.print(F32.show(x) ++ "," ++ F32.show(y) ++ "," ++ F32.show(z))
    return p

def output(n: Nat, +i: U32, p: W.Positions) -> IO(Unit):
  match n:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+k:
      do IO<Unit>:
        p : W.Positions <- row(W.read(i,p))
        output(k,(i + 1 : U32),p)

def result(s: S.State) -> IO(Unit):
  S.State{+side,p,_,_,_,_,_} = s
  output(U32.to_nat((side * side : U32)),0,p)

def run(+bits: Nat, steps: Nat) -> IO(Unit):
  do IO<Unit>:
    s : S.State <- Spatial.require(~S.State,S.create(bits))
    s : S.State <- frames(steps,U32.shln(1,bits),0,s)
    result(s)

def main() -> IO(Unit):
  do IO<Unit>:
    Unit <- run(3n,1n)
    Unit <- run(3n,180n)
    Unit <- run(5n,1n)
    run(5n,180n)
