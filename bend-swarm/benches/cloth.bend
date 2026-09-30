import Base
import ../engine/platform/arguments.bend as Arguments
import ../demos/cloth/frame.bend as F
import ../demos/cloth/physics.bend as P
import ../engine/core/time.bend as Time
import ../engine/render/post.bend as Post

def report(on: Bool, total: U32, f: F.Frame) -> IO(F.Frame):
  match on:
    case False{}: IO.pure(F.Frame,f)
    case True{}:
      F.Frame{s,t,g,p,b,i,+sim,+draw} = f
      do IO<F.Frame>:
        Unit <- IO.print(U32.show(sim) ++ "," ++ U32.show(draw) ++ "," ++ U32.show(total))
        return F.Frame{s,t,g,p,b,i,sim,draw}

def frames_effects(+settings: Post.Settings, +render_gpu: Bool, +depth: Nat, n: Nat, +tick: U32, +reporting: Bool, f: F.Frame) -> IO(F.Frame):
  match n:
    case 0n: IO.pure(F.Frame,f)
    case 1n+k:
      do IO<F.Frame>:
        start : Nat <- Time.micros()
        f : F.Frame <- F.step_effects(settings,Nat.is_ne(depth,0n),render_gpu,depth,False{},2n,P.Controls{32,4294967295,0.0,0.0,0.0,(U32.to_f32(tick) / 60.0 : F32),1.5},f)
        end : Nat <- Time.micros()
        f : F.Frame <- report(reporting,Time.elapsed(start,end),f)
        frames_effects(settings,render_gpu,depth,k,(tick + 1 : U32),reporting,f)

def frames_render(render_gpu: Bool, depth: Nat, n: Nat, tick: U32, reporting: Bool, f: F.Frame) -> IO(F.Frame):
  frames_effects(Post.Settings{False{},False{},7.5,4.0},render_gpu,depth,n,tick,reporting,f)

def frames_depth(+depth: Nat, n: Nat, tick: U32, reporting: Bool, f: F.Frame) -> IO(F.Frame):
  frames_render(Nat.is_ne(depth,0n),depth,n,tick,reporting,f)

def frames(n: Nat, tick: U32, reporting: Bool, f: F.Frame) -> IO(F.Frame):
  frames_depth(10n,n,tick,reporting,f)

def bench_effects(+settings: Post.Settings, +render_gpu: Bool, bits: Nat, +depth: Nat, +warm: Nat, samples: Nat) -> IO(Unit):
  do IO<Unit>:
    f : F.Frame <- F.create(bits)
    f : F.Frame <- frames_effects(settings,render_gpu,depth,warm,0,False{},f)
    Unit <- IO.print("simulation_us,render_us,frame_us")
    f : F.Frame <- frames_effects(settings,render_gpu,depth,samples,U32.from_nat(warm),True{},f)
    return Unit{}

def bench_render(render_gpu: Bool, bits: Nat, depth: Nat, warm: Nat, samples: Nat) -> IO(Unit):
  bench_effects(Post.Settings{False{},False{},7.5,4.0},render_gpu,bits,depth,warm,samples)

def bench_size(bits: Nat, +depth: Nat, warm: Nat, samples: Nat) -> IO(Unit):
  bench_render(Nat.is_ne(depth,0n),bits,depth,warm,samples)

def bench(depth: Nat, warm: Nat, samples: Nat) -> IO(Unit):
  bench_size(5n,depth,warm,samples)

def number(fallback: Nat, r: Maybe<&2,U32>) -> Nat:
  match r:
    case None{}: fallback
    case Some{n}: U32.to_nat(n)

def effects(mode: String) -> Post.Settings:
  match mode:
    case "raw": Post.Settings{False{},False{},7.5,4.0}
    case "dof": Post.Settings{True{},True{},7.5,4.0}
    case _: Post.Settings{True{},False{},7.5,4.0}
def configured(mode: String, settings: Post.Settings, bits: Nat, warm: Nat, samples: Nat) -> IO(Unit):
  match mode:
    case "cpu": bench_effects(settings,False{},bits,0n,warm,samples)
    case "hybrid": bench_effects(settings,True{},bits,0n,warm,samples)
    case _: bench_effects(settings,True{},bits,10n,warm,samples)

def args(xs: List<String>) -> IO(Unit):
  match xs:
    case mode <> bits <> quality <> warm <> samples <> Nil{}:
      configured(mode,effects(quality),number(5n,U32.read(bits)),number(120n,U32.read(warm)),number(600n,U32.read(samples)))
    case "hybrid" <> Nil{}: bench_render(True{},6n,0n,120n,600n)
    case bits <> depth <> warm <> samples <> Nil{}:
      bench_size(number(5n,U32.read(bits)),number(10n,U32.read(depth)),number(120n,U32.read(warm)),number(600n,U32.read(samples)))
    case depth <> warm <> samples <> Nil{}:
      bench(number(10n,U32.read(depth)),number(120n,U32.read(warm)),number(600n,U32.read(samples)))
    case _: bench(10n,120n,600n)

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- Arguments.read()
    args(xs)
