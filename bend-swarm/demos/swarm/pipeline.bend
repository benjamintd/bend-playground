import Base
import ../../engine/spatial.bend as Spatial
import ./world.bend as W
import ./boids.bend as B
import ./points.bend as Points
import ../../engine/spatial/grid.bend as G
import ../../engine/core/time.bend as Time

type Metrics is Data:
  Metrics{histogram: U32, scan: U32, scatter: U32, simulation: U32, binning: U32, render: U32, total: U32, checks: Nat}

type Frame is Type:
  Frame{scene: Points.Scene, next: W.World, pixels: Array<U32>, image: Image, metrics: Metrics}

def from_points(next: W.World, p: Points.Frame) -> Frame:
  Points.Frame{scene,pixels,image,_} = p
  Frame{scene,next,pixels,image,Metrics{0,0,0,0,0,0,0,0n}}

def create(+depth: Nat) -> Frame:
  from_points(W.empty(depth,U32.shln(1,depth)),Points.create(depth))

def flocked(r: W.World & W.World & Spatial.Index(B.space()) & Spatial.Statistics) -> Points.Scene & W.World & Nat:
  (old,next,index,Spatial.Statistics{checks,_}) = r
  (Points.Scene{next,G.from_index(~B.space(),index)},old,checks)

def flock(gpu: Bool, depth: Nat, scene: Points.Scene, next: W.World,
  mx: F32, my: F32, power: F32) -> IO(Points.Scene & W.World & Nat):
  Points.Scene{W.World{+n,+cap,px,py,vx,vy},grid} = scene
  do IO<Points.Scene & W.World & Nat>:
    result : Spatial.Step(B.space(),W.World,W.World) <- Spatial.require(~Spatial.Step(B.space(),W.World,W.World),
      B.run(gpu,depth,B.Context{mx,my,power},G.snapshot(~W.World,n,cap,W.World{n,cap,px,py,vx,vy},grid),next))
    return flocked(Spatial.release(~B.space(),~W.World,~W.World,result))

def measured(m: Metrics, next: W.World, p: Points.Frame) -> Frame:
  Points.Frame{scene,pixels,image,_} = p
  Frame{scene,next,pixels,image,m}

def after_flock(+gpu: Bool, +depth: Nat, pixels: Array<U32>, old: Image,
  +t0: Nat, +t1: Nat, +t2: Nat, +t3: Nat, +t4: Nat,
  r: Points.Scene & W.World & Nat) -> IO(Frame):
  (scene,next,checks) = r
  do IO<Frame>:
    scene : Points.Scene = Points.histogram(gpu,depth,scene)
    barrier : Nat <- Time.micros()
    scene : Points.Scene = Points.scan(scene)
    barrier : Nat <- Time.micros()
    scene : Points.Scene = Points.scatter(gpu,depth,scene)
    +t5 : Nat <- Time.micros()
    f : Points.Frame = Points.render(gpu,scene,pixels,old)
    +t6 : Nat <- Time.micros()
    return measured(Metrics{Time.elapsed(t0,t1),Time.elapsed(t1,t2),Time.elapsed(t2,t3),
      Time.elapsed(t3,t4),Time.elapsed(t4,t5),Time.elapsed(t5,t6),Time.elapsed(t0,t6),checks},next,f)

def step(+gpu: Bool, +depth: Nat, mx: F32, my: F32, power: F32, f: Frame) -> IO(Frame):
  Frame{scene,next,pixels,old,_} = f
  do IO<Frame>:
    +t0 : Nat <- Time.micros()
    scene : Points.Scene = Points.histogram(gpu,depth,scene)
    +t1 : Nat <- Time.micros()
    scene : Points.Scene = Points.scan(scene)
    +t2 : Nat <- Time.micros()
    scene : Points.Scene = Points.scatter(gpu,depth,scene)
    +t3 : Nat <- Time.micros()
    r : Points.Scene & W.World & Nat <- flock(gpu,depth,scene,next,mx,my,power)
    t4 : Nat <- Time.micros()
    after_flock(gpu,depth,pixels,old,t0,t1,t2,t3,t4,r)

def csv(m: Metrics) -> String:
  Metrics{h,s,c,u,b,r,t,k} = m
  U32.show(h) ++ "," ++ U32.show(s) ++ "," ++ U32.show(c) ++ "," ++ U32.show(u) ++ ","
    ++ U32.show(b) ++ "," ++ U32.show(r) ++ "," ++ U32.show(t) ++ "," ++ Nat.show(k)

def report(f: Frame) -> IO(Frame):
  Frame{s,n,p,i,+m} = f
  do IO<Frame>:
    Unit <- IO.print(csv(m))
    return Frame{s,n,p,i,m}

def maybe_report(reporting: Bool, f: Frame) -> IO(Frame):
  match reporting:
    case True{}: report(f)
    case False{}: IO.pure(Frame,f)

def frames(n: Nat, +gpu: Bool, +depth: Nat, f: Frame, +reporting: Bool) -> IO(Frame):
  match n:
    case 0n: IO.pure(Frame,f)
    case 1n+p:
      do IO<Frame>:
        f : Frame <- step(gpu,depth,0.0,0.0,0.0,f)
        f : Frame <- maybe_report(reporting,f)
        frames(p,gpu,depth,f,reporting)
