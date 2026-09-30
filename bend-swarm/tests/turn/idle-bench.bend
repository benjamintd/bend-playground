import Base
import ../../demos/turn/main.bend as App
import ../../demos/turn/play.bend as P
import ../../demos/turn/render.bend as R
import ../../engine/core/time.bend as Time
import ../../engine/platform/arguments.bend as Arguments
import ../../engine/platform/viewport.bend as Viewport
import ./window-control.bend as Host

# Exact pre-fix scheduling policy, sharing the unchanged renderer and physics.
def legacy(s: App.Session) -> IO(App.Session):
  App.Session{w,renderer,image,p,_,_,previous,_} = s
  do IO<App.Session>:
    +start : Nat <- Time.micros()
    +next : P.Play = P.tick((U32.to_f32(Time.elapsed(previous,start)) / 1000000.0 : F32),p)
    result : App.Session <- App.present(w,next,start,R.frame(False{},next,renderer,image))
    end : Nat <- Time.micros()
    Unit <- IO.sleep(((16667 - U32.min(Time.elapsed(start,end),16667)) / 1000 : U32))
    return result
def step(optimized: Bool, s: App.Session) -> IO(App.Session):
  match optimized:
    case False{}: legacy(s)
    case True{}:
      do IO<App.Session>:
        next : App.Session <- App.poll(s)
        App.checked(next)
def finish(start: Nat, cpu: Nat, drawn: U32, loops: U32, previous: Nat, s: App.Session) -> IO(Unit):
  App.Session{w,_,_,P.Play{_,_,_,_,_,clock,_,_,_,_,_,_,_,_,_,pace,hints},active,_,_,last} = s
  +frames = (drawn + Bool.to_u32(Bool.not(Nat.is_eq(previous,last))) : U32)
  do IO<Unit>:
    end : Nat <- Time.micros()
    used : Nat <- Host.cpu_micros()
    Unit <- IO.print(U32.show(Time.elapsed(start,end)) ++ "," ++ U32.show(Time.elapsed(cpu,used)) ++ ","
      ++ U32.show(frames) ++ "," ++ U32.show(loops) ++ "," ++ U32.show(clock) ++ "," ++ U32.show(Bool.to_u32(active)))
    Window.close(w)
def timed(start: Nat, s: App.Session) -> Bool & App.Session:
  App.Session{w,r,image,p,active,dirty,+now,last} = s
  ((Time.elapsed(start,now) >= 5000000 : U32),App.Session{w,r,image,p,active,dirty,now,last})
def frames(n: Nat, +optimized: Bool, +start: Nat, cpu: Nat, drawn: U32, loops: U32, previous: Nat, result: Bool & App.Session) -> IO(Unit):
  match n:
    case 0n:
      (_,s) = result
      finish(start,cpu,drawn,loops,previous,s)
    case 1n+k:
      (done,s) = result
      match done:
        case True{}: finish(start,cpu,drawn,loops,previous,s)
        case False{}:
          App.Session{w,r,image,p,active,dirty,now,+last} = s
          count = (drawn + Bool.to_u32(Bool.not(Nat.is_eq(previous,last))) : U32)
          do IO<Unit>:
            next : App.Session <- step(optimized,App.Session{w,r,image,p,active,dirty,now,last})
            frames(k,optimized,start,cpu,count,(loops + 1 : U32),last,timed(start,next))
def prepared(+optimized: Bool, mode: U32, s: App.Session) -> IO(Unit):
  App.Session{w,renderer,image,p,_,_,_,_} = s
  do IO<Unit>:
    w : Window <- Host.action(w,mode)
    +now : Nat <- Time.micros()
    cpu : Nat <- Host.cpu_micros()
    frames(10000n,optimized,now,cpu,0,0,now,(False{},App.Session{w,renderer,image,p,True{},False{},now,now}))
def run(optimized: Bool, menu: Bool, mode: U32) -> IO(Unit):
  do IO<Unit>:
    w : Window <- IO.try(Window,Window.open("TURN idle measurement",760,760))
    w : Window <- Viewport.resolution(w,1024)
    +now : Nat <- Time.micros()
    +p : P.Play = Bool.pick(P.Play,menu,P.toggle(P.create(0)),P.create(0))
    ready : App.Session <- App.present(w,p,now,R.frame(False{},p,R.create(),Pix{0}))
    prepared(optimized,mode,ready)
def mode(optimized: Bool, name: String) -> IO(Unit):
  match name:
    case "idle": run(optimized,False{},3)
    case "menu": run(optimized,True{},3)
    case "background": run(optimized,False{},0)
    case "hidden": run(optimized,False{},1)
    case "minimized": run(optimized,False{},2)
    case _: IO.die(Unit,64,"expected idle/menu/background/hidden/minimized")
def args(xs: List<String>) -> IO(Unit):
  match xs:
    case "before" <> name <> Nil{}: mode(False{},name)
    case "after" <> name <> Nil{}: mode(True{},name)
    case _: IO.die(Unit,64,"expected before|after CASE")
def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- Arguments.read()
    args(xs)
