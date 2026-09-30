import Base
import ../engine/platform/arguments.bend as Arguments
import ../demos/cloth/main.bend as App
import ../demos/cloth/frame.bend as F
import ../engine/core/time.bend as Time
import ./cloth.bend as B
import ../engine/render/post.bend as Post

def report(on: Bool, elapsed: U32, r: Window & F.Frame & App.Controls) -> IO(Window & F.Frame & App.Controls):
  match on:
    case False{}: IO.pure(Window & F.Frame & App.Controls,r)
    case True{}:
      (w,F.Frame{s,t,index,p,b,image,+sim,+draw},c) = r
      do IO<Window & F.Frame & App.Controls>:
        Unit <- IO.print(U32.show(sim) ++ "," ++ U32.show(draw) ++ "," ++ U32.show(elapsed))
        return (w,F.Frame{s,t,index,p,b,image,sim,draw},c)
def frames(+controls: App.Controls, n: Nat, +tick: U32, r: Window & F.Frame & App.Controls) -> IO(Unit):
  match n:
    case 0n:
      (w,_,_) = r
      Window.close(w)
    case 1n+k:
      (w,f,_) = r
      do IO<Unit>:
        +start : Nat <- Time.micros()
        r : Window & F.Frame & App.Controls <- App.advance(tick,(tick * 2 : U32),2,start,w,(f,controls))
        end : Nat <- Time.micros()
        r : Window & F.Frame & App.Controls <- report((tick >= 120 : U32),Time.elapsed(start,end),r)
        frames(controls,k,(tick + 1 : U32),r)
def bench_effects(gpu: Bool, +high: Bool, settings: Post.Settings) -> IO(Unit):
  Post.Settings{aa,dof,_,_} = settings
  +controls : App.Controls = App.Controls{gpu,False{},False{},False{},True{},True{},256.0,256.0,False{},4294967295,7.5,0.5,0.5,high,aa,dof}
  do IO<Unit>:
    w : Window <- IO.try(Window,Window.open("BEND CLOTH | display benchmark",1024,1024))
    f : F.Frame <- F.create(Bool.pick(Nat,high,6n,5n))
    Unit <- IO.print("simulation_us,render_us,frame_us")
    frames(controls,720n,0,(w,f,controls))

def bench(high: Bool) -> IO(Unit):
  bench_effects(False{},high,B.effects("raw"))
def quality(q: String) -> Bool:
  match q:
    case "standard": False{}
    case _: True{}
def backend(q: String) -> Bool:
  match q:
    case "cpu": False{}
    case _: True{}


def args(xs: List<String>) -> IO(Unit):
  match xs:
    case mode <> size <> effect <> Nil{}: bench_effects(backend(mode),quality(size),B.effects(effect))
    case "standard" <> Nil{}: bench(False{})
    case _: bench(True{})
def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- Arguments.read()
    args(xs)
