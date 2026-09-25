import Base
import ./frame.bend as F
import ./simulation.bend as S
import ./physics.bend as P
import ./world.bend as W
import ./surface.bend as Surface
import ./view.bend as V
import ./input.bend as Input
import ../../engine/platform/viewport.bend as Viewport
import ../../engine/spatial.bend as Spatial
import ../../engine/spatial/layout.bend as L
import ../../engine/render/mesh.bend as M
import ../../engine/render/hud.bend as Hud
import ../../engine/core/time.bend as Time

type Controls is Data:
  Controls{gpu: Bool, paused: Bool, reset: Bool, quit: Bool, wind: Bool, hud: Bool,
    mx: F32, my: F32, picking: Bool, grab: U32, grab_depth: F32, scale_x: F32, scale_y: F32, high: Bool}

def event(e: Event, c: Controls) -> Controls:
  match e:
    case Close{}:
      Controls{g,p,r,_,w,h,x,y,k,i,d, +sx, +sy, +high} = c
      Controls{g,p,r,True{},w,h,x,y,k,i,d, sx, sy, high}
    case Key{27,True{}}:
      Controls{g,p,r,_,w,h,x,y,k,i,d, +sx, +sy, +high} = c
      Controls{g,p,r,True{},w,h,x,y,k,i,d, sx, sy, high}
    case Key{103,True{}}:
      Controls{g,p,r,q,w,h,x,y,k,i,d, +sx, +sy, +high} = c
      Controls{Bool.not(g),p,r,q,w,h,x,y,k,i,d, sx, sy, high}
    case Key{32,True{}}:
      Controls{g,p,r,q,w,h,x,y,k,i,d, +sx, +sy, +high} = c
      Controls{g,Bool.not(p),r,q,w,h,x,y,k,i,d, sx, sy, high}
    case Key{114,True{}}:
      Controls{g,p,_,q,w,h,x,y,_,_,d, +sx, +sy, +high} = c
      Controls{g,p,True{},q,w,h,x,y,False{},4294967295,d, sx, sy, high}
    case Key{119,True{}}:
      Controls{g,p,r,q,w,h,x,y,k,i,d, +sx, +sy, +high} = c
      Controls{g,p,r,q,Bool.not(w),h,x,y,k,i,d, sx, sy, high}
    case Key{113,True{}}:
      Controls{g,p,_,q,w,h,x,y,_,_,d,sx,sy,high} = c
      Controls{g,p,True{},q,w,h,x,y,False{},4294967295,d,sx,sy,Bool.not(high)}
    case Key{104,True{}}:
      Controls{g,p,r,q,w,h,x,y,k,i,d, +sx, +sy, +high} = c
      Controls{g,p,r,q,w,Bool.not(h),x,y,k,i,d, sx, sy, high}
    case Move{mx,my}:
      Controls{g,p,r,q,w,h,_,_,k,i,d, +sx, +sy, +high} = c
      Controls{g,p,r,q,w,h,(U32.to_f32(mx) * sx : F32),(U32.to_f32(my) * sy : F32),k,i,d, sx, sy, high}
    case Mouse{mx,my,0,down}:
      Controls{g,p,r,q,w,h,_,_,_,_,d, +sx, +sy, +high} = c
      Controls{g,p,r,q,w,h,(U32.to_f32(mx) * sx : F32),(U32.to_f32(my) * sy : F32),down,4294967295,d, sx, sy, high}
    case _: c

def events(es: List<Event>, c: Controls) -> Controls:
  match es:
    case Nil{}: c
    case e <> rest: events(rest,event(e,c))

def selected(side: U32, previous: W.Positions, scratch: W.Positions, spatial: Spatial.Index(P.space()),
  samples: Array<Surface.Sample>, checks: Nat, neighbors: Nat, tris: Array<M.Triangle>, index: M.Index, pixels: Array<U32>, background: Array<M.Fragment>, image: Image,
  sim: U32, render: U32, c: Controls, r: W.Positions & Input.Pick) -> F.Frame & Controls:
  Controls{g,p,restart,q,w,h,x,y,_,_,_, +sx, +sy, +high} = c
  (current,Input.Pick{i,_,depth}) = r
  (F.Frame{S.State{side,current,previous,scratch,spatial,samples,checks,neighbors},tris,index,pixels,background,image,sim,render},
    Controls{g,p,restart,q,w,h,x,y,False{},i,depth, sx, sy, high})

