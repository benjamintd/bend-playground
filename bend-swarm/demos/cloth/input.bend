import Base
import ./world.bend as W
import ./view.bend as V
import ../../engine/render/mesh.bend as M
import ../../engine/spatial/layout.bend as L

type Pick is Data:
  Pick{id: U32, squared: F32, depth: F32}

def nearest(close: Bool, id: U32, d2: F32, depth: F32, old: Pick) -> Pick:
  match close:
    case True{}: Pick{id,d2,depth}
    case False{}: old

def projected(id: U32, x: F32, y: F32, old: Pick, v: M.Vertex) -> Pick:
  Pick{j,+d2,z} = old
  M.Vertex{vx,vy,+depth} = v
  +dx = (vx - x : F32)
  +dy = (vy - y : F32)
  +dist = (dx * dx + dy * dy : F32)
  nearest((dist < d2 : F32) && (depth > 0.1 : F32),id,dist,depth,Pick{j,d2,z})

def read(id: U32, x: F32, y: F32, old: Pick, r: W.Positions & L.Point) -> W.Positions & Pick:
  (p,v) = r
  (p,projected(id,x,y,old,V.project(v)))

def scan(n: Nat, +i: U32, +x: F32, +y: F32, r: W.Positions & Pick) -> W.Positions & Pick:
  match n:
    case 0n: r
    case 1n+k:
      (p,old) = r
      scan(k,(i + 1 : U32),x,y,read(i,x,y,old,W.read(i,p)))

def pick(n: U32, x: F32, y: F32, p: W.Positions) -> W.Positions & Pick:
  scan(U32.to_nat(n),0,x,y,(p,Pick{4294967295,484.0,7.5}))
