import Base
import ../../demos/swarm/boids.bend as B
import ../../demos/swarm/world.bend as W
import ../../engine/spatial.bend as Spatial
import ../../engine/spatial/layout.bend as L

type State is Type:
  State{current: W.World, previous: W.World, index: Spatial.Index(B.space())}
def created(r: Result<String,Spatial.Index(B.space())>) -> Result<String,State>:
  match r:
    case Fail{e}: Fail{e}
    case Done{index}: Done{State{W.create(11n),W.empty(11n,2048),index}}
def create() -> Result<String,State>: created(Spatial.create(~B.space(),11n))
def positioned(r: W.World & W.Sample) -> W.World & L.Point:
  (w,s) = r
  (w,B.position(s))
def position(+i: U32, w: W.World) -> W.World & L.Point: positioned(W.read(i,w))
def released(r: W.World & W.World & Spatial.Index(B.space()) & Spatial.Statistics) -> State:
  (old,current,index,_) = r
  State{current,old,index}
def simulated(r: Result<String,Spatial.Step(B.space(),W.World,W.World)>) -> Result<String,State>:
  match r:
    case Fail{e}: Fail{e}
    case Done{s}: Done{released(Spatial.release(~B.space(),~W.World,~W.World,s))}
def built(c: B.Context, out: W.World, r: Result<String,Spatial.Snapshot(B.space(),W.World)>) -> Result<String,State>:
  match r:
    case Fail{e}: Fail{e}
    case Done{snapshot}: simulated(B.run(False{},0n,c,snapshot,out))
def frame(x: F32, y: F32, power: F32, s: State) -> Result<String,State>:
  State{current,out,index} = s
  built(B.Context{x,y,power},out,Spatial.build(~B.space(),~W.World,~position,~W.join,False{},0n,2048,current,index))
