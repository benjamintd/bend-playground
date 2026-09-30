import Base
import ./tiles.bend as Tiles
import ./image.bend as ImageBuffer
import ../core/math.bend as M

type Buffers is Type:
  Buffers{px: Array<F32>, py: Array<F32>, offsets: Array<U32>, ids: Array<U32>, pixels: Array<U32>}

def color(i: U32) -> U32:
  M.word(U32.is_eq(U32.and(i, 1), 0), 4389850, 16757081)

def plot_pixel(id: U32, p: U32, px: Array<F32>, py: Array<F32>, offsets: Array<U32>, ids: Array<U32>,
  r: Array<U32> & U32) -> Buffers:
  (pixels,c) = r
  Buffers{px,py,offsets,ids,Array.set(U32,pixels,p,U32.max(c,color(id)))}

def plot_y(id: U32, x: F32, px: Array<F32>, offsets: Array<U32>, ids: Array<U32>, pixels: Array<U32>,
  r: Array<F32> & F32) -> Buffers:
  (py, y) = r
  +p = (F32.to_u32(x) + F32.to_u32(y) * 1024 : U32)
  plot_pixel(id,p,px,py,offsets,ids,Array.get(U32,pixels,p))

def plot_x(+id: U32, py: Array<F32>, offsets: Array<U32>, ids: Array<U32>, pixels: Array<U32>,
  r: Array<F32> & F32) -> Buffers:
  (px, x) = r
  plot_y(id, x, px, offsets, ids, pixels, Array.get(F32, py, id))

def plot_id(px: Array<F32>, py: Array<F32>, offsets: Array<U32>, pixels: Array<U32>,
  r: Array<U32> & U32) -> Buffers:
  (ids, +id) = r
  plot_x(id, py, offsets, ids, pixels, Array.get(F32, px, id))

def plot(i: U32, b: Buffers) -> Buffers:
  Buffers{px, py, offsets, ids, pixels} = b
  plot_id(px, py, offsets, pixels, Array.get(U32, ids, i))

def points(n: Nat, +i: U32, b: Buffers) -> Buffers:
  match n:
    case 0n: b
    case 1n+p: points(p, (i + 1 : U32), plot(i, b))

def range_end(+start: U32, px: Array<F32>, py: Array<F32>, ids: Array<U32>, pixels: Array<U32>,
  r: Array<U32> & U32) -> Buffers:
  (offsets, end) = r
  points(U32.to_nat((end - start : U32)), start, Buffers{px, py, offsets, ids, pixels})

def range_start(cell: U32, px: Array<F32>, py: Array<F32>, ids: Array<U32>, pixels: Array<U32>,
  r: Array<U32> & U32) -> Buffers:
  (offsets, start) = r
  range_end(start, px, py, ids, pixels, Array.get(U32, offsets, (cell + 1 : U32)))

def raster(+cell: U32, b: Buffers) -> Buffers:
  Buffers{px, py, offsets, ids, pixels} = b
  range_start(cell, px, py, ids, pixels, Array.get(U32, offsets, cell))

def clear(+n: Nat, +x: U32, +y: U32, pixels: Array<U32>) -> Array<U32>:
  match n:
    case 0n: pixels
    case 1n+p:
      +i = U32.from_nat(p)
      clear(p, x, y, Array.set(U32, pixels,
        (x + U32.and(i, 7) + (y + U32.shrn(i, 3n)) * 1024 : U32), 395279))

def tile_image(px: Array<F32>, py: Array<F32>, offsets: Array<U32>, ids: Array<U32>,
  r: Array<U32> & Image) -> Buffers & Image:
  (pixels, image) = r
  (Buffers{px, py, offsets, ids, pixels}, image)

def tile_done(x: U32, y: U32, b: Buffers) -> Buffers & Image:
  Buffers{px, py, offsets, ids, pixels} = b
  tile_image(px, py, offsets, ids, ImageBuffer.square8(~1024,x,y,pixels))

def tile(+x: U32, +y: U32, b: Buffers, old: Image) -> Buffers & Image:
  Buffers{px, py, offsets, ids, pixels} = b
  tile_done(x, y, raster((U32.shrn(x, 3n) + U32.shrn(y, 3n) * 128 : U32),
    Buffers{px, py, offsets, ids, clear(64n, x, y, pixels)}))

def join(a: Buffers, b: Buffers) -> Buffers:
  Buffers{ax, ay, ao, ai, ap} = a
  Buffers{bx, by, bo, bi, bp} = b
  Buffers{Array.join(F32, ax, bx), Array.join(F32, ay, by), Array.join(U32, ao, bo),
    Array.join(U32, ai, bi), Array.join(U32, ap, bp)}

def leaf(x: U32, y: U32, b: Buffers, old: Image) -> Buffers & Image:
  tile(x,y,b,old)
def render(gpu: Bool, b: Buffers, old: Image) -> Buffers & Image:
  match gpu:
    case True{}: Tiles.tree!(~Buffers,~8,~leaf,~join,7n,0,0,b,Tiles.open(old))
    case False{}: Tiles.tree(~Buffers,~8,~leaf,~join,7n,0,0,b,Tiles.open(old))
