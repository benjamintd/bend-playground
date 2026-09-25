import Base
import ./pipeline.bend as P
import ./points.bend as Points
import ./world.bend as W
import ../../engine/render/hud.bend as Hud
import ../../engine/core/time.bend as Time
import ../../engine/parallel/plan.bend as Plan

# Window effects retain the image for reclamation inside the next tile tree.
type Controls is Data:
  Controls{gpu: Bool, paused: Bool, depth: Nat, reset: Bool, quit: Bool,
    mx: F32, my: F32, power: F32, hud: Bool}

def mouse_power(button: U32, down: Bool) -> F32:
  match down:
    case False{}: 0.0
    case True{}:
      Bool.pick(F32,U32.is_eq(button,0),70.0,F32.neg(70.0))

def event(e: Event, c: Controls) -> Controls:
  match e:
    case Close{}:
      Controls{g,p,d,r,q,x,y,force,h} = c
      Controls{g,p,d,r,True{},x,y,force,h}
    case Key{27, True{}}:
      Controls{g,p,d,r,q,x,y,force,h} = c
      Controls{g,p,d,r,True{},x,y,force,h}
    case Key{103, True{}}:
      Controls{g,p,d,r,q,x,y,force,h} = c
      Controls{Bool.not(g),p,d,r,q,x,y,force,h}
    case Key{32, True{}}:
      Controls{g,p,d,r,q,x,y,force,h} = c
      Controls{g,Bool.not(p),d,r,q,x,y,force,h}
    case Key{114, True{}}:
      Controls{g,p,d,r,q,x,y,force,h} = c
      Controls{g,p,d,True{},q,x,y,force,h}
    case Key{104, True{}}:
      Controls{g,p,d,r,q,x,y,force,h} = c
      Controls{g,p,d,r,q,x,y,force,Bool.not(h)}
    case Key{93, True{}}:
      Controls{g,p,d,r,q,x,y,force,h} = c
      Controls{g,p,Nat.min(20n,1n+d),True{},q,x,y,force,h}
    case Key{91, True{}}:
      Controls{g,p,d,r,q,x,y,force,h} = c
      Controls{g,p,Nat.max(10n,Nat.sub(d,1n)),True{},q,x,y,force,h}
    case Move{mx,my}:
      Controls{g,p,d,r,q,x,y,force,h} = c
      Controls{g,p,d,r,q,U32.to_f32(mx),U32.to_f32(my),force,h}
    case Mouse{mx,my,button,down}:
      Controls{g,p,d,r,q,x,y,force,h} = c
      Controls{g,p,d,r,q,U32.to_f32(mx),U32.to_f32(my),mouse_power(button,down),h}
    case _: c

def events(xs: List<Event>, c: Controls) -> Controls:
  match xs:
    case Nil{}: c
    case e <> rest: events(rest,event(e,c))

def ms(n: U32) -> String:
  F32.show((U32.to_f32(n) / 1000.0 : F32))

def label(c: Controls, m: P.Metrics) -> String:
  Controls{g,p,d,_,_,_,_,_,_} = c
  P.Metrics{hist,scan,scatter,sim,bin,render,+total,checks} = m
  "BEND SWARM\n"
    ++ "AGENTS " ++ U32.show(U32.shln(1,d)) ++ "\n"
    ++ Bool.pick(String,g,"GPU METAL","CPU") ++ "\n"
    ++ Bool.pick(String,p,"PAUSED","FLOCKING") ++ "\n\n"
    ++ "GRID " ++ ms((hist + scan + scatter : U32)) ++ "\n"
    ++ "SIM  " ++ ms(sim) ++ "\n"
    ++ "BINS " ++ ms(bin) ++ "\n"
    ++ "DRAW " ++ ms(render) ++ "\n"
    ++ "STEP " ++ ms(total) ++ "\n"
    ++ "MS HEADLESS\n"
    ++ "DEPTH 14\n"
    ++ "G CPU/GPU\n"
    ++ "MOUSE ATTRACT\n"
    ++ "RIGHT REPEL\n"

