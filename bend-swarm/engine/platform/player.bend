import Base
import ./viewport.bend as Viewport
import ../core/time.bend as Time
import ../render/hud.bend as Hud
import ../spatial/layout.bend as L

# Native presentation for small demos. State and rendering are caller-owned.
# Mouse coordinates are normalized to actual logical window dimensions.
type Input is Data:
  Input{gpu: Bool, paused: Bool, reset: Bool, quit: Bool, hud: Bool, preset: U32, seed: U32,
    mx: F32, my: F32, power: F32, time: F32, antialias: Bool, defocus: Bool, high: Bool}
type Metrics is Data:
  Metrics{simulation_us: U32, render_us: U32, count: U32}
def event(c: Input, e: Event, +sx: F32, +sy: F32) -> Input:
  Input{g,p,r,q,h,+v,s,x,y,f,t,aa,dof,high} = c
  match e:
    case Close{}: Input{g,p,r,True{},h,v,s,x,y,f,t,aa,dof,high}
    case Key{27,True{}}: Input{g,p,r,True{},h,v,s,x,y,f,t,aa,dof,high}
    case Key{32,True{}}: Input{g,Bool.not(p),r,q,h,v,s,x,y,f,t,aa,dof,high}
    case Key{103,True{}}: Input{Bool.not(g),p,r,q,h,v,s,x,y,f,t,aa,dof,high}
    case Key{97,True{}}: Input{g,p,r,q,h,v,s,x,y,f,t,Bool.not(aa),dof,high}
    case Key{113,True{}}: Input{g,p,r,q,h,v,s,x,y,f,t,aa,dof,Bool.not(high)}
    case Key{100,True{}}: Input{g,p,r,q,h,v,s,x,y,f,t,aa,Bool.not(dof),high}
    case Key{104,True{}}: Input{g,p,r,q,Bool.not(h),v,s,x,y,f,t,aa,dof,high}
    case Key{114,True{}}: Input{g,p,True{},q,h,v,(s + 1 : U32),x,y,f,0.0,aa,dof,high}
    case Key{49,True{}}: Input{g,p,True{},q,h,0,s,x,y,f,0.0,aa,dof,high}
    case Key{50,True{}}: Input{g,p,True{},q,h,1,s,x,y,f,0.0,aa,dof,high}
    case Key{51,True{}}: Input{g,p,True{},q,h,2,s,x,y,f,0.0,aa,dof,high}
    case Move{mx,my}: Input{g,p,r,q,h,v,s,(U32.to_f32(mx) * sx : F32),(U32.to_f32(my) * sy : F32),f,t,aa,dof,high}
    case Mouse{mx,my,button,down}:
      Input{g,p,r,q,h,v,s,(U32.to_f32(mx) * sx : F32),(U32.to_f32(my) * sy : F32),
        L.pick(down,L.pick(U32.is_eq(button,0),1.0,F32.neg(1.0)),0.0),t,aa,dof,high}
    case _: Input{g,p,r,q,h,v,s,x,y,f,t,aa,dof,high}
def events(es: List<Event>, +sx: F32, +sy: F32, c: Input) -> Input:
  match es:
    case Nil{}: c
    case e <> rest: events(rest,sx,sy,event(c,e,sx,sy))
def next(c: Input) -> Input:
  Input{g,+p,_,q,h,v,s,x,y,f,t,aa,dof,high} = c
  Input{g,p,False{},q,h,v,s,x,y,f,(t + L.pick(p,0.0,0.016666667) : F32),aa,dof,high}
def overlay(show: Bool, text: String, image: Image) -> Image:
  match show:
    case False{}: image
    case True{}: Hud.overlay(Hud.panel(text),image)
def pace(+start: Nat) -> IO(U32):
  do IO<U32>:
    end : Nat <- Time.micros()
    Unit <- IO.sleep(((16667 - U32.min(Time.elapsed(start,end),16667)) / 1000 : U32))
    end : Nat <- Time.micros()
    return Time.elapsed(start,end)
def caption(~title: String, refresh: Bool, dt: U32, w: Window) -> IO(Window):
  match refresh:
    case False{}: IO.pure(Window,w)
    case True{}: Window.set_title(w,title ++ " | " ++ U32.show((1000000 / U32.max(1,dt) : U32)) ++ " FPS | 1 2 3 scenes | R reset | SPACE pause | Q resolution | A edges | H details")
