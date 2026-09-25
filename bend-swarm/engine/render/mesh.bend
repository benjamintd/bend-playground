import Base
import ../parallel/regions.bend as Region
import ../spatial/internal/index.bend as Scan
import ../spatial/layout.bend as L

# Flat Data records compile to packed scalar array elements, not heap objects.
# Screen coordinates are in the selected render target; z is camera depth.
type Vertex is Data:
  Vertex{x: F32, y: F32, z: F32, light: F32}
type Triangle is Data:
  Triangle{a: Vertex, b: Vertex, c: Vertex, color: U32}
type Fragment is Data:
  Fragment{depth: F32, color: U32}
type Bounds is Data:
  Bounds{x: U32, y: U32, width: U32, height: U32}
type Index is Type:
  Index{counts: Array<U32>, offsets: Array<U32>, cursors: Array<U32>, ids: Array<U32>, capacity: U32}

def empty() -> Index:
  Index{Array.new(U32,14n,0),Array.new(U32,15n,0),Array.new(U32,14n,0),Array.new(U32,18n,0),262144}

def blank() -> Triangle:
  Triangle{Vertex{0.0,0.0,0.0,1.0},Vertex{0.0,0.0,0.0,1.0},Vertex{0.0,0.0,0.0,1.0},0}

def extent(~level: Nat,visible: Bool, +x: F32, +y: F32, mx: F32, my: F32) -> Bounds:
  match visible:
    case False{}: Bounds{0,0,0,0}
    case True{}:
      +tx = F32.to_u32((F32.max(x,0.0) / U32.to_f32(U32.shln(4,level)) : F32))
      +ty = F32.to_u32((F32.max(y,0.0) / U32.to_f32(U32.shln(4,level)) : F32))
      Bounds{tx,ty,(F32.to_u32((F32.min(mx,U32.to_f32((U32.shln(512,level) - 1 : U32))) / U32.to_f32(U32.shln(4,level)) : F32)) - tx + 1 : U32),
        (F32.to_u32((F32.min(my,U32.to_f32((U32.shln(512,level) - 1 : U32))) / U32.to_f32(U32.shln(4,level)) : F32)) - ty + 1 : U32)}

def bounds_level(~level: Nat,t: Triangle) -> Bounds:
  Triangle{Vertex{+ax,+ay,az,_},Vertex{+bx,+by,bz,_},Vertex{+cx,+cy,cz,_},_} = t
  +x = F32.min(ax,F32.min(bx,cx))
  +y = F32.min(ay,F32.min(by,cy))
  +mx = F32.max(ax,F32.max(bx,cx))
  +my = F32.max(ay,F32.max(by,cy))
  extent(~level,(F32.min(az,F32.min(bz,cz)) > 0.1 : F32) && (mx >= 0.0 : F32) && (my >= 0.0 : F32)
    && (x < U32.to_f32(U32.shln(512,level)) : F32) && (y < U32.to_f32(U32.shln(512,level)) : F32),x,y,mx,my)

type Binning is Type:
  Binning{triangles: Array<Triangle>, counts: Array<U32>, ids: Array<U32>}

def incremented(scatter: Bool, id: U32, tris: Array<Triangle>, ids: Array<U32>, r: Array<U32> & U32) -> Binning:
  match scatter:
    case False{}:
      (counts,_) = r
      Binning{tris,counts,ids}
    case True{}:
      (counts,slot) = r
      Binning{tris,counts,Array.set(U32,ids,slot,id)}

def cells(~level: Nat,+n: Nat, +x: U32, +y: U32, +width: U32, +scatter: Bool, +id: U32, b: Binning) -> Binning:
  match n:
    case 0n: b
    case 1n+k:
      Binning{tris,counts,ids} = b
      +i = U32.from_nat(k)
      cells(~level,k,x,y,width,scatter,id,incremented(scatter,id,tris,ids,
        Array.atomic.add(counts,(x + i % width + (y + i / width) * 128 : U32),1)))

