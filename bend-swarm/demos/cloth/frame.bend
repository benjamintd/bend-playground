import Base
import ./simulation.bend as S
import ./physics.bend as P
import ./view.bend as V
import ./world.bend as W
import ./surface.bend as Surface
import ../../engine/render/mesh.bend as M
import ../../engine/render/post.bend as Post
import ../../engine/render/finish.bend as Finish
import ../../engine/spatial.bend as Spatial
import ../../engine/core/time.bend as Time

type Frame is Type:
  Frame{state: S.State, triangles: Array<M.Triangle>, index: M.Index, pixels: Array<U32>, background: Array<M.Fragment>, image: Image,
    simulation_us: U32, render_us: U32}

def background(high: Bool) -> Array<M.Fragment>:
  match high:
    case True{}: M.backdrop(~True{},~V.background_high,Array.new(M.Fragment,21n,M.Fragment{0.0,0}))
    case False{}: M.backdrop(~False{},~V.background,Array.new(M.Fragment,19n,M.Fragment{0.0,0}))

def create(+bits: Nat) -> IO(Frame):
  do IO<Frame>:
    state : S.State <- Spatial.require(~S.State,S.create(Nat.min(bits,5n)))
    return Frame{state,Array.new(M.Triangle,Bool.pick(Nat,Nat.is_lt(5n,bits),14n,Nat.add(1n,Nat.add(bits,bits))),M.blank()),M.empty(),
      Array.new(U32,Bool.pick(Nat,Nat.is_lt(5n,bits),20n,18n),0),background(Nat.is_lt(5n,bits)),Pix{0},0,0}

def drawn(state: S.State, counts: Array<U32>, cursors: Array<U32>, capacity: U32,
  simulation: U32, render: U32, result: M.Drawing & Image) -> Frame:
  (M.Drawing{tris,offsets,ids,pixels,background},image) = result
  Frame{state,tris,M.Index{counts,offsets,cursors,ids,capacity},pixels,background,image,simulation,render}

def render_effects(settings: Post.Settings, high: Bool, gpu: Bool, b: M.Drawing, image: Image) -> M.Drawing & Image:
  match high:
    case True{}: Finish.draw(~True{},gpu,settings,b,image)
    case False{}: Finish.draw(~False{},gpu,settings,b,image)

def render(high: Bool, gpu: Bool, b: M.Drawing, image: Image) -> M.Drawing & Image:
  render_effects(Post.Settings{False{},False{},7.5,4.0},high,gpu,b,image)

def binned(settings: Post.Settings,high: Bool, +gpu: Bool, state: S.State, pixels: Array<U32>, background: Array<M.Fragment>, image: Image, simulation: U32, start: Nat,
  r: Array<M.Triangle> & M.Index) -> IO(Frame):
  (tris,M.Index{counts,offsets,cursors,ids,cap}) = r
  do IO<Frame>:
    result : M.Drawing & Image = render_effects(settings,high,gpu,M.Drawing{tris,offsets,ids,pixels,background},image)
    end : Nat <- Time.micros()
    return drawn(state,counts,cursors,cap,simulation,Time.elapsed(start,end),result)

def projected(settings: Post.Settings,+gpu: Bool, n: U32, previous: W.Positions, scratch: W.Positions, spatial: Spatial.Index(P.space()),
  samples: Array<Surface.Sample>, checks: Nat, neighbors: Nat, index: M.Index, pixels: Array<U32>, background: Array<M.Fragment>, image: Image, simulation: U32, start: Nat,
  r: V.Projection) -> IO(Frame):
  V.Projection{current,tris,side,+high} = r
  binned(settings,high,gpu,S.State{side,current,previous,scratch,spatial,samples,checks,neighbors},pixels,background,image,simulation,start,M.build_quality(high,gpu,n,tris,index))

def draw_sized(settings: Post.Settings,+gpu: Bool, start: Nat, state: S.State, tris: Array<M.Triangle>, index: M.Index, background: Array<M.Fragment>, image: Image, sim: U32,
  r: Array<U32> & U32) -> IO(Frame):
  S.State{+side,current,previous,scratch,spatial,samples,checks,neighbors} = state
  (pixels,size) = r
  +high = (size > 262144 : U32)
  +n = Bool.pick(U32,high,7938,((side - 1) * (side - 1) * 2 : U32))
  projected(settings,gpu,n,previous,scratch,spatial,samples,checks,neighbors,index,pixels,background,image,sim,start,
    V.triangles_run(gpu,n,V.Projection{current,tris,side,high}))
def draw_effects(settings: Post.Settings, gpu: Bool, start: Nat, f: Frame) -> IO(Frame):
  Frame{state,tris,index,pixels,background,image,sim,_} = f
  draw_sized(settings,gpu,start,state,tris,index,background,image,sim,Array.size(U32,pixels))

def draw(gpu: Bool, start: Nat, f: Frame) -> IO(Frame):
  draw_effects(Post.Settings{False{},False{},7.5,4.0},gpu,start,f)

def substeps(n: Nat, +gpu: Bool, +depth: Nat, +c: P.Controls, s: S.State) -> IO(S.State):
  match n:
    case 0n: IO.pure(S.State,s)
    case 1n+k:
      do IO<S.State>:
        s : S.State <- S.substep(gpu,depth,c,s)
        substeps(k,gpu,depth,c,s)
def advance(paused: Bool, +gpu: Bool, depth: Nat, n: Nat, c: P.Controls, s: S.State) -> IO(S.State):
  match paused:
    case True{}: IO.pure(S.State,s)
    case False{}: substeps(n,gpu,Bool.pick(Nat,gpu,depth,0n),c,s)
def step_effects(settings: Post.Settings, sim_gpu: Bool, render_gpu: Bool, depth: Nat, paused: Bool, n: Nat, c: P.Controls, f: Frame) -> IO(Frame):
  Frame{s,tris,index,pixels,background,image,_,_} = f
  do IO<Frame>:
    t0 : Nat <- Time.micros()
    s : S.State <- advance(paused,sim_gpu,depth,n,c,s)
    +t1 : Nat <- Time.micros()
    draw_effects(settings,render_gpu,t1,Frame{s,tris,index,pixels,background,image,Time.elapsed(t0,t1),0})
def step_render(sim_gpu: Bool, render_gpu: Bool, depth: Nat, paused: Bool, n: Nat, c: P.Controls, f: Frame) -> IO(Frame):
  step_effects(Post.Settings{False{},False{},7.5,4.0},sim_gpu,render_gpu,depth,paused,n,c,f)
def step_count(+gpu: Bool, depth: Nat, paused: Bool, n: Nat, c: P.Controls, f: Frame) -> IO(Frame):
  step_render(gpu,gpu,depth,paused,n,c,f)
def step_depth(gpu: Bool, depth: Nat, paused: Bool, c: P.Controls, f: Frame) -> IO(Frame):
  step_count(gpu,depth,paused,2n,c,f)
def step(gpu: Bool, paused: Bool, c: P.Controls, f: Frame) -> IO(Frame):
  step_depth(gpu,10n,paused,c,f)
