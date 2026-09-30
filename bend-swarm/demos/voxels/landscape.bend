import Base
import ../../engine/voxel/world.bend as W
import ../../engine/camera.bend as C
import ../../engine/core/vec3.bend as V
import ../../engine/spatial/layout.bend as L
import ../../engine/geometry/solid.bend as Solid
import ../../engine/render/project.bend as P
import ../../engine/render/batch.bend as B

# Sixteen 8x16x8 chunks. The bounded world is deliberately editable in all axes,
# including caves/overhangs. Cached faces are rebuilt only after a local edit.
type Cache is Data:
  Empty{}
  Chunk{id: U32, faces: List<&2, P.Triangle>, next: Cache}
type Landscape is Type:
  Landscape{world: W.World, cache: Cache, dirty: U32, rebuilt: U32}
def terrain(+x: F32, +y: F32, +z: F32) -> U32:
  +height = (5.0 + 2.0 * F32.sin((x * 0.24 : F32)) + 2.0 * F32.cos((z * 0.2 : F32))
    + 1.5 * F32.sin(((x + z) * 0.31 : F32)) : F32)
  +tunnel = (F32.square((y - 3.0 : F32)) + F32.square((z - 16.0 : F32)) < 6.5 : F32)
    && (x > 3.0 : F32) && (x < 29.0 : F32)
  L.word((y < height : F32) && Bool.not(tunnel),L.word((y + 1.0 >= height : F32),1,L.word((y > 2.0 : F32),2,3)),0)
def fill(+n: Nat, cells: Array<U32>) -> Array<U32>:
  match n:
    case 0n: cells
    case 1n+k:
      +i = U32.from_nat(k)
      fill(k,Array.set(U32,cells,i,terrain(U32.to_f32((i % 32 : U32)),U32.to_f32(((i / 32) % 16 : U32)),U32.to_f32((i / 512 : U32)))))
def chunks(+n: Nat) -> Cache:
  match n:
    case 0n: Empty{}
    case 1n+k: Chunk{U32.from_nat(k),Nil{},chunks(k)}
def create() -> Landscape:
  Landscape{W.World{fill(16384n,Array.new(U32,14n,0)),32,16,32},chunks(16n),65535,0}
def neighbor(face: U32) -> L.Point:
  match face:
    case 0: L.Point{F32.neg(1.0),0.0,0.0}
    case 1: L.Point{1.0,0.0,0.0}
    case 2: L.Point{0.0,F32.neg(1.0),0.0}
    case 3: L.Point{0.0,1.0,0.0}
    case 4: L.Point{0.0,0.0,F32.neg(1.0)}
    case _: L.Point{0.0,0.0,1.0}
def tint(material: U32, +face: U32) -> U32:
  match material:
    case 1: L.word(U32.is_eq(face,3),8176278,L.word(U32.is_eq(face,1) || U32.is_eq(face,4),5275239,6525558))
    case 2: L.word(U32.is_eq(face,3),13209494,L.word(U32.is_eq(face,1) || U32.is_eq(face,4),9206383,11114369))
    case _: L.word(U32.is_eq(face,3),10004896,L.word(U32.is_eq(face,1) || U32.is_eq(face,4),5923448,7633049))
