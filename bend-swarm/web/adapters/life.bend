import Base
import ../../demos/life/simulation.bend as S
import ../../engine/spatial.bend as Spatial

# Same six-species model, 2048 particles for the single-threaded web backend.
def created(seed: U32, r: Result<String,Spatial.Index(S.space())>) -> Result<String,S.State>:
  match r:
    case Fail{e}: Fail{e}
    case Done{index}: Done{S.State{S.fill(2048n,0,seed,Array.new(S.Particle,11n,S.Particle{0.0,0.0,0.0,0.0})),Array.new(S.Particle,11n,S.Particle{0.0,0.0,0.0,0.0}),index}}
def create(seed: U32) -> Result<String,S.State>: created(seed,Spatial.create(~S.space(),11n))
def released(r: Result<String,Spatial.Step(S.space(),Array<S.Particle>,Array<S.Particle>)>) -> Result<String,S.State>:
  match r:
    case Fail{e}: Fail{e}
    case Done{s}: Done{S.released(Spatial.release(~S.space(),~Array<S.Particle>,~Array<S.Particle>,s))}
def built(c: S.Controls, out: Array<S.Particle>, r: Result<String,Spatial.Snapshot(S.space(),Array<S.Particle>)>) -> Result<String,S.State>:
  match r:
    case Fail{e}: Fail{e}
    case Done{snapshot}: released(Spatial.stencil(~S.space(),~Array<S.Particle>,~Array<S.Particle>,~S.Particle,~S.Force,~S.Controls,
      ~S.read,~S.point,~S.begin,~S.visit,~S.finish,~Array.join(S.Particle),~Array.join(S.Particle),False{},0n,32.0,False{},c,snapshot,out))
def frame(preset: U32, seed: U32, x: F32, y: F32, power: F32, s: S.State) -> Result<String,S.State>:
  S.State{current,out,index} = s
  built(S.Controls{preset,seed,x,y,power},out,Spatial.build(~S.space(),~Array<S.Particle>,~S.position,~Array.join(S.Particle),False{},0n,2048,current,index))
def color(species: U32) -> U32:
  match species:
    case 0: 5304258
    case 1: 16758619
    case 2: 15429309
    case 3: 6921215
    case 4: 15982954
    case _: 9927665
