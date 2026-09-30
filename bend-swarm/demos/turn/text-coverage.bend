import Base
import ../../engine/render/mesh.bend as M
import ../../engine/render/coverage.bend as Coverage
import ../../engine/render/tiles.bend as Tiles

# TURN's lettering occupies depth 1. Resolve four samples only in tiles that
# contain text. World tiles retain the fast single-sample path. Both paths use
# the engine's existing rasterizers and the same owned buffers / tile scheduler.
type Scan is Type:
  Scan{triangles: Array<M.Triangle>, ids: Array<U32>, found: Bool}
def is_text(t: M.Triangle) -> Bool:
  M.Triangle{M.Vertex{_,_,a,_},M.Vertex{_,_,b,_},M.Vertex{_,_,c,_},_} = t
  F32.is_eq(a,1.0) && F32.is_eq(b,1.0) && F32.is_eq(c,1.0)
def read_triangle(ids: Array<U32>, r: Array<M.Triangle> & M.Triangle) -> Scan:
  (tris,t) = r
  Scan{tris,ids,is_text(t)}
def read_id(tris: Array<M.Triangle>, r: Array<U32> & U32) -> Scan:
  (ids,id) = r
  read_triangle(ids,Array.get(M.Triangle,tris,id))
def candidates(n: Nat, +i: U32, scan: Scan) -> Scan:
  match n scan:
    case _ Scan{tris,ids,True{}}: Scan{tris,ids,True{}}
    case 0n Scan{tris,ids,False{}}: Scan{tris,ids,False{}}
    case 1n+k Scan{tris,ids,False{}}: candidates(k,(i + 1 : U32),read_id(tris,Array.get(U32,ids,i)))
def selected(+x: U32, +y: U32, offsets: Array<U32>, pixels: Array<U32>, fragments: Array<M.Fragment>,
  r: Scan) -> M.Drawing:
  Scan{tris,ids,text} = r
  match text:
    case False{}: M.raster(~1n,x,y,M.Drawing{tris,offsets,ids,pixels,fragments})
    case True{}:
      +cell = (x / 8 + y / 8 * 128 : U32)
      Coverage.start(~1n,cell,tris,ids,pixels,fragments,Array.get(U32,offsets,cell))
def end(x: U32, y: U32, +first: U32, tris: Array<M.Triangle>, ids: Array<U32>, pixels: Array<U32>, fragments: Array<M.Fragment>, r: Array<U32> & U32) -> M.Drawing:
  (offsets,last) = r
  selected(x,y,offsets,pixels,fragments,candidates(U32.to_nat((last - first : U32)),first,Scan{tris,ids,False{}}))
def start(x: U32, y: U32, cell: U32, tris: Array<M.Triangle>, ids: Array<U32>, pixels: Array<U32>, fragments: Array<M.Fragment>, r: Array<U32> & U32) -> M.Drawing:
  (offsets,first) = r
  end(x,y,first,tris,ids,pixels,fragments,Array.get(U32,offsets,(cell + 1 : U32)))
def raster(+x: U32, +y: U32, b: M.Drawing) -> M.Drawing:
  M.Drawing{tris,offsets,ids,pixels,fragments} = b
  +cell = (x / 8 + y / 8 * 128 : U32)
  start(x,y,cell,tris,ids,pixels,fragments,Array.get(U32,offsets,cell))
def tile(+x: U32, +y: U32, b: M.Drawing, old: Image) -> M.Drawing & Image:
  M.tile8_done(~1n,x,y,raster((x + 8 : U32),(y + 8 : U32),
    raster(x,(y + 8 : U32),raster((x + 8 : U32),y,raster(x,y,b)))))
def leaf(x: U32, y: U32, b: M.Drawing, old: Image) -> M.Drawing & Image:
  tile(x,y,b,old)
def draw(gpu: Bool, b: M.Drawing, old: Image) -> M.Drawing & Image:
  match gpu:
    case True{}: Tiles.tree!(~M.Drawing,~16,~leaf,~M.join,6n,0,0,b,Tiles.open(old))
    case False{}: Tiles.tree(~M.Drawing,~16,~leaf,~M.join,6n,0,0,b,Tiles.open(old))