def face_quad(face: U32, p: L.Point, color: U32, out: List<&2, P.Triangle>) -> List<&2, P.Triangle>:
  match face:
    case 0:
      L.Point{+x,+y,+z} = p
      Solid.quad(L.Point{x,y,z},L.Point{x,(y + 1.0 : F32),z},L.Point{x,(y + 1.0 : F32),(z + 1.0 : F32)},L.Point{x,y,(z + 1.0 : F32)},color,out)
    case 1:
      L.Point{x,+y,+z} = p
      +a = (x + 1.0 : F32)
      Solid.quad(L.Point{a,y,z},L.Point{a,y,(z + 1.0 : F32)},L.Point{a,(y + 1.0 : F32),(z + 1.0 : F32)},L.Point{a,(y + 1.0 : F32),z},color,out)
    case 2:
      L.Point{+x,+y,+z} = p
      Solid.quad(L.Point{x,y,z},L.Point{(x + 1.0 : F32),y,z},L.Point{(x + 1.0 : F32),y,(z + 1.0 : F32)},L.Point{x,y,(z + 1.0 : F32)},color,out)
    case 3:
      L.Point{+x,y,+z} = p
      +a = (y + 1.0 : F32)
      Solid.quad(L.Point{x,a,z},L.Point{x,a,(z + 1.0 : F32)},L.Point{(x + 1.0 : F32),a,(z + 1.0 : F32)},L.Point{(x + 1.0 : F32),a,z},color,out)
    case 4:
      L.Point{+x,+y,+z} = p
      Solid.quad(L.Point{x,y,z},L.Point{x,(y + 1.0 : F32),z},L.Point{(x + 1.0 : F32),(y + 1.0 : F32),z},L.Point{(x + 1.0 : F32),y,z},color,out)
    case _:
      L.Point{+x,+y,z} = p
      +a = (z + 1.0 : F32)
      Solid.quad(L.Point{x,y,a},L.Point{(x + 1.0 : F32),y,a},L.Point{(x + 1.0 : F32),(y + 1.0 : F32),a},L.Point{x,(y + 1.0 : F32),a},color,out)
def exposed(empty: Bool, face: U32, p: L.Point, color: U32, out: List<&2, P.Triangle>) -> List<&2, P.Triangle>:
  match empty:
    case False{}: out
    case True{}: face_quad(face,p,color,out)
def face_read(face: U32, p: L.Point, color: U32, out: List<&2, P.Triangle>, r: W.World & U32) -> W.World & List<&2, P.Triangle>:
  (world,value) = r
  (world,exposed(U32.is_eq(value,0),face,p,color,out))
def faces(+n: Nat, +p: L.Point, +material: U32, r: W.World & List<&2, P.Triangle>) -> W.World & List<&2, P.Triangle>:
  match n:
    case 0n: r
    case 1n+k:
      (world,out) = r
      +f = U32.from_nat(k)
      faces(k,p,material,face_read(f,p,tint(material,f),out,W.read(world,V.add(p,neighbor(f)))))
def occupied(yes: Bool, p: L.Point, material: U32, world: W.World, out: List<&2, P.Triangle>) -> W.World & List<&2, P.Triangle>:
  match yes:
    case False{}: (world,out)
    case True{}: faces(6n,p,material,(world,out))
def cell_read(p: L.Point, out: List<&2, P.Triangle>, r: W.World & U32) -> W.World & List<&2, P.Triangle>:
  (world,+value) = r
  occupied(U32.is_ne(value,0),p,value,world,out)
def mesh(+n: Nat, +cx: U32, +cz: U32, r: W.World & List<&2, P.Triangle>) -> W.World & List<&2, P.Triangle>:
  match n:
    case 0n: r
    case 1n+k:
      (world,out) = r
      +i = U32.from_nat(k)
      +p = {L.Point{U32.to_f32((cx * 8 + i % 8 : U32)),U32.to_f32(((i / 8) % 16 : U32)),U32.to_f32((cz * 8 + i / 128 : U32))} : L.Point}
      mesh(k,cx,cz,cell_read(p,out,W.read(world,p)))
def rebuild(yes: Bool, +id: U32, world: W.World, faces: List<&2, P.Triangle>) -> W.World & List<&2, P.Triangle>:
  match yes:
    case False{}: (world,faces)
    case True{}: mesh(1024n,(id % 4 : U32),(id / 4 : U32),(world,Nil{}))
def update_node(id: U32, tail: Cache, r: W.World & List<&2, P.Triangle>) -> W.World & Cache:
  (world,faces) = r
  (world,Chunk{id,faces,tail})
def update_tail(+dirty: U32, +id: U32, faces: List<&2, P.Triangle>, r: W.World & Cache) -> W.World & Cache:
  (world,tail) = r
  update_node(id,tail,rebuild(U32.is_ne(U32.and(dirty,U32.shln(1,U32.to_nat(id))),0),id,world,faces))
def update(cache: Cache, +dirty: U32, world: W.World) -> W.World & Cache:
  match cache:
    case Empty{}: (world,Empty{})
    case Chunk{id,faces,tail}: update_tail(dirty,id,faces,update(tail,dirty,world))
