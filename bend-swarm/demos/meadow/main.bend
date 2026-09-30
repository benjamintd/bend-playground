import Base
import ../../engine/parallel/policy.bend as Policy
import ../../engine/profile/frame.bend as Profile
import ./scene.bend as Scene
import ../../engine/render/mesh.bend as M
import ../../engine/render/post.bend as Post
import ../../engine/render/finish.bend as Finish
import ../../engine/platform/player.bend as Player
import ../../engine/core/time.bend as Time

type State is Type:
  State{blades: Array<Scene.Blade>, triangles: Array<M.Triangle>, index: M.Index, pixels: Array<U32>, fragments: Array<M.Fragment>, high: Bool}
def resize(~high: Bool, change: Bool, s: State) -> State:
  match change:
    case False{}: s
    case True{}:
      State{blades,tris,index,_,_,_} = s
      State{blades,tris,index,Array.new(U32,Bool.pick(Nat,high,22n,20n),0),
        M.backdrop_level(~Bool.pick(Nat,high,2n,1n),~Scene.background_size(~high),
          Array.new(M.Fragment,Bool.pick(Nat,high,23n,21n),M.Fragment{0.0,0})),high}
def ensure(~high: Bool, s: State) -> State:
  State{blades,tris,index,pixels,fragments,+was} = s
  resize(~high,Bool.xor(high,was),State{blades,tris,index,pixels,fragments,was})
def create(preset: U32, seed: U32) -> IO(State):
  IO.pure(State,resize(~False{},True{},State{Array.new(Scene.Blade,12n,Scene.Blade{0.0,0.0,0.0,0.0}),
    Array.new(M.Triangle,15n,M.blank()),M.empty(),Array.new(U32,0n,0),Array.new(M.Fragment,0n,M.Fragment{0.0,0}),False{}}))
def finished(high: Bool, blades: Array<Scene.Blade>, counts: Array<U32>, cursors: Array<U32>, cap: U32,
  policy: Policy.Policy, +sim: U32, geo: U32, bin: U32, draw: U32, r: (M.Drawing & Image) & U32 & U32) -> State & Image & Player.Metrics:
  ((M.Drawing{tris,offsets,ids,pixels,fragments},image),ras,post) = r
  (State{blades,tris,M.Index{counts,offsets,cursors,ids,cap},pixels,fragments,high},image,
    Player.Measured{sim,draw,4096,Profile.Sample{policy,sim,geo,bin,ras,post}})
def binned(~high: Bool, +policy: Policy.Policy, settings: Post.Settings, sim: U32, geo: U32, start: Nat, render_start: Nat,
  blades: Array<Scene.Blade>, pixels: Array<U32>, fragments: Array<M.Fragment>, old: Image, r: Array<M.Triangle> & M.Index) -> IO(State & Image & Player.Metrics):
  Policy.Policy{_,_,_,raster,post_gpu,_} = policy
  (tris,M.Index{counts,offsets,cursors,ids,cap}) = r
  do IO<State & Image & Player.Metrics>:
    end : Nat <- Time.micros()
    r : (M.Drawing & Image) & U32 & U32 <- Finish.measured(~Bool.pick(Nat,high,2n,1n),raster,post_gpu,settings,M.Drawing{tris,offsets,ids,pixels,fragments},old)
    finished_at : Nat <- Time.micros()
    return finished(high,blades,counts,cursors,cap,policy,sim,geo,Time.elapsed(start,end),Time.elapsed(render_start,finished_at),r)
def projected(~high: Bool, +policy: Policy.Policy, settings: Post.Settings, sim: U32, +start: Nat, index: M.Index,
  pixels: Array<U32>, fragments: Array<M.Fragment>, old: Image, r: Scene.Geometry) -> IO(State & Image & Player.Metrics):
  Policy.Policy{_,_,bin,_,_,_} = policy
  Scene.Geometry{blades,tris} = r
  do IO<State & Image & Player.Metrics>:
    +end : Nat <- Time.micros()
    binned(~high,policy,settings,sim,Time.elapsed(start,end),end,start,blades,pixels,fragments,old,
      M.build_level(~Bool.pick(Nat,high,2n,1n),bin,32768,tris,index))
def ready(~high: Bool, +policy: Policy.Policy, c: Player.Input, s: State, image: Image) -> IO(State & Image & Player.Metrics):
  Policy.Policy{sim_gpu,geometry,_,_,_,_} = policy
  Player.Input{_,paused,_,_,_,preset,_,mx,my,power,time,aa,dof,_} = c
  State{blades,tris,index,pixels,fragments,_} = s
  do IO<State & Image & Player.Metrics>:
    t0 : Nat <- Time.micros()
    blades : Array<Scene.Blade> = Scene.simulate(sim_gpu,paused,Scene.controls(time,preset,power,Scene.mouse(mx,my)),blades)
    +t1 : Nat <- Time.micros()
    projected(~high,policy,Post.Settings{aa,dof,10.5,6.0},Time.elapsed(t0,t1),t1,index,pixels,fragments,image,
      Scene.project_size(~high,geometry,Scene.Geometry{blades,tris}))
def sized(high: Bool, policy: Policy.Policy, c: Player.Input, s: State, image: Image) -> IO(State & Image & Player.Metrics):
  match high:
    case True{}: ready(~True{},policy,c,ensure(~True{},s),image)
    case False{}: ready(~False{},policy,c,ensure(~False{},s),image)
def frame_policy(policy: Policy.Policy, +c: Player.Input, s: State, image: Image) -> IO(State & Image & Player.Metrics):
  Player.Input{_,_,_,_,_,_,_,_,_,_,_,_,_,high} = c
  do IO<State & Image & Player.Metrics>:
    policy : Policy.Policy <- Policy.resolve(policy)
    sized(high,policy,c,s,image)
def frame_shared(+c: Player.Input, s: State, image: Image) -> IO(State & Image & Player.Metrics):
  Player.Input{gpu,_,_,_,_,_,_,_,_,_,_,_,_,_} = c
  frame_policy(Policy.all(gpu,0n),c,s,image)
def frame(c: Player.Input, s: State, image: Image) -> IO(State & Image & Player.Metrics):
  frame_shared(c,s,image)
def main() -> IO(Unit):
  Player.run(~State,~"BEND MEADOW",~"HOLD MOUSE GUST\n1 2 3 WIND\nA ANTIALIAS\nQ RESOLUTION\nD FOCUS\nSPACE PAUSE\nR RESET",~create,~frame,False{},False{})