def bounded(~level: Nat,scatter: Bool, id: U32, b: Binning, box: Bounds) -> Binning:
  Bounds{x,y,+width,height} = box
  cells(~level,U32.to_nat((width * height : U32)),x,y,width,scatter,id,b)

def bin_read(~level: Nat,scatter: Bool, id: U32, counts: Array<U32>, ids: Array<U32>, r: Array<Triangle> & Triangle) -> Binning:
  (tris,t) = r
  bounded(~level,scatter,id,Binning{tris,counts,ids},bounds_level(~level,t))

def bin_loop(~level: Nat,n: Nat, +i: U32, +scatter: Bool, b: Binning) -> Binning:
  match n:
    case 0n: b
    case 1n+k:
      Binning{tris,counts,ids} = b
      bin_loop(~level,k,(i + 1 : U32),scatter,bin_read(~level,scatter,i,counts,ids,Array.get(Triangle,tris,i)))

def bin_leaf(~level: Nat,~scatter: Bool, start: U32, n: U32, b: Binning) -> Binning:
  bin_loop(~level,U32.to_nat(n),start,scatter,b)

def bin_join(a: Binning, b: Binning) -> Binning:
  Binning{at,ac,ai} = a
  Binning{bt,bc,bi} = b
  Binning{Array.join(Triangle,at,bt),Array.join(U32,ac,bc),Array.join(U32,ai,bi)}

def bin(~level: Nat,~scatter: Bool, +n: U32, b: Binning) -> Binning:
  Region.run(~Binning,~bin_leaf(~level,~scatter),~bin_join,U32.log2(U32.max(n,1)),0,n,b)

def bin_run(~level: Nat,~scatter: Bool, gpu: Bool, n: U32, b: Binning) -> Binning:
  match gpu:
    case True{}: bin!(~level,~scatter,n,b)
    case False{}: bin_loop(~level,U32.to_nat(n),0,scatter,b)

def scatter_done(counts: Array<U32>, offsets: Array<U32>, cap: U32, b: Binning) -> Array<Triangle> & Index:
  Binning{tris,cursors,ids} = b
  (tris,Index{counts,offsets,cursors,ids,cap})

def storage(grow: Bool, +total: U32, ids: Array<U32>, cap: U32) -> Array<U32> & U32:
  match grow:
    case False{}: (ids,cap)
    case True{}:
      +depth = Nat.add(1n,U32.log2(U32.max((total - 1 : U32),1)))
      (Array.new(U32,depth,0),U32.shln(1,depth))

def ready(~level: Nat,gpu: Bool, n: U32, tris: Array<Triangle>, counts: Array<U32>, offsets: Array<U32>, cursors: Array<U32>,
  r: Array<U32> & U32) -> Array<Triangle> & Index:
  (ids,cap) = r
  scatter_done(counts,offsets,cap,bin_run(~level,~True{},gpu,n,Binning{tris,cursors,ids}))

def scanned(~level: Nat,gpu: Bool, n: U32, tris: Array<Triangle>, ids: Array<U32>, +cap: U32, s: Scan.Scan) -> Array<Triangle> & Index:
  Scan.Scan{counts,offsets,cursors,+total} = s
  ready(~level,gpu,n,tris,counts,offsets,cursors,storage((total > cap : U32),total,ids,cap))

def histogrammed(~level: Nat,gpu: Bool, n: U32, offsets: Array<U32>, cursors: Array<U32>, cap: U32, b: Binning) -> Array<Triangle> & Index:
  Binning{tris,counts,ids} = b
  scanned(~level,gpu,n,tris,ids,cap,Scan.scan_loop(16384n,0,Scan.Scan{counts,offsets,cursors,0}))

def build_level(~level: Nat,+gpu: Bool, +n: U32, tris: Array<Triangle>, index: Index) -> Array<Triangle> & Index:
  Index{counts,offsets,cursors,ids,cap} = index
  histogrammed(~level,gpu,n,offsets,cursors,cap,bin_run(~level,~False{},gpu,n,Binning{tris,counts,ids}))

