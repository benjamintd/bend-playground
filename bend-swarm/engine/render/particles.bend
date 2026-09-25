import Base
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

def pixel(r: Array<U32> & U32) -> Array<U32> & Image:
  (pixels, c) = r
  (pixels, Pix{c})

def combine(a: Image, b: Image, c: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, d) = r
  (pixels, Qua{a, b, c, d})

# Statically unrolled tiles; no recursive continuation or fork per pixel.
def square1(x: U32, y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  pixel(Array.get(U32, pixels, (x + y * 1024 : U32)))

def square2_c(x: U32, y: U32, a: Image, b: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, c) = r
  combine(a, b, c, square1(x, y, pixels))

def square2_b(+x: U32, +y: U32, a: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, b) = r
  square2_c((x + 1 : U32), (y + 1 : U32), a, b, square1(x, (y + 1 : U32), pixels))

def square2_a(+x: U32, +y: U32, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, a) = r
  square2_b(x, y, a, square1((x + 1 : U32), y, pixels))

def square2(+x: U32, +y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  square2_a(x, y, square1(x, y, pixels))

def square4_c(x: U32, y: U32, a: Image, b: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, c) = r
  combine(a, b, c, square2(x, y, pixels))

def square4_b(+x: U32, +y: U32, a: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, b) = r
  square4_c((x + 2 : U32), (y + 2 : U32), a, b, square2(x, (y + 2 : U32), pixels))

def square4_a(+x: U32, +y: U32, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, a) = r
  square4_b(x, y, a, square2((x + 2 : U32), y, pixels))

def square4(+x: U32, +y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  square4_a(x, y, square2(x, y, pixels))

def square8_c(x: U32, y: U32, a: Image, b: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, c) = r
  combine(a, b, c, square4(x, y, pixels))

def square8_b(+x: U32, +y: U32, a: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, b) = r
  square8_c((x + 4 : U32), (y + 4 : U32), a, b, square4(x, (y + 4 : U32), pixels))

def square8_a(+x: U32, +y: U32, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, a) = r
  square8_b(x, y, a, square4((x + 4 : U32), y, pixels))

def square8(+x: U32, +y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  square8_a(x, y, square4(x, y, pixels))

def tile_image(px: Array<F32>, py: Array<F32>, offsets: Array<U32>, ids: Array<U32>,
  r: Array<U32> & Image) -> Buffers & Image:
  (pixels, image) = r
  (Buffers{px, py, offsets, ids, pixels}, image)

def tile_done(x: U32, y: U32, b: Buffers) -> Buffers & Image:
  Buffers{px, py, offsets, ids, pixels} = b
  tile_image(px, py, offsets, ids, square8(x, y, pixels))

def tile(+x: U32, +y: U32, b: Buffers, old: Image) -> Buffers & Image:
  Buffers{px, py, offsets, ids, pixels} = b
  tile_done(x, y, raster((U32.shrn(x, 3n) + U32.shrn(y, 3n) * 128 : U32),
    Buffers{px, py, offsets, ids, clear(64n, x, y, pixels)}))

def join(a: Buffers, b: Buffers) -> Buffers:
  Buffers{ax, ay, ao, ai, ap} = a
  Buffers{bx, by, bo, bi, bp} = b
  Buffers{Array.join(F32, ax, bx), Array.join(F32, ay, by), Array.join(U32, ao, bo),
    Array.join(U32, ai, bi), Array.join(U32, ap, bp)}

def joined(a: Buffers & Image, b: Buffers & Image, c: Buffers & Image, d: Buffers & Image) -> Buffers & Image:
  (ab, ai) = a
  (bb, bi) = b
  (cb, ci) = c
  (db, di) = d
  (join(join(ab, bb), join(cb, db)), Qua{ai, bi, ci, di})

type Four is Type:
  Four{a: Image, b: Image, c: Image, d: Image}

def open(old: Image) -> Four:
  match old:
    case Pix{+c}: Four{Pix{c}, Pix{c}, Pix{c}, Pix{c}}
    case Qua{a, b, c, d}: Four{a, b, c, d}

# All aliases read positions/offsets/IDs; each tile writes its disjoint pixels.
# Previous image is consumed at the same tile, distributing reclamation.
@unsafe
def tree(+depth: Nat, +x: U32, +y: U32, +b: Buffers, old: Four) -> Buffers & Image:
  match depth:
    case 0n:
      Four{a, c, d, e} = old
      tile(x, y, b, Qua{a, c, d, e})
    case 1n+p:
      Four{oa, ob, oc, od} = old
      +h = U32.shln(8, p)
      a c d e = tree(p, x, y, b, open(oa)) tree(p, (x + h : U32), y, b, open(ob))
        tree(p, x, (y + h : U32), b, open(oc)) tree(p, (x + h : U32), (y + h : U32), b, open(od))
      joined(a, c, d, e)

def render(gpu: Bool, b: Buffers, old: Image) -> Buffers & Image:
  match gpu:
    case True{}: tree!(7n, 0, 0, b, open(old))
    case False{}: tree(7n, 0, 0, b, open(old))
