import Base
import ./simulation.bend as S
import ../../engine/spatial.bend as Spatial
import ../../engine/render/splats.bend as Splats
import ../../engine/platform/player.bend as Player
import ../../engine/core/time.bend as Time

def color(species: U32) -> U32:
  match species:
    case 0: 5304258
    case 1: 16758619
    case 2: 15429309
    case 3: 6921215
    case 4: 15982954
    case _: 9927665
def sampled(i: U32, r: Array<S.Particle> & S.Particle) -> Array<S.Particle> & Splats.Splat:
  (a,S.Particle{x,y,_,_}) = r
  (a,Splats.Splat{x,y,color((i % 6 : U32))})
def sprite(+i: U32, a: Array<S.Particle>) -> Array<S.Particle> & Splats.Splat:
  sampled(i,Array.get(S.Particle,a,i))
type State is Type:
  State{simulation: S.State, screen: Spatial.Index(Splats.space()), pixels: Array<U32>, high: Bool}
def create(preset: U32, seed: U32) -> IO(State):
  do IO<State>:
    s : S.State <- S.create(seed)
    screen : Spatial.Index(Splats.space()) <- Spatial.require(~Spatial.Index(Splats.space()),Spatial.create(~Splats.space(),13n))
    return State{s,screen,Array.new(U32,20n,0),False{}}
def completed(high: Bool, previous: Array<S.Particle>, index: Spatial.Index(S.space()), sim: U32, draw: U32,
  r: Array<S.Particle> & Spatial.Index(Splats.space()) & Array<U32> & Image) -> State & Image & Player.Metrics:
  (current,screen,pixels,image) = r
  (State{S.State{current,previous,index},screen,pixels,high},image,Player.Metrics{sim,draw,8192})
def render(~high: Bool, +gpu: Bool, smooth: Bool, sim: U32, +start: Nat, screen: Spatial.Index(Splats.space()), pixels: Array<U32>, image: Image, s: S.State) -> IO(State & Image & Player.Metrics):
  S.State{current,previous,index} = s
  do IO<State & Image & Player.Metrics>:
    snapshot : Spatial.Snapshot(Splats.space(),Array<S.Particle>) <- Spatial.require(~Spatial.Snapshot(Splats.space(),Array<S.Particle>),
      Spatial.build(~Splats.space(),~Array<S.Particle>,~S.position,~Array.join(S.Particle),gpu,Bool.pick(Nat,gpu,13n,7n),8192,current,screen))
    r : Array<S.Particle> & Spatial.Index(Splats.space()) & Array<U32> & Image =
      Splats.draw_level(~Bool.pick(Nat,high,1n,0n),~Array<S.Particle>,~sprite,~Array.join(S.Particle),gpu,Splats.Settings{smooth,4.0,1.55},snapshot,pixels,image)
    end : Nat <- Time.micros()
    return completed(high,previous,index,sim,Time.elapsed(start,end),r)
def sized(high: Bool, gpu: Bool, smooth: Bool, sim: U32, start: Nat, screen: Spatial.Index(Splats.space()), pixels: Array<U32>, image: Image, s: S.State) -> IO(State & Image & Player.Metrics):
  match high:
    case True{}: render(~True{},gpu,smooth,sim,start,screen,pixels,image,s)
    case False{}: render(~False{},gpu,smooth,sim,start,screen,pixels,image,s)
def resized(change: Bool, high: Bool, pixels: Array<U32>) -> Array<U32>:
  match change:
    case False{}: pixels
    case True{}: Array.new(U32,Bool.pick(Nat,high,22n,20n),0)
def frame(c: Player.Input, s: State, image: Image) -> IO(State & Image & Player.Metrics):
  Player.Input{+gpu,paused,_,_,_,preset,seed,mx,my,power,_,aa,_,+high} = c
  State{simulation,screen,pixels,was} = s
  do IO<State & Image & Player.Metrics>:
    t0 : Nat <- Time.micros()
    simulation : S.State <- S.advance(paused,gpu,S.Controls{preset,seed,(mx * 1024.0 : F32),(my * 1024.0 : F32),power},simulation)
    +t1 : Nat <- Time.micros()
    sized(high,gpu,aa,Time.elapsed(t0,t1),t1,screen,resized(Bool.xor(high,was),high,pixels),image,simulation)
def main() -> IO(Unit):
  Player.run(~State,~"BEND LIFE",~"LEFT ATTRACT\nRIGHT REPEL\n1 ISLANDS\n2 CHASERS\n3 RANDOM RULES\nA SMOOTH EDGES\nQ RESOLUTION\nSPACE PAUSE\nR RESEED",~create,~frame,True{},True{})
