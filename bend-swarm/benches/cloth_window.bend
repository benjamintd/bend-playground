import Base
import ../demos/cloth/main.bend as App
import ../demos/cloth/frame.bend as F
import ../engine/core/time.bend as Time

def report(on: Bool, elapsed: U32, r: Window & F.Frame & App.Controls) -> IO(Window & F.Frame & App.Controls):
  match on:
    case False{}: IO.pure(Window & F.Frame & App.Controls,r)
    case True{}:
      (w,F.Frame{s,t,index,p,b,image,+sim,+draw},c) = r
      do IO<Window & F.Frame & App.Controls>:
        Unit <- IO.print(U32.show(sim) ++ "," ++ U32.show(draw) ++ "," ++ U32.show(elapsed))
        return (w,F.Frame{s,t,index,p,b,image,sim,draw},c)
def frames(+high: Bool, n: Nat, +tick: U32, r: Window & F.Frame & App.Controls) -> IO(Unit):
  match n:
    case 0n:
      (w,_,_) = r
      Window.close(w)
    case 1n+k:
      (w,f,_) = r
      do IO<Unit>:
        +start : Nat <- Time.micros()
        r : Window & F.Frame & App.Controls <- App.advance(tick,(tick * 2 : U32),2,start,w,(f,App.Controls{False{},False{},False{},False{},True{},True{},256.0,256.0,False{},4294967295,7.5,0.5,0.5,high}))
        end : Nat <- Time.micros()
        r : Window & F.Frame & App.Controls <- report((tick >= 120 : U32),Time.elapsed(start,end),r)
        frames(high,k,(tick + 1 : U32),r)
def bench(+high: Bool) -> IO(Unit):
  do IO<Unit>:
    w : Window <- IO.try(Window,Window.open("BEND CLOTH | display benchmark",1024,1024))
    f : F.Frame <- F.create(Bool.pick(Nat,high,6n,5n))
    Unit <- IO.print("simulation_us,render_us,frame_us")
    frames(high,720n,0,(w,f,App.Controls{False{},False{},False{},False{},True{},True{},256.0,256.0,False{},4294967295,7.5,0.5,0.5,high}))


def args(xs: List<String>) -> IO(Unit):
  match xs:
    case "standard" <> Nil{}: bench(False{})
    case _: bench(True{})
def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- IO.args()
    args(xs)
