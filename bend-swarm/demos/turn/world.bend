import Base
import ./model.bend as G
import ./levels.bend as L

# One fixed, canonical index for every voxel in the 10x10x10 world.
def cell(+i: U32) -> G.Point:
  G.Point{(i % 10 : U32),((i / 10) % 10 : U32),(i / 100 : U32)}
def axis_plane(i: U32) -> G.Plane:
  match i:
    case 0: G.XY{}
    case 1: G.YZ{}
    case _: G.ZX{}
def face_plane(i: U32) -> G.Plane:
  axis_plane((i / 2 : U32))
def next_depth(side: U32, q: G.Point) -> G.Point:
  G.Point{x,y,z} = q
  G.Point{x,y,(z + Bool.pick(U32,U32.is_eq(side,0),1,4294967295) : U32)}
def neighbor(+p: G.Plane, side: U32, q: G.Point) -> G.Point:
  G.world(p,next_depth(side,G.local(p,q)))
def exposed(+level: U32, +q: G.Point, p: G.Plane, side: U32) -> Bool:
  +next = neighbor(p,side,q)
  G.inside(q) && L.solid(level,q) && (Bool.not(G.inside(next)) || L.free(level,next))
def light(p: G.Plane) -> F32:
  match p:
    case G.XY{}: 1.0
    case G.YZ{}: 0.75
    case G.ZX{}: 0.85