def select(on: Bool, x: F32, y: F32, c: Controls, f: F.Frame) -> F.Frame & Controls:
  match on:
    case False{}: (f,c)
    case True{}:
      F.Frame{S.State{+side,current,previous,scratch,spatial,samples,checks,neighbors},tris,index,pixels,background,image,sim,render} = f
      selected(side,previous,scratch,spatial,samples,checks,neighbors,tris,index,pixels,background,image,sim,render,c,
        Input.pick((side * side : U32),x,y,current))

# Resolve a press before subsequent movement in the same event batch. Waiting
# until the batch ended could attempt to pick at a point already off the cloth.
def select_current(r: F.Frame & Controls) -> F.Frame & Controls:
  (f,+c) = r
  Controls{_,_,_,_,_,_,x,y,pick,_,_,_,_,_} = c
  select(pick,x,y,c,f)
def event_frame(e: Event, r: F.Frame & Controls) -> F.Frame & Controls:
  (f,c) = r
  select_current((f,event(e,c)))
def events_frame(es: List<Event>, r: F.Frame & Controls) -> F.Frame & Controls:
  match es:
    case Nil{}: r
    case e <> rest: events_frame(rest,event_frame(e,r))
def window_events(w: Window, r: F.Frame & Controls) -> Window & F.Frame & Controls:
  (f,c) = r
  (w,f,c)

def physical(side: U32, time: F32, wind: Bool, id: U32, target: L.Point) -> P.Controls:
  L.Point{x,y,z} = target
  P.Controls{side,id,F32.max(F32.neg(3.5),F32.min(3.5,x)),F32.max(F32.neg(1.5),F32.min(3.0,y)),
    F32.max(F32.neg(3.5),F32.min(3.5,z)),time,L.pick(wind,1.5,0.0)}

def caption(refresh: Bool, us: U32, w: Window) -> IO(Window):
  match refresh:
    case False{}: IO.pure(Window,w)
    case True{}: Window.set_title(w,"BEND CLOTH | " ++ U32.show((1000000 / U32.max(us,1) : U32))
      ++ " FPS | drag fabric | SPACE pause | R reset | W wind | G CPU/GPU | Q quality | H details")

def milliseconds(us: U32) -> String:
  +tenths = (us / 100 : U32)
  U32.show((tenths / 10 : U32)) ++ "." ++ U32.show((tenths % 10 : U32))
def label(c: Controls, sim: U32, render: U32) -> String:
  Controls{g,p,_,_,wind,_,_,_,_,grab,_,_,_,high} = c
  "BEND CLOTH\n" ++ Bool.pick(String,g,"METAL\n","CPU\n")
    ++ "1024 SIM POINTS\n" ++ Bool.pick(String,high,"7938 TRIANGLES\n1024 PIXELS\n","1922 TRIANGLES\n512 PIXELS\n")
    ++ "SIM " ++ milliseconds(sim) ++ " MS\nDRAW " ++ milliseconds(render) ++ " MS\n"
    ++ Bool.pick(String,p,"PAUSED\n",Bool.pick(String,U32.is_ne(grab,4294967295),"PULLING\n","DRAG TO PULL\n"))
    ++ "SPACE PAUSE\nR RESET\nW WIND\nG BACKEND\nQ QUALITY\nH DETAILS"

def overlay(on: Bool, text: String, image: Image) -> Image:
  match on:
    case False{}: image
    case True{}: Hud.overlay(Hud.panel(text),image)

# Cap presentation at 60 Hz. Simulation uses elapsed time independently below.
def pace(start: Nat) -> IO(Unit):
  do IO<Unit>:
    end : Nat <- Time.micros()
    IO.sleep(((16667 - U32.min(Time.elapsed(start,end),16667)) / 1000 : U32))

