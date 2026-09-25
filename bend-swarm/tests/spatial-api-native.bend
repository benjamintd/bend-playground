import Base
import ./spatial-api.bend as T
import ../engine/spatial/layout.bend as L
import ../engine/spatial/internal/stencil.bend as K

# Integer-quarter coordinates avoid ambiguous radius-boundary rounding.
def fixture(n: Nat, +i: U32, p: T.Points) -> T.Points:
  match n:
    case 0n: p
    case 1n+rest:
      T.Points{x,y,z} = p
      fixture(rest,(i + 1 : U32),T.Points{
        Array.set(F32,x,i,(U32.to_f32((i * 17 % 31 : U32)) / 4.0 - 4.0 : F32)),
        Array.set(F32,y,i,(U32.to_f32((i * 11 % 29 : U32)) / 4.0 - 4.0 : F32)),
        Array.set(F32,z,i,(U32.to_f32((i * 7 % 37 : U32)) / 4.0 - 4.0 : F32))})

def points() -> T.Points:
  fixture(32n,0,T.Points{Array.new(F32,5n,0.0),Array.new(F32,5n,0.0),Array.new(F32,5n,0.0)})

def printed(r: Array<U32> & U32) -> IO(Array<U32>):
  (a,x) = r
  do IO<Array<U32>>:
    Unit <- IO.print(U32.show(x))
    return a

def output(n: Nat, +i: U32, a: Array<U32>) -> IO(Unit):
  match n:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+p:
      do IO<Unit>:
        a : Array<U32> <- printed(Array.get(U32,a,i))
        output(p,(i + 1 : U32),a)

def report(~space: L.Layout, r: Result<String,K.Step<space,T.Points,Array<U32>>>) -> IO(Unit):
  match r:
    case Fail{message}: IO.die(Unit,2,message)
    case Done{K.Step{_,out,checks,neighbors}}:
      do IO<Unit>:
        Unit <- IO.print(Nat.show(checks) ++ "," ++ Nat.show(neighbors))
        output(32n,0,out)

def main() -> IO(Unit):
  do IO<Unit>:
    Unit <- report(~T.periodic2(),T.periodic(True{},32,2.4,False{},points()))
    Unit <- report(~T.bounded3(),T.bounded(True{},32,2.4,False{},points()))
    Unit <- report(~T.tiny3(),T.tiny(True{},13,10.0,True{},points()))
    Unit <- report(~T.tiny3(),T.tiny(True{},0,0.0,True{},points()))
    return Unit{}