# Perspective-correct depth with a two-sided, opaque surface. Stable tie rule.
def choose(inside: Bool, +depth: F32, color: U32, old: Fragment) -> Fragment:
  match inside:
    case False{}: old
    case True{}:
      Fragment{+z,+c} = old
      +ink = color
      Fragment{F32.min(z,depth),L.word((depth < z : F32),ink,L.word(F32.is_eq(depth,z),U32.max(ink,c),c))}

def shaded(+color: U32, +light: F32) -> U32:
  (F32.to_u32(F32.min(255.0,(U32.to_f32(U32.and(U32.shrn(color,16n),255)) * light : F32))) * 65536
    + F32.to_u32(F32.min(255.0,(U32.to_f32(U32.and(U32.shrn(color,8n),255)) * light : F32))) * 256
    + F32.to_u32(F32.min(255.0,(U32.to_f32(U32.and(color,255)) * light : F32))) : U32)

def barycentric(valid: Bool, u: F32, +v: F32, +w: F32, az: F32, bz: F32, cz: F32, +al: F32, bl: F32, cl: F32, color: U32, old: Fragment) -> Fragment:
  match valid:
    case False{}: old
    case True{}: choose(True{},
      (1.0 / F32.max((u / az + v / bz + w / cz : F32),0.000001) : F32),shaded(color,F32.max(0.0,(al + v * (bl - al) + w * (cl - al) : F32))),old)

def weights(nonzero: Bool, +x: F32, +y: F32, +ax: F32, +ay: F32, +az: F32,
  +bx: F32, +by: F32, +bz: F32, +cx: F32, +cy: F32, +cz: F32, +den: F32, al: F32, bl: F32, cl: F32, color: U32, old: Fragment) -> Fragment:
  match nonzero:
    case False{}: old
    case True{}:
      +u = (((by - cy) * (x - cx) + (cx - bx) * (y - cy)) / den : F32)
      +v = (((cy - ay) * (x - cx) + (ax - cx) * (y - cy)) / den : F32)
      +w = (1.0 - u - v : F32)
      # Bend evaluates arguments eagerly. Reject misses before depth and
      # lighting work, rather than computing a color that choose discards.
      barycentric((F32.min(az,F32.min(bz,cz)) > 0.1 : F32) && (u >= 0.0 : F32)
        && (v >= 0.0 : F32) && (w >= 0.0 : F32),u,v,w,az,bz,cz,al,bl,cl,color,old)

def sample(x: F32, y: F32, t: Triangle, old: Fragment) -> Fragment:
  Triangle{Vertex{+ax,+ay,az,al},Vertex{+bx,+by,bz,bl},Vertex{+cx,+cy,cz,cl},color} = t
  +den = ((by - cy) * (ax - cx) + (cx - bx) * (ay - cy) : F32)
  weights((F32.abs(den) > 0.00001 : F32),x,y,ax,ay,az,bx,by,bz,cx,cy,cz,den,al,bl,cl,color,old)

# Allocate two framebuffer areas of Fragment. The first half is a static
# backdrop_level, refilled only when camera/background changes. Raster reads it
# immutably and writes resolved current-frame fragments into the second half.
def backdrop_loop(~level: Nat, ~background: U32 -> U32 -> Fragment, n: Nat, +i: U32, out: Array<Fragment>) -> Array<Fragment>:
  match n:
    case 0n: out
    case 1n+k:
      +width = U32.shln(512,level)
      backdrop_loop(~level,~background,k,(i + 1 : U32),Array.set(Fragment,out,i,background((i % width : U32),(i / width : U32))))
def backdrop_leaf(~level: Nat, ~background: U32 -> U32 -> Fragment, i: U32, n: U32, out: Array<Fragment>) -> Array<Fragment>:
  backdrop_loop(~level,~background,U32.to_nat(n),i,out)
