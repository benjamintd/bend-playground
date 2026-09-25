import Base
import ./frame.bend as F
import ./simulation.bend as S
import ./physics.bend as P
import ./world.bend as W
import ./view.bend as V
import ./input.bend as Input
import ../../engine/spatial.bend as Spatial
import ../../engine/spatial/layout.bend as L
import ../../engine/render/mesh.bend as M
import ../../engine/render/hud.bend as Hud
import ../../engine/core/time.bend as Time

type Controls is Data:
  Controls{gpu: Bool, paused: Bool, reset: Bool, quit: Bool, wind: Bool, hud: Bool,
    mx: F32, my: F32, picking: Bool, grab: U32, grab_depth: F32}

def event(e: Event, c: Controls) -> Controls:
  match e:
    case Close{}:
      Controls{g,p,r,_,w,h,x,y,k,i,d} = c
      Controls{g,p,r,True{},w,h,x,y,k,i,d}
    case Key{27,True{}}:
      Controls{g,p,r,_,w,h,x,y,k,i,d} = c
      Controls{g,p,r,True{},w,h,x,y,k,i,d}
    case Key{103,True{}}:
      Controls{g,p,r,q,w,h,x,y,k,i,d} = c
      Controls{Bool.not(g),p,r,q,w,h,x,y,k,i,d}
    case Key{32,True{}}:
      Controls{g,p,r,q,w,h,x,y,k,i,d} = c
      Controls{g,Bool.not(p),r,q,w,h,x,y,k,i,d}
    case Key{114,True{}}:
      Controls{g,p,_,q,w,h,x,y,_,_,d} = c
      Controls{g,p,True{},q,w,h,x,y,False{},4294967295,d}
    case Key{119,True{}}:
      Controls{g,p,r,q,w,h,x,y,k,i,d} = c
      Controls{g,p,r,q,Bool.not(w),h,x,y,k,i,d}
    case Key{104,True{}}:
      Controls{g,p,r,q,w,h,x,y,k,i,d} = c
      Controls{g,p,r,q,w,Bool.not(h),x,y,k,i,d}
    case Move{mx,my}:
      Controls{g,p,r,q,w,h,_,_,k,i,d} = c
      Controls{g,p,r,q,w,h,(U32.to_f32(mx) * 0.5 : F32),(U32.to_f32(my) * 0.5 : F32),k,i,d}
    case Mouse{mx,my,0,down}:
      Controls{g,p,r,q,w,h,_,_,_,_,d} = c
      Controls{g,p,r,q,w,h,(U32.to_f32(mx) * 0.5 : F32),(U32.to_f32(my) * 0.5 : F32),down,4294967295,d}
    case _: c

def events(es: List<Event>, c: Controls) -> Controls:
  match es:
    case Nil{}: c
    case e <> rest: events(rest,event(e,c))

def selected(side: U32, previous: W.Positions, scratch: W.Positions, spatial: Spatial.Index(P.space()),
  checks: Nat, neighbors: Nat, tris: Array<M.Triangle>, index: M.Index, pixels: Array<U32>, image: Image,
  sim: U32, render: U32, c: Controls, r: W.Positions & Input.Pick) -> F.Frame & Controls:
  Controls{g,p,restart,q,w,h,x,y,_,_,_} = c
  (current,Input.Pick{i,_,depth}) = r
  (F.Frame{S.State{side,current,previous,scratch,spatial,checks,neighbors},tris,index,pixels,image,sim,render},
    Controls{g,p,restart,q,w,h,x,y,False{},i,depth})

def select(on: Bool, x: F32, y: F32, c: Controls, f: F.Frame) -> F.Frame & Controls:
  match on:
    case False{}: (f,c)
    case True{}:
      F.Frame{S.State{+side,current,previous,scratch,spatial,checks,neighbors},tris,index,pixels,image,sim,render} = f
      selected(side,previous,scratch,spatial,checks,neighbors,tris,index,pixels,image,sim,render,c,
        Input.pick((side * side : U32),x,y,current))

def physical(time: F32, wind: Bool, id: U32, target: L.Point) -> P.Controls:
  L.Point{x,y,z} = target
  P.Controls{32,id,F32.max(F32.neg(3.5),F32.min(3.5,x)),F32.max(F32.neg(1.5),F32.min(3.0,y)),
    F32.max(F32.neg(3.5),F32.min(3.5,z)),time,L.pick(wind,1.5,0.0)}