def clean_result(rebuilt: U32, r: W.World & Cache) -> Landscape:
  (world,cache) = r
  Landscape{world,cache,0,rebuilt}
def count_bits(n: Nat, +bits: U32) -> U32:
  match n:
    case 0n: 0
    case 1n+k: (U32.and(bits,1) + count_bits(k,U32.shrn(bits,1n)) : U32)
def clean(s: Landscape) -> Landscape:
  Landscape{world,cache,+dirty,_} = s
  clean_result(count_bits(16n,dirty),update(cache,dirty,world))
def projected(visible: Bool, view: C.View, faces: List<&2, P.Triangle>, out: B.Batch) -> B.Batch:
  match visible:
    case False{}: out
    case True{}: P.triangles(faces,view,out)
def draw(cache: Cache, +view: C.View, out: B.Batch) -> B.Batch:
  match cache:
    case Empty{}: out
    case Chunk{+id,faces,tail}:
      +x = U32.to_f32(((id % 4) * 8 : U32))
      +z = U32.to_f32(((id / 4) * 8 : U32))
      draw(tail,view,projected(C.intersects_bounds(view,L.Point{x,0.0,z},L.Point{(x + 8.0 : F32),16.0,(z + 8.0 : F32)}),view,faces,out))
def mark_valid(valid: Bool, x: F32, z: F32, mask: U32) -> U32:
  match valid:
    case False{}: mask
    case True{}: U32.or(mask,U32.shln(1,U32.to_nat((F32.to_u32((x / 8.0 : F32)) + F32.to_u32((z / 8.0 : F32)) * 4 : U32))))
def mark(+x: F32, +z: F32, mask: U32) -> U32:
  mark_valid((x >= 0.0 : F32) && (z >= 0.0 : F32) && (x < 32.0 : F32) && (z < 32.0 : F32),x,z,mask)
def dirty(p: L.Point, mask: U32) -> U32:
  L.Point{+x,_,+z} = p
  mark(x,z,mark((x - 1.0 : F32),z,mark((x + 1.0 : F32),z,mark(x,(z - 1.0 : F32),mark(x,(z + 1.0 : F32),mask)))))
def edit_valid(valid: Bool, s: Landscape, +p: L.Point, value: U32) -> Landscape:
  match valid:
    case False{}: s
    case True{}:
      Landscape{world,cache,mask,rebuilt} = s
      Landscape{W.write(world,p,value),cache,dirty(p,mask),rebuilt}
def edit(s: Landscape, +p: L.Point, value: U32) -> Landscape:
  edit_valid(W.inside(p,32,16,32),s,p,value)
def blast(+n: Nat, +center: L.Point, s: Landscape) -> Landscape:
  match n:
    case 0n: s
    case 1n+k:
      +i = U32.from_nat(k)
      +d = {L.Point{(U32.to_f32((i % 5 : U32)) - 2.0 : F32),(U32.to_f32(((i / 5) % 5 : U32)) - 2.0 : F32),(U32.to_f32((i / 25 : U32)) - 2.0 : F32)} : L.Point}
      blast(k,center,edit_valid((V.length(d) <= 2.2 : F32),s,V.add(center,d),0))
def apply_hit(add: Bool, +cell: L.Point, normal: L.Point, s: Landscape) -> Landscape:
  match add:
    case True{}: edit(s,V.add(cell,normal),1)
    case False{}: blast(125n,cell,s)
def hit(add: Bool, cache: Cache, dirty: U32, rebuilt: U32, r: W.World & Maybe<&2, W.Hit>) -> Landscape:
  (world,h) = r
  match h:
    case None{}: Landscape{world,cache,dirty,rebuilt}
    case Some{W.Hit{cell,normal,_,_}}:
      apply_hit(add,cell,normal,Landscape{world,cache,dirty,rebuilt})
def pick(s: Landscape, ray: C.Ray, add: Bool) -> Landscape:
  Landscape{world,cache,dirty,rebuilt} = s
  hit(add,cache,dirty,rebuilt,W.raycast(world,ray))