def backdrop_level(~level: Nat, ~background: U32 -> U32 -> Fragment, out: Array<Fragment>) -> Array<Fragment>:
  Region.run(~Array<Fragment>,~backdrop_leaf(~level,~background),~Array.join(Fragment),6n,0,U32.shln(262144,Nat.add(level,level)),out)

type Query is Type:
  Query{triangles: Array<Triangle>, ids: Array<U32>, result: Fragment}

def sampled(x: F32, y: F32, ids: Array<U32>, old: Fragment, r: Array<Triangle> & Triangle) -> Query:
  (tris,t) = r
  Query{tris,ids,sample(x,y,t,old)}

def queried(x: F32, y: F32, tris: Array<Triangle>, old: Fragment, r: Array<U32> & U32) -> Query:
  (ids,id) = r
  sampled(x,y,ids,old,Array.get(Triangle,tris,id))

def query(n: Nat, +i: U32, +x: F32, +y: F32, q: Query) -> Query:
  match n:
    case 0n: q
    case 1n+k:
      Query{tris,ids,old} = q
      query(k,(i + 1 : U32),x,y,queried(x,y,tris,old,Array.get(U32,ids,i)))

type Drawing is Type:
  Drawing{triangles: Array<Triangle>, offsets: Array<U32>, ids: Array<U32>, pixels: Array<U32>, background: Array<Fragment>}

def written(~level: Nat, +i: U32, offsets: Array<U32>, pixels: Array<U32>, background: Array<Fragment>, q: Query) -> Drawing:
  Query{tris,ids,+fragment} = q
  Fragment{_,color} = fragment
  Drawing{tris,offsets,ids,Array.set(U32,pixels,i,color),Array.set(Fragment,background,(U32.shln(262144,Nat.add(level,level)) + i : U32),fragment)}

def background_read(~level: Nat, i: U32, x: F32, y: F32, start: U32, count: U32,
  tris: Array<Triangle>, offsets: Array<U32>, ids: Array<U32>, out: Array<U32>, r: Array<Fragment> & Fragment) -> Drawing:
  (background,fragment) = r
  written(~level,i,offsets,out,background,query(U32.to_nat(count),start,x,y,Query{tris,ids,fragment}))

def pixels(~level: Nat, +n: Nat, +x: U32, +y: U32, +start: U32, +count: U32, b: Drawing) -> Drawing:
  match n:
    case 0n: b
    case 1n+k:
      Drawing{tris,offsets,ids,out,background} = b
      +i = U32.from_nat(k)
      +px = (x + U32.and(i,(U32.shln(4,level) - 1 : U32)) : U32)
      +py = (y + U32.shrn(i,Nat.add(level,2n)) : U32)
      pixels(~level,k,x,y,start,count,background_read(~level,(px + py * U32.shln(512,level) : U32),
        (U32.to_f32(px) + 0.5 : F32),(U32.to_f32(py) + 0.5 : F32),start,count,tris,offsets,ids,out,
        Array.get(Fragment,background,(px + py * U32.shln(512,level) : U32))))

def range_end(~level: Nat, x: U32, y: U32, +start: U32,
  tris: Array<Triangle>, ids: Array<U32>, out: Array<U32>, background: Array<Fragment>, r: Array<U32> & U32) -> Drawing:
  (offsets,end) = r
  pixels(~level,U32.to_nat(U32.shln(16,Nat.add(level,level))),x,y,start,(end - start : U32),Drawing{tris,offsets,ids,out,background})

def range_start(~level: Nat, x: U32, y: U32, cell: U32,
  tris: Array<Triangle>, ids: Array<U32>, out: Array<U32>, background: Array<Fragment>, r: Array<U32> & U32) -> Drawing:
  (offsets,start) = r
  range_end(~level,x,y,start,tris,ids,out,background,Array.get(U32,offsets,(cell + 1 : U32)))