def reset(on: Bool, d: Nat, f: P.Frame) -> P.Frame:
  match on:
    case True{}: P.create(d)
    case False{}: f

def redraw(+gpu: Bool, f: P.Frame) -> IO(P.Frame):
  P.Frame{scene,next,pixels,image,_} = f
  do IO<P.Frame>:
    scene : Points.Scene = Points.histogram(gpu,Plan.default_depth(),scene)
    barrier : Nat <- Time.micros()
    scene : Points.Scene = Points.scan(scene)
    barrier : Nat <- Time.micros()
    scene : Points.Scene = Points.scatter(gpu,Plan.default_depth(),scene)
    barrier : Nat <- Time.micros()
    return P.from_points(next,Points.render(gpu,scene,pixels,image))

def advance(paused: Bool, gpu: Bool, mx: F32, my: F32, power: F32, f: P.Frame) -> IO(P.Frame):
  match paused:
    case True{}: redraw(gpu,f)
    case False{}: P.step(gpu,Plan.default_depth(),mx,my,power,f)

def caption(refresh: Bool, elapsed: U32, w: Window) -> IO(Window):
  match refresh:
    case False{}: IO.pure(Window,w)
    case True{}:
      Window.set_title(w,"BEND SWARM | " ++ U32.show((1000000 / U32.max(elapsed,1) : U32))
        ++ " FPS incl. display | G backend | SPACE pause | R reset | [ ] population | H HUD")

def shown(tick: U32, frame_us: U32, scene: Points.Scene, next: W.World, pixels: Array<U32>,
  +metrics: P.Metrics, c: Controls, r: Window & Image & List<Event>) -> IO(Window & P.Frame & Controls):
  (w,image,es) = r
  do IO<Window & P.Frame & Controls>:
    w : Window <- caption(U32.is_eq(U32.and(tick,15),0),frame_us,w)
    return (w,P.Frame{scene,next,pixels,image,metrics},events(es,c))

def overlay(on: Bool, text: String, img: Image) -> Image:
  match on:
    case True{}: Hud.overlay(Hud.panel(text),img)
    case False{}: img

def show(tick: U32, start: Nat, +c: Controls, w: Window, f: P.Frame) -> IO(Window & P.Frame & Controls):
  Controls{_,_,_,_,_,_,_,_,h} = c
  P.Frame{scene,next,pixels,image,+metrics} = f
  do IO<Window & P.Frame & Controls>:
    result : Window & Image & List<Event> <- Window.frame(w,overlay(h,label(c,metrics),image))
    end : Nat <- Time.micros()
    shown(tick,Time.elapsed(start,end),scene,next,pixels,metrics,c,result)

def loop(n: Nat, +tick: U32, r: Window & P.Frame & Controls) -> IO(Unit):
  match n:
    case 0n:
      (w,_,_) = r
      Window.close(w)
    case 1n+p:
      (w,f,Controls{+gpu,+paused,+depth,restart,quit,+mx,+my,+power,+hud}) = r
      match quit:
        case True{}: Window.close(w)
        case False{}:
          do IO<Unit>:
            start : Nat <- Time.micros()
            f : P.Frame <- advance(paused,gpu,mx,my,power,reset(restart,depth,f))
            r : Window & P.Frame & Controls <- show(tick,start,Controls{gpu,paused,depth,False{},False{},mx,my,power,hud},w,f)
            loop(p,(tick + 1 : U32),r)

def main() -> IO(Unit):
  do IO<Unit>:
    w : Window <- IO.try(Window,Window.open("BEND SWARM | G backend | SPACE pause | R reset | [ ] population | H HUD",1024,1024))
    loop(4294967295n,0,(w,P.create(17n),Controls{True{},False{},17n,False{},False{},512.0,512.0,0.0,True{}}))