def presented(~S: Type, ~title: String, tick: U32, start: Nat, sx: F32, sy: F32, c: Input, state: S,
  r: Window & Image & List<Event>) -> IO(Window & S & Image & Input):
  (w,image,es) = r
  do IO<Window & S & Image & Input>:
    dt : U32 <- pace(start)
    w : Window <- caption(~title,U32.is_eq(U32.and(tick,15),0),dt,w)
    return (w,state,image,events(es,sx,sy,next(c)))
def show(~S: Type, ~title: String, ~help: String, tick: U32, start: Nat, sx: F32, sy: F32, +c: Input,
  w: Window, r: S & Image & Metrics) -> IO(Window & S & Image & Input):
  Input{gpu,_,_,_,h,_,_,_,_,_,_,aa,dof,high} = c
  (s,image,Metrics{sim,draw,count}) = r
  do IO<Window & S & Image & Input>:
    w : Window <- Viewport.resolution(w,Bool.pick(U32,high,2048,1024))
    result : Window & Image & List<Event> <- Window.frame(w,overlay(h,title ++ "\n" ++ Bool.pick(String,gpu,"METAL\n","CPU\n")
      ++ U32.show(count) ++ " ELEMENTS\n" ++ Bool.pick(String,high,"2048 PX\n","1024 PX\n") ++ "SIM " ++ U32.show((sim / 1000 : U32)) ++ " MS\nDRAW " ++ U32.show((draw / 1000 : U32)) ++ " MS\n" ++ help,image))
    presented(~S,~title,tick,start,sx,sy,c,s,result)
def reset(~S: Type, ~create: U32 -> U32 -> IO(S), on: Bool, preset: U32, seed: U32, s: S) -> IO(S):
  match on:
    case False{}: IO.pure(S,s)
    case True{}: create(preset,seed)
def loop(~S: Type, ~title: String, ~help: String, ~create: U32 -> U32 -> IO(S), ~frame: Input -> S -> Image -> IO(S & Image & Metrics),
  n: Nat, +tick: U32, +sx: F32, +sy: F32, r: Window & S & Image & Input) -> IO(Unit):
  match n:
    case 0n:
      (w,_,_,_) = r
      Window.close(w)
    case 1n+k:
      (w,s,image,+c) = r
      Input{_,_,restart,quit,_,preset,seed,_,_,_,_,aa,dof,high} = c
      match quit:
        case True{}: Window.close(w)
        case False{}:
          do IO<Unit>:
            start : Nat <- Time.micros()
            s : S <- reset(~S,~create,restart,preset,seed,s)
            f : S & Image & Metrics <- frame(c,s,image)
            r : Window & S & Image & Input <- show(~S,~title,~help,tick,start,sx,sy,c,w,f)
            loop(~S,~title,~help,~create,~frame,k,(tick + 1 : U32),sx,sy,r)
def started(~S: Type, ~title: String, ~help: String, ~create: U32 -> U32 -> IO(S), ~frame: Input -> S -> Image -> IO(S & Image & Metrics),
  gpu: Bool, aa: Bool, s: S, r: Window & U32 & U32) -> IO(Unit):
  (w,width,height) = r
  loop(~S,~title,~help,~create,~frame,4294967295n,0,(1.0 / U32.to_f32(width) : F32),(1.0 / U32.to_f32(height) : F32),
    (w,s,Pix{0},Input{gpu,False{},False{},False{},False{},1,42,0.5,0.5,0.0,0.0,aa,False{},False{}}))
def run(~S: Type, ~title: String, ~help: String, ~create: U32 -> U32 -> IO(S), ~frame: Input -> S -> Image -> IO(S & Image & Metrics),gpu: Bool, aa: Bool) -> IO(Unit):
  do IO<Unit>:
    w : Window <- IO.try(Window,Window.open(title,1024,1024))
    s : S <- create(1,42)
    r : Window & U32 & U32 <- Viewport.dimensions(w)
    started(~S,~title,~help,~create,~frame,gpu,aa,s,r)
