import Base
import ../engine/platform/arguments.bend as Arguments
import ../demos/swarm/pipeline.bend as P

def num(default: Nat, value: Maybe<&2, U32>) -> Nat:
  match value:
    case None{}: default
    case Some{n}: U32.to_nat(n)

def bench(depth: Nat, fork: Nat, warm: Nat, samples: Nat) -> IO(Unit):
  +f = fork
  do IO<Unit>:
    state : P.Frame = P.create(depth)
    state : P.Frame <- P.frames(warm, True{}, f, state, False{})
    Unit <- IO.print("histogram_us,scan_us,scatter_us,simulation_us,screen_binning_us,render_us,frame_us,candidates")
    state : P.Frame <- P.frames(samples, True{}, f, state, True{})
    return Unit{}

def args(xs: List<String>) -> IO(Unit):
  match xs:
    case a <> b <> c <> d <> Nil{}:
      bench(num(17n, U32.read(a)),num(12n,U32.read(b)),num(120n,U32.read(c)),num(600n,U32.read(d)))
    case _:
      IO.die(Unit, 2, "usage: full-frame [runtime options] -- log2_agents fork_depth warmup samples")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- Arguments.read()
    args(xs)
