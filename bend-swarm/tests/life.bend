import Base
import ../demos/life/simulation.bend as Life
import ../engine/spatial.bend as Spatial

def built(gpu: Bool, c: Life.Controls, r: Result<String,Spatial.Snapshot(Life.space(),Array<Life.Particle>)>) -> Result<String,Spatial.Step(Life.space(),Array<Life.Particle>,Array<Life.Particle>)>:
  match r:
    case Fail{e}: Fail{e}
    case Done{snapshot}: Spatial.stencil(~Life.space(),~Array<Life.Particle>,~Array<Life.Particle>,~Life.Particle,~Life.Force,~Life.Controls,
      ~Life.read,~Life.point,~Life.begin,~Life.visit,~Life.finish,~Array.join(Life.Particle),~Array.join(Life.Particle),gpu,5n,32.0,False{},c,snapshot,
      Array.new(Life.Particle,5n,Life.Particle{0.0,0.0,0.0,0.0}))
def created(+gpu: Bool, c: Life.Controls, a: Array<Life.Particle>, r: Result<String,Spatial.Index(Life.space())>) -> Result<String,Spatial.Step(Life.space(),Array<Life.Particle>,Array<Life.Particle>)>:
  match r:
    case Fail{e}: Fail{e}
    case Done{index}: built(gpu,c,Spatial.build(~Life.space(),~Array<Life.Particle>,~Life.position,~Array.join(Life.Particle),gpu,5n,32,a,index))
def run(gpu: Bool, c: Life.Controls, a: Array<Life.Particle>) -> Result<String,Spatial.Step(Life.space(),Array<Life.Particle>,Array<Life.Particle>)>:
  created(gpu,c,a,Spatial.create(~Life.space(),5n))
def fixture() -> Array<Life.Particle>:
  Life.fill(32n,0,42,Array.new(Life.Particle,5n,Life.Particle{0.0,0.0,0.0,0.0}))
