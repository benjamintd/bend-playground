import Base
import ../demos/swarm/world.bend as W
import ../demos/swarm/boids.bend as B
import ../engine/spatial.bend as S
import ../engine/spatial/layout.bend as L

def position_read(r: W.World & W.Sample) -> W.World & L.Point:
  (w,s) = r
  (w,B.position(s))

def position(+i: U32, w: W.World) -> W.World & L.Point:
  position_read(W.read(i,w))

def built(n: U32, depth: Nat, r: Result<String,S.Snapshot(B.space(),W.World)>) -> Result<String,S.Step(B.space(),W.World,W.World)>:
  match r:
    case Fail{e}: Fail{e}
    case Done{snapshot}: B.run(True{},3n,B.Context{0.0,0.0,0.0},snapshot,W.empty(depth,n))

def created(+n: U32, depth: Nat, w: W.World, r: Result<String,S.Index(B.space())>) -> Result<String,S.Step(B.space(),W.World,W.World)>:
  match r:
    case Fail{e}: Fail{e}
    case Done{index}: built(n,depth,S.build(~B.space(),~W.World,~position,~W.join,True{},3n,n,w,index))

def run(+n: U32, +depth: Nat, w: W.World) -> Result<String,S.Step(B.space(),W.World,W.World)>:
  created(n,depth,w,S.create(~B.space(),depth))