def displayed(tick: U32, +start: Nat, state: S.State, tris: Array<M.Triangle>, index: M.Index, pixels: Array<U32>, background: Array<M.Fragment>,
  sim: U32, render: U32, c: Controls, r: Window & Image & List<Event>) -> IO(Window & F.Frame & Controls):
  (w,image,es) = r
  do IO<Window & F.Frame & Controls>:
    Unit <- pace(start)
    end : Nat <- Time.micros()
    w : Window <- caption(U32.is_eq(U32.and(tick,15),0),Time.elapsed(start,end),w)
    return window_events(w,events_frame(es,(F.Frame{state,tris,index,pixels,background,image,sim,render},c)))


def show(tick: U32, +start: Nat, +c: Controls, w: Window, f: F.Frame) -> IO(Window & F.Frame & Controls):
  Controls{_,_,_,_,_,h,_,_,_,_,_, +sx, +sy, +high} = c
  F.Frame{state,tris,index,pixels,background,image,+sim,+render} = f
  do IO<Window & F.Frame & Controls>:
    r : Window & Image & List<Event> <- Window.frame(w,overlay(h,label(c,sim,render),image))
    displayed(tick,start,state,tris,index,pixels,background,sim,render,c,r)

def advance(+tick: U32, time: U32, steps: U32, start: Nat, w: Window, r: F.Frame & Controls) -> IO(Window & F.Frame & Controls):
  (f,+c) = r
  Controls{gpu,paused,_,_,wind,_,x,y,_,id,depth, +sx, +sy, +high} = c
  do IO<Window & F.Frame & Controls>:
    f : F.Frame <- F.step_count(gpu,10n,paused,U32.to_nat(steps),physical(32,(U32.to_f32(time) / 120.0 : F32),wind,id,V.target(x,y,depth)),f)
    show(tick,start,c,w,f)

def reset(on: Bool, high: Bool, f: F.Frame) -> IO(F.Frame):
  match on:
    case False{}: IO.pure(F.Frame,f)
    case True{}: F.create(Bool.pick(Nat,high,6n,5n))

def loop(n: Nat, +tick: U32, +time: U32, last: Nat, lag: U32, r: Window & F.Frame & Controls) -> IO(Unit):
  match n:
    case 0n:
      (w,_,_) = r
      Window.close(w)
    case 1n+k:
      (w,f,Controls{g,+p,+restart,quit,wind,h,+x,+y,+pick,i,d, +sx, +sy, +high}) = r
      match quit:
        case True{}: Window.close(w)
        case False{}:
          do IO<Unit>:
            +start : Nat <- Time.micros()
            +pending : U32 = L.word(p || restart,0,(lag + U32.min(Time.elapsed(last,start),66664) : U32))
            # Drop excess wall time after stalls. Extra catch-up work must not
            # turn an expensive frame into a sustained responsiveness spiral.
            +steps : U32 = U32.min((pending / 8333 : U32),2)
            f : F.Frame <- reset(restart,high,f)
            r : Window & F.Frame & Controls <- advance(tick,time,steps,start,w,
              select(pick,x,y,Controls{g,p,False{},False{},wind,h,x,y,pick,i,d, sx, sy, high},f))
            loop(k,(tick + 1 : U32),(time + steps : U32),start,(pending % 8333 : U32),r)

def started(r: Window & U32 & U32, f: F.Frame) -> IO(Unit):
  (w,width,height) = r
  do IO<Unit>:
    now : Nat <- Time.micros()
    loop(4294967295n,0,0,now,16666,(w,f,Controls{False{},False{},False{},False{},True{},True{},256.0,256.0,False{},4294967295,7.5,
      (512.0 / U32.to_f32(width) : F32),(512.0 / U32.to_f32(height) : F32),False{}}))
def main() -> IO(Unit):
  do IO<Unit>:
    w : Window <- IO.try(Window,Window.open("BEND CLOTH | drag fabric | Q quality | G backend",1024,1024))
    f : F.Frame <- F.create(5n)
    r : Window & U32 & U32 <- Viewport.dimensions(w)
    started(r,f)