def caption(refresh: Bool, us: U32, w: Window) -> IO(Window):
  match refresh:
    case False{}: IO.pure(Window,w)
    case True{}: Window.set_title(w,"BEND CLOTH | " ++ U32.show((1000000 / U32.max(us,1) : U32))
      ++ " FPS | drag fabric | SPACE pause | R reset | W wind | G CPU/GPU | H details")

def label(c: Controls, sim: U32, render: U32) -> String:
  Controls{g,p,_,_,wind,_,_,_,_,_,_} = c
  "BEND CLOTH\n\n1024 VERTICES\n1922 TRIANGLES\n\n"
    ++ Bool.pick(String,g,"GPU METAL\n","CPU\n") ++ Bool.pick(String,p,"PAUSED\n","SIMULATING\n")
    ++ Bool.pick(String,wind,"WIND ON\n","WIND OFF\n")
    ++ "\nSIM " ++ F32.show((U32.to_f32(sim) / 1000.0 : F32))
    ++ "\nDRAW " ++ F32.show((U32.to_f32(render) / 1000.0 : F32)) ++ "\nMS HEADLESS\n\n"
    ++ "DRAG FABRIC\nSPACE PAUSE\nR RESET\nW WIND\nG CPU/GPU\nH DETAILS"

def overlay(on: Bool, text: String, image: Image) -> Image:
  match on:
    case False{}: image
    case True{}: Hud.overlay(Hud.panel(text),image)

def displayed(tick: U32, start: Nat, state: S.State, tris: Array<M.Triangle>, index: M.Index, pixels: Array<U32>,
  sim: U32, render: U32, c: Controls, r: Window & Image & List<Event>) -> IO(Window & F.Frame & Controls):
  (w,image,es) = r
  do IO<Window & F.Frame & Controls>:
    end : Nat <- Time.micros()
    w : Window <- caption(U32.is_eq(U32.and(tick,15),0),Time.elapsed(start,end),w)
    return (w,F.Frame{state,tris,index,pixels,image,sim,render},events(es,c))

def show(tick: U32, start: Nat, +c: Controls, w: Window, f: F.Frame) -> IO(Window & F.Frame & Controls):
  Controls{_,_,_,_,_,h,_,_,_,_,_} = c
  F.Frame{state,tris,index,pixels,image,+sim,+render} = f
  do IO<Window & F.Frame & Controls>:
    r : Window & Image & List<Event> <- Window.frame(w,overlay(h,label(c,sim,render),image))
    displayed(tick,start,state,tris,index,pixels,sim,render,c,r)

def advance(+tick: U32, start: Nat, w: Window, r: F.Frame & Controls) -> IO(Window & F.Frame & Controls):
  (f,+c) = r
  Controls{gpu,paused,_,_,wind,_,x,y,_,id,depth} = c
  do IO<Window & F.Frame & Controls>:
    f : F.Frame <- F.step(gpu,paused,physical((U32.to_f32(tick) / 60.0 : F32),wind,id,V.target(x,y,depth)),f)
    show(tick,start,c,w,f)

def reset(on: Bool, f: F.Frame) -> IO(F.Frame):
  match on:
    case False{}: IO.pure(F.Frame,f)
    case True{}: F.create(5n)

def loop(n: Nat, +tick: U32, r: Window & F.Frame & Controls) -> IO(Unit):
  match n:
    case 0n:
      (w,_,_) = r
      Window.close(w)
    case 1n+k:
      (w,f,Controls{g,p,restart,quit,wind,h,+x,+y,+pick,i,d}) = r
      match quit:
        case True{}: Window.close(w)
        case False{}:
          do IO<Unit>:
            start : Nat <- Time.micros()
            f : F.Frame <- reset(restart,f)
            r : Window & F.Frame & Controls <- advance(tick,start,w,
              select(pick,x,y,Controls{g,p,False{},False{},wind,h,x,y,pick,i,d},f))
            loop(k,(tick + 1 : U32),r)

def main() -> IO(Unit):
  do IO<Unit>:
    w : Window <- IO.try(Window,Window.open("BEND CLOTH | drag fabric | SPACE pause | R reset | W wind | G backend",1024,1024))
    f : F.Frame <- F.create(5n)
    loop(4294967295n,0,(w,f,Controls{True{},False{},False{},False{},True{},True{},256.0,256.0,False{},4294967295,7.5}))
