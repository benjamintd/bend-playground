import Base
import ./simulation.bend as S
import ./physics.bend as P
import ./view.bend as V
import ./world.bend as W
import ../../engine/render/mesh.bend as M
import ../../engine/spatial.bend as Spatial
import ../../engine/core/time.bend as Time

type Frame is Type:
  Frame{state: S.State, triangles: Array<M.Triangle>, index: M.Index, pixels: Array<U32>, image: Image,
    simulation_us: U32, render_us: U32}

def create(+bits: Nat) -> IO(Frame):
  do IO<Frame>:
    state : S.State <- Spatial.require(~S.State,S.create(bits))
    return Frame{state,Array.new(M.Triangle,Nat.add(1n,Nat.add(bits,bits)),M.blank()),M.empty(),
      Array.new(U32,18n,0),Pix{0},0,0}

def drawn(state: S.State, counts: Array<U32>, cursors: Array<U32>, capacity: U32,
  simulation: U32, render: U32, result: M.Drawing & Image) -> Frame:
  (M.Drawing{tris,offsets,ids,pixels},image) = result
  Frame{state,tris,M.Index{counts,offsets,cursors,ids,capacity},pixels,image,simulation,render}

def binned(+gpu: Bool, state: S.State, pixels: Array<U32>, image: Image, simulation: U32, start: Nat,
  r: Array<M.Triangle> & M.Index) -> IO(Frame):
  (tris,M.Index{counts,offsets,cursors,ids,cap}) = r
  do IO<Frame>:
    result : M.Drawing & Image = M.render(~V.background,gpu,M.Drawing{tris,offsets,ids,pixels},image)
    end : Nat <- Time.micros()
    return drawn(state,counts,cursors,cap,simulation,Time.elapsed(start,end),result)

def projected(+gpu: Bool, n: U32, previous: W.Positions, scratch: W.Positions, spatial: Spatial.Index(P.space()),
  checks: Nat, neighbors: Nat, index: M.Index, pixels: Array<U32>, image: Image, simulation: U32, start: Nat,
  r: V.Projection) -> IO(Frame):
  V.Projection{current,tris,side} = r
  binned(gpu,S.State{side,current,previous,scratch,spatial,checks,neighbors},pixels,image,simulation,start,M.build(gpu,n,tris,index))

def draw(+gpu: Bool, start: Nat, f: Frame) -> IO(Frame):
  Frame{S.State{+side,current,previous,scratch,spatial,checks,neighbors},tris,index,pixels,image,sim,_} = f
  +n = ((side - 1) * (side - 1) * 2 : U32)
  projected(gpu,n,previous,scratch,spatial,checks,neighbors,index,pixels,image,sim,start,
    V.triangles_run(gpu,n,V.Projection{current,tris,side}))

def advance(paused: Bool, gpu: Bool, depth: Nat, c: P.Controls, s: S.State) -> IO(S.State):
  match paused:
    case True{}: IO.pure(S.State,s)
    case False{}: S.step(gpu,depth,c,s)

def step_depth(+gpu: Bool, depth: Nat, paused: Bool, c: P.Controls, f: Frame) -> IO(Frame):
  Frame{s,tris,index,pixels,image,_,_} = f
  do IO<Frame>:
    t0 : Nat <- Time.micros()
    s : S.State <- advance(paused,gpu,depth,c,s)
    +t1 : Nat <- Time.micros()
    draw(gpu,t1,Frame{s,tris,index,pixels,image,Time.elapsed(t0,t1),0})

# Small cloth workloads need fewer owned regions than the massive swarm.
def step(gpu: Bool, paused: Bool, c: P.Controls, f: Frame) -> IO(Frame):
  step_depth(gpu,10n,paused,c,f)