def raster(~level: Nat, +x: U32, +y: U32, b: Drawing) -> Drawing:
  Drawing{tris,offsets,ids,out,background} = b
  +cell = (U32.shrn(x,Nat.add(level,2n)) + U32.shrn(y,Nat.add(level,2n)) * 128 : U32)
  range_start(~level,x,y,cell,tris,ids,out,background,Array.get(U32,offsets,cell))

def pixel(r: Array<U32> & U32) -> Array<U32> & Image:
  (pixels, c) = r
  (pixels, Pix{c})

def combine(a: Image, b: Image, c: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, d) = r
  (pixels, Qua{a, b, c, d})

# Statically unrolled tiles; no recursive continuation or fork per pixel.
def square1(~level: Nat,x: U32, y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  pixel(Array.get(U32, pixels, (x + y * U32.shln(512,level) : U32)))

def square2_c(~level: Nat,x: U32, y: U32, a: Image, b: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, c) = r
  combine(a, b, c, square1(~level,x, y, pixels))

def square2_b(~level: Nat,+x: U32, +y: U32, a: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, b) = r
  square2_c(~level,(x + 1 : U32), (y + 1 : U32), a, b, square1(~level,x, (y + 1 : U32), pixels))

def square2_a(~level: Nat,+x: U32, +y: U32, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, a) = r
  square2_b(~level,x, y, a, square1(~level,(x + 1 : U32), y, pixels))

def square2(~level: Nat,+x: U32, +y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  square2_a(~level,x, y, square1(~level,x, y, pixels))

def square4_c(~level: Nat,x: U32, y: U32, a: Image, b: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, c) = r
  combine(a, b, c, square2(~level,x, y, pixels))

def square4_b(~level: Nat,+x: U32, +y: U32, a: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, b) = r
  square4_c(~level,(x + 2 : U32), (y + 2 : U32), a, b, square2(~level,x, (y + 2 : U32), pixels))

def square4_a(~level: Nat,+x: U32, +y: U32, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, a) = r
  square4_b(~level,x, y, a, square2(~level,(x + 2 : U32), y, pixels))

def square4(~level: Nat,+x: U32, +y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  square4_a(~level,x, y, square2(~level,x, y, pixels))

def square8_c(~level: Nat,x: U32, y: U32, a: Image, b: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, c) = r
  combine(a, b, c, square4(~level,x, y, pixels))

def square8_b(~level: Nat,+x: U32, +y: U32, a: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, b) = r
  square8_c(~level,(x + 4 : U32), (y + 4 : U32), a, b, square4(~level,x, (y + 4 : U32), pixels))

def square8_a(~level: Nat,+x: U32, +y: U32, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, a) = r
  square8_b(~level,x, y, a, square4(~level,(x + 4 : U32), y, pixels))

def square8_level(~level: Nat,+x: U32, +y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  square8_a(~level,x, y, square4(~level,x, y, pixels))
def square16_c(~level: Nat,x: U32, y: U32, a: Image, b: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, c) = r
  combine(a, b, c, square8_level(~level,x, y, pixels))

def square16_b(~level: Nat,+x: U32, +y: U32, a: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, b) = r
  square16_c(~level,(x + 8 : U32), (y + 8 : U32), a, b, square8_level(~level,x, (y + 8 : U32), pixels))

def square16_a(~level: Nat,+x: U32, +y: U32, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, a) = r
  square16_b(~level,x, y, a, square8_level(~level,(x + 8 : U32), y, pixels))

def square16(~level: Nat,+x: U32, +y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  square16_a(~level,x, y, square8_level(~level,x, y, pixels))

def tile_image(tris: Array<Triangle>, offsets: Array<U32>, ids: Array<U32>, background: Array<Fragment>, r: Array<U32> & Image) -> Drawing & Image:
  (pixels,image) = r
  (Drawing{tris,offsets,ids,pixels,background},image)

def square32_c(~level: Nat,x: U32, y: U32, a: Image, b: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels,c) = r
  combine(a,b,c,square16(~level,x,y,pixels))
def square32_b(~level: Nat,+x: U32, +y: U32, a: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels,b) = r
  square32_c(~level,(x + 16 : U32),(y + 16 : U32),a,b,square16(~level,x,(y + 16 : U32),pixels))
def square32_a(~level: Nat,+x: U32, +y: U32, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels,a) = r
  square32_b(~level,x,y,a,square16(~level,(x + 16 : U32),y,pixels))
def square32(~level: Nat,+x: U32, +y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  square32_a(~level,x,y,square16(~level,x,y,pixels))
def square_gpu(~level: Nat, size: U32, x: U32, y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  match size:
    case 0: square4(~level,x,y,pixels)
    case 1: square8_level(~level,x,y,pixels)
    case _: square16(~level,x,y,pixels)
def square_cpu(~level: Nat, size: U32, x: U32, y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  match size:
    case 0: square8_level(~level,x,y,pixels)
    case 1: square16(~level,x,y,pixels)
    case _: square32(~level,x,y,pixels)
def square_leaf_level(~level: Nat, small: Bool, x: U32, y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  match small:
    case True{}: square_gpu(~level,U32.from_nat(level),x,y,pixels)
    case False{}: square_cpu(~level,U32.from_nat(level),x,y,pixels)

def tile_done(~level: Nat,x: U32, y: U32, b: Drawing) -> Drawing & Image:
  Drawing{tris,offsets,ids,pixels,background} = b
  tile_image(tris,offsets,ids,background,square_leaf_level(~level,True{},x,y,pixels))

def tile(~level: Nat, +x: U32, +y: U32, b: Drawing, old: Image) -> Drawing & Image:
  tile_done(~level,x,y,raster(~level,x,y,b))

def tile8_done(~level: Nat,x: U32, y: U32, b: Drawing) -> Drawing & Image:
  Drawing{tris,offsets,ids,pixels,background} = b
  tile_image(tris,offsets,ids,background,square_leaf_level(~level,False{},x,y,pixels))
def tile8(~level: Nat, +x: U32, +y: U32, b: Drawing, old: Image) -> Drawing & Image:
  tile8_done(~level,x,y,raster(~level,(x + U32.shln(4,level) : U32),(y + U32.shln(4,level) : U32),
    raster(~level,x,(y + U32.shln(4,level) : U32),raster(~level,(x + U32.shln(4,level) : U32),y,raster(~level,x,y,b)))))
def tile_size(~level: Nat, small: Bool, x: U32, y: U32, b: Drawing, old: Image) -> Drawing & Image:
  match small:
    case True{}: tile(~level,x,y,b,old)
    case False{}: tile8(~level,x,y,b,old)

def join(a: Drawing, b: Drawing) -> Drawing:
  Drawing{at,ao,ai,ap,ab} = a
  Drawing{bt,bo,bi,bp,bb} = b
  Drawing{Array.join(Triangle,at,bt),Array.join(U32,ao,bo),Array.join(U32,ai,bi),Array.join(U32,ap,bp),Array.join(Fragment,ab,bb)}

def joined(a: Drawing & Image, b: Drawing & Image, c: Drawing & Image, d: Drawing & Image) -> Drawing & Image:
  (ab,ai) = a
  (bb,bi) = b
  (cb,ci) = c
  (db,di) = d
  (join(join(ab,bb),join(cb,db)),Qua{ai,bi,ci,di})

type Four is Type:
  Four{a: Image, b: Image, c: Image, d: Image}

def open(old: Image) -> Four:
  match old:
    case Pix{+c}: Four{Pix{c},Pix{c},Pix{c},Pix{c}}
    case Qua{a,b,c,d}: Four{a,b,c,d}

# Internal unsafe boundary: read-only triangles and bins, disjoint tile pixels.
# Old image subtrees are reclaimed in the same parallel tile tree.
@unsafe
def tree(~level: Nat, ~small: Bool, +depth: Nat, +x: U32, +y: U32, +b: Drawing, old: Four) -> Drawing & Image:
  match depth:
    case 0n:
      Four{a,c,d,e} = old
      tile_size(~level,small,x,y,b,Qua{a,c,d,e})
    case 1n+p:
      Four{oa,ob,oc,od} = old
      +h = U32.shln((L.word(small,4,8) * U32.shln(1,level) : U32),p)
      a c d e = tree(~level,~small,p,x,y,b,open(oa)) tree(~level,~small,p,(x + h : U32),y,b,open(ob))
        tree(~level,~small,p,x,(y + h : U32),b,open(oc)) tree(~level,~small,p,(x + h : U32),(y + h : U32),b,open(od))
      joined(a,c,d,e)

def render_level(~level: Nat, gpu: Bool, b: Drawing, old: Image) -> Drawing & Image:
  match gpu:
    case True{}: tree!(~level,~True{},7n,0,0,b,open(old))
    case False{}: tree(~level,~False{},6n,0,0,b,open(old))

def bounds(t: Triangle) -> Bounds:
  bounds_level(~0n,t)
def build(gpu: Bool, n: U32, tris: Array<Triangle>, index: Index) -> Array<Triangle> & Index:
  build_level(~0n,gpu,n,tris,index)
def build_quality(level: Bool, gpu: Bool, n: U32, tris: Array<Triangle>, index: Index) -> Array<Triangle> & Index:
  match level:
    case True{}: build_level(~1n,gpu,n,tris,index)
    case False{}: build_level(~0n,gpu,n,tris,index)
def render( gpu: Bool, b: Drawing, old: Image) -> Drawing & Image:
  render_level(~0n,gpu,b,old)

# Buffer-only path for post-processing. Static fragments occupy [0, area);
# resolved color/depth occupy [area, 2*area), with one writer per screen pixel.
# The backdrop_level allocation must have twice the render area.
def buffer_loop(~level: Nat, n: Nat, +i: U32, b: Drawing) -> Drawing:
  match n:
    case 0n: b
    case 1n+k:
      +tile = U32.shln(4,level)
      buffer_loop(~level,k,(i + 1 : U32),raster(~level,((i % 128) * tile : U32),((i / 128) * tile : U32),b))
def buffer_leaf(~level: Nat, i: U32, n: U32, b: Drawing) -> Drawing:
  buffer_loop(~level,U32.to_nat(n),i,b)
def buffer(~level: Nat, depth: Nat, b: Drawing) -> Drawing:
  Region.run(~Drawing,~buffer_leaf(~level),~join,depth,0,16384,b)
def buffer_level(~level: Nat, gpu: Bool, b: Drawing) -> Drawing:
  match gpu:
    case True{}: buffer!(~level,14n,b)
    case False{}: buffer(~level,8n,b)

# Stable 512/1024 API. Resolution-level entry points also support level 2 (2048).
def backdrop(~high: Bool, ~background: U32 -> U32 -> Fragment, out: Array<Fragment>) -> Array<Fragment>:
  backdrop_level(~Bool.pick(Nat,high,1n,0n),~background,out)
def render_size(~high: Bool, gpu: Bool, b: Drawing, old: Image) -> Drawing & Image:
  render_level(~Bool.pick(Nat,high,1n,0n),gpu,b,old)
def render_buffer(~high: Bool, gpu: Bool, b: Drawing) -> Drawing:
  buffer_level(~Bool.pick(Nat,high,1n,0n),gpu,b)
def square_leaf(~high: Bool, small: Bool, x: U32, y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  square_leaf_level(~Bool.pick(Nat,high,1n,0n),small,x,y,pixels)
def square8(~high: Bool, x: U32, y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  square8_level(~Bool.pick(Nat,high,1n,0n),x,y,pixels)
