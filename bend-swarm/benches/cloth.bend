import Base
import ../demos/cloth/frame.bend as F
import ../demos/cloth/physics.bend as P
import ../engine/core/time.bend as Time

def report(on: Bool, total: U32, f: F.Frame) -> IO(F.Frame):
  match on:
    case False{}: IO.pure(F.Frame,f)
    case True{}:
      F.Frame{s,t,g,p,i,+sim,+draw} = f
      do IO<F.Frame>:
        Unit <- IO.print(U32.show(sim) ++ "," ++ U32.show(draw) ++ "," ++ U32.show(total))
        return F.Frame{s,t,g,p,i,sim,draw}

def frames_depth(+depth: Nat, n: Nat, +tick: U32, +reporting: Bool, f: F.Frame) -> IO(F.Frame):
  match n:
    case 0n: IO.pure(F.Frame,f)
    case 1n+k:
      do IO<F.Frame>:
        start : Nat <- Time.micros()
        f : F.Frame <- F.step_depth(True{},depth,False{},P.Controls{32,4294967295,0.0,0.0,0.0,(U32.to_f32(tick) / 60.0 : F32),1.5},f)
        end : Nat <- Time.micros()
        f : F.Frame <- report(reporting,Time.elapsed(start,end),f)
        frames_depth(depth,k,(tick + 1 : U32),reporting,f)

def frames(n: Nat, tick: U32, reporting: Bool, f: F.Frame) -> IO(F.Frame):
  frames_depth(10n,n,tick,reporting,f)

def bench(+depth: Nat, +warm: Nat, samples: Nat) -> IO(Unit):
  do IO<Unit>:
    f : F.Frame <- F.create(5n)
    f : F.Frame <- frames_depth(depth,warm,0,False{},f)
    Unit <- IO.print("simulation_us,render_us,frame_us")
    f : F.Frame <- frames_depth(depth,samples,U32.from_nat(warm),True{},f)
    return Unit{}

def number(fallback: Nat, r: Maybe<&2,U32>) -> Nat:
  match r:
    case None{}: fallback
    case Some{n}: U32.to_nat(n)

def args(xs: List<String>) -> IO(Unit):
  match xs:
    case depth <> warm <> samples <> Nil{}:
      bench(number(10n,U32.read(depth)),number(120n,U32.read(warm)),number(600n,U32.read(samples)))
    case _: bench(10n,120n,600n)

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- IO.args()
    args(xs)
