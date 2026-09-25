import Base
import ../demos/life/simulation.bend as S

def row(i: U32, r: Array<S.Particle> & S.Particle) -> IO(Array<S.Particle>):
  (a,S.Particle{x,y,vx,vy}) = r
  do IO<Array<S.Particle>>:
    Unit <- IO.print(U32.show(i) ++ "," ++ F32.show(x) ++ "," ++ F32.show(y) ++ "," ++ F32.show(vx) ++ "," ++ F32.show(vy))
    return a
def rows(n: Nat, +i: U32, a: Array<S.Particle>) -> IO(Array<S.Particle>):
  match n:
    case 0n: IO.pure(Array<S.Particle>,a)
    case 1n+k:
      do IO<Array<S.Particle>>:
        a : Array<S.Particle> <- row(i,Array.get(S.Particle,a,i))
        rows(k,(i + 1 : U32),a)
def output(s: S.State) -> IO(S.State):
  S.State{a,b,index} = s
  do IO<S.State>:
    a : Array<S.Particle> <- rows(8192n,0,a)
    return S.State{a,b,index}
def frames(n: Nat, s: S.State) -> IO(S.State):
  match n:
    case 0n: IO.pure(S.State,s)
    case 1n+k:
      do IO<S.State>:
        s : S.State <- S.step(True{},S.Controls{1,42,0.0,0.0,0.0},s)
        frames(k,s)
def main() -> IO(Unit):
  do IO<Unit>:
    s : S.State <- S.create(42)
    s : S.State <- frames(600n,s)
    s : S.State <- output(s)
    s : S.State <- frames(1n,s)
    s : S.State <- output(s)
    return Unit{}
