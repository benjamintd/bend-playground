import Base
import ../parallel/regions.bend as Region
import ../spatial/internal/index.bend as Scan
import ../spatial/layout.bend as L

# Flat Data records compile to packed scalar array elements, not heap objects.
# Screen coordinates are in the 512 x 512 render target; z is camera depth.
type Vertex is Data:
  Vertex{x: F32, y: F32, z: F32}
type Triangle is Data:
  Triangle{a: Vertex, b: Vertex, c: Vertex, color: U32}
type Fragment is Data:
  Fragment{depth: F32, color: U32}
type Bounds is Data:
  Bounds{x: U32, y: U32, width: U32, height: U32}
type Index is Type:
  Index{counts: Array<U32>, offsets: Array<U32>, cursors: Array<U32>, ids: Array<U32>, capacity: U32}

def empty() -> Index:
  Index{Array.new(U32,12n,0),Array.new(U32,13n,0),Array.new(U32,12n,0),Array.new(U32,18n,0),262144}

def blank() -> Triangle:
  Triangle{Vertex{0.0,0.0,0.0},Vertex{0.0,0.0,0.0},Vertex{0.0,0.0,0.0},0}

def extent(visible: Bool, +x: F32, +y: F32, mx: F32, my: F32) -> Bounds:
  match visible:
    case False{}: Bounds{0,0,0,0}
    case True{}:
      +tx = F32.to_u32((F32.max(x,0.0) / 8.0 : F32))
      +ty = F32.to_u32((F32.max(y,0.0) / 8.0 : F32))
      Bounds{tx,ty,(F32.to_u32((F32.min(mx,511.0) / 8.0 : F32)) - tx + 1 : U32),
        (F32.to_u32((F32.min(my,511.0) / 8.0 : F32)) - ty + 1 : U32)}

def bounds(t: Triangle) -> Bounds:
  Triangle{Vertex{+ax,+ay,az},Vertex{+bx,+by,bz},Vertex{+cx,+cy,cz},_} = t
  +x = F32.min(ax,F32.min(bx,cx))
  +y = F32.min(ay,F32.min(by,cy))
  +mx = F32.max(ax,F32.max(bx,cx))
  +my = F32.max(ay,F32.max(by,cy))
  extent((F32.min(az,F32.min(bz,cz)) > 0.1 : F32) && (mx >= 0.0 : F32) && (my >= 0.0 : F32)
    && (x < 512.0 : F32) && (y < 512.0 : F32),x,y,mx,my)

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

def cells(+n: Nat, +x: U32, +y: U32, +width: U32, +scatter: Bool, +id: U32, b: Binning) -> Binning:
  match n:
    case 0n: b
    case 1n+k:
      Binning{tris,counts,ids} = b
      +i = U32.from_nat(k)
      cells(k,x,y,width,scatter,id,incremented(scatter,id,tris,ids,
        Array.atomic.add(counts,(x + i % width + (y + i / width) * 64 : U32),1)))

def bounded(scatter: Bool, id: U32, b: Binning, box: Bounds) -> Binning:
  Bounds{x,y,+width,height} = box
  cells(U32.to_nat((width * height : U32)),x,y,width,scatter,id,b)

def bin_read(scatter: Bool, id: U32, counts: Array<U32>, ids: Array<U32>, r: Array<Triangle> & Triangle) -> Binning:
  (tris,t) = r
  bounded(scatter,id,Binning{tris,counts,ids},bounds(t))

def bin_loop(n: Nat, +i: U32, +scatter: Bool, b: Binning) -> Binning:
  match n:
    case 0n: b
    case 1n+k:
      Binning{tris,counts,ids} = b
      bin_loop(k,(i + 1 : U32),scatter,bin_read(scatter,i,counts,ids,Array.get(Triangle,tris,i)))

def bin_leaf(~scatter: Bool, start: U32, n: U32, b: Binning) -> Binning:
  bin_loop(U32.to_nat(n),start,scatter,b)

def bin_join(a: Binning, b: Binning) -> Binning:
  Binning{at,ac,ai} = a
  Binning{bt,bc,bi} = b
  Binning{Array.join(Triangle,at,bt),Array.join(U32,ac,bc),Array.join(U32,ai,bi)}

def bin(~scatter: Bool, +n: U32, b: Binning) -> Binning:
  Region.run(~Binning,~bin_leaf(~scatter),~bin_join,U32.log2(U32.max(n,1)),0,n,b)

def bin_run(~scatter: Bool, gpu: Bool, n: U32, b: Binning) -> Binning:
  match gpu:
    case True{}: bin!(~scatter,n,b)
    case False{}: bin(~scatter,n,b)

def scatter_done(counts: Array<U32>, offsets: Array<U32>, cap: U32, b: Binning) -> Array<Triangle> & Index:
  Binning{tris,cursors,ids} = b
  (tris,Index{counts,offsets,cursors,ids,cap})

def storage(grow: Bool, +total: U32, ids: Array<U32>, cap: U32) -> Array<U32> & U32:
  match grow:
    case False{}: (ids,cap)
    case True{}:
      +depth = Nat.add(1n,U32.log2(U32.max((total - 1 : U32),1)))
      (Array.new(U32,depth,0),U32.shln(1,depth))

def ready(gpu: Bool, n: U32, tris: Array<Triangle>, counts: Array<U32>, offsets: Array<U32>, cursors: Array<U32>,
  r: Array<U32> & U32) -> Array<Triangle> & Index:
  (ids,cap) = r
  scatter_done(counts,offsets,cap,bin_run(~True{},gpu,n,Binning{tris,cursors,ids}))

def scanned(gpu: Bool, n: U32, tris: Array<Triangle>, ids: Array<U32>, +cap: U32, s: Scan.Scan) -> Array<Triangle> & Index:
  Scan.Scan{counts,offsets,cursors,+total} = s
  ready(gpu,n,tris,counts,offsets,cursors,storage((total > cap : U32),total,ids,cap))

def histogrammed(gpu: Bool, n: U32, offsets: Array<U32>, cursors: Array<U32>, cap: U32, b: Binning) -> Array<Triangle> & Index:
  Binning{tris,counts,ids} = b
  scanned(gpu,n,tris,ids,cap,Scan.scan_loop(4096n,0,Scan.Scan{counts,offsets,cursors,0}))

def build(+gpu: Bool, +n: U32, tris: Array<Triangle>, index: Index) -> Array<Triangle> & Index:
  Index{counts,offsets,cursors,ids,cap} = index
  histogrammed(gpu,n,offsets,cursors,cap,bin_run(~False{},gpu,n,Binning{tris,counts,ids}))

# Perspective-correct depth with a two-sided, opaque surface. Stable tie rule.
def choose(inside: Bool, +depth: F32, color: U32, old: Fragment) -> Fragment:
  match inside:
    case False{}: old
    case True{}:
      Fragment{+z,+c} = old
      +ink = color
      Fragment{F32.min(z,depth),L.word((depth < z : F32),ink,L.word(F32.is_eq(depth,z),U32.max(ink,c),c))}

def barycentric(valid: Bool, +u: F32, +v: F32, +w: F32, az: F32, bz: F32, cz: F32, color: U32, old: Fragment) -> Fragment:
  match valid:
    case False{}: old
    case True{}: choose((u >= 0.0 : F32) && (v >= 0.0 : F32) && (w >= 0.0 : F32),
      (1.0 / F32.max((u / az + v / bz + w / cz : F32),0.000001) : F32),color,old)

def weights(nonzero: Bool, +x: F32, +y: F32, +ax: F32, +ay: F32, +az: F32,
  +bx: F32, +by: F32, +bz: F32, +cx: F32, +cy: F32, +cz: F32, +den: F32, color: U32, old: Fragment) -> Fragment:
  match nonzero:
    case False{}: old
    case True{}:
      +u = (((by - cy) * (x - cx) + (cx - bx) * (y - cy)) / den : F32)
      +v = (((cy - ay) * (x - cx) + (ax - cx) * (y - cy)) / den : F32)
      barycentric((F32.min(az,F32.min(bz,cz)) > 0.1 : F32),u,v,(1.0 - u - v : F32),az,bz,cz,color,old)

def sample(x: F32, y: F32, t: Triangle, old: Fragment) -> Fragment:
  Triangle{Vertex{+ax,+ay,az},Vertex{+bx,+by,bz},Vertex{+cx,+cy,cz},color} = t
  +den = ((by - cy) * (ax - cx) + (cx - bx) * (ay - cy) : F32)
  weights((F32.abs(den) > 0.00001 : F32),x,y,ax,ay,az,bx,by,bz,cx,cy,cz,den,color,old)

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
  Drawing{triangles: Array<Triangle>, offsets: Array<U32>, ids: Array<U32>, pixels: Array<U32>}

def written(i: U32, offsets: Array<U32>, pixels: Array<U32>, q: Query) -> Drawing:
  Query{tris,ids,Fragment{_,color}} = q
  Drawing{tris,offsets,ids,Array.set(U32,pixels,i,color)}

def pixels(~background: U32 -> U32 -> Fragment, +n: Nat, +x: U32, +y: U32, +start: U32, +count: U32, b: Drawing) -> Drawing:
  match n:
    case 0n: b
    case 1n+k:
      Drawing{tris,offsets,ids,out} = b
      +i = U32.from_nat(k)
      +px = (x + U32.and(i,7) : U32)
      +py = (y + U32.shrn(i,3n) : U32)
      pixels(~background,k,x,y,start,count,written((px + py * 512 : U32),offsets,out,
        query(U32.to_nat(count),start,(U32.to_f32(px) + 0.5 : F32),(U32.to_f32(py) + 0.5 : F32),
          Query{tris,ids,background(px,py)})))

def range_end(~background: U32 -> U32 -> Fragment, x: U32, y: U32, +start: U32,
  tris: Array<Triangle>, ids: Array<U32>, out: Array<U32>, r: Array<U32> & U32) -> Drawing:
  (offsets,end) = r
  pixels(~background,64n,x,y,start,(end - start : U32),Drawing{tris,offsets,ids,out})

def range_start(~background: U32 -> U32 -> Fragment, x: U32, y: U32, cell: U32,
  tris: Array<Triangle>, ids: Array<U32>, out: Array<U32>, r: Array<U32> & U32) -> Drawing:
  (offsets,start) = r
  range_end(~background,x,y,start,tris,ids,out,Array.get(U32,offsets,(cell + 1 : U32)))

def raster(~background: U32 -> U32 -> Fragment, +x: U32, +y: U32, b: Drawing) -> Drawing:
  Drawing{tris,offsets,ids,out} = b
  +cell = (U32.shrn(x,3n) + U32.shrn(y,3n) * 64 : U32)
  range_start(~background,x,y,cell,tris,ids,out,Array.get(U32,offsets,cell))

def pixel(r: Array<U32> & U32) -> Array<U32> & Image:
  (pixels, c) = r
  (pixels, Pix{c})

def combine(a: Image, b: Image, c: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, d) = r
  (pixels, Qua{a, b, c, d})

# Statically unrolled tiles; no recursive continuation or fork per pixel.
def square1(x: U32, y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  pixel(Array.get(U32, pixels, (x + y * 512 : U32)))

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

def tile_image(tris: Array<Triangle>, offsets: Array<U32>, ids: Array<U32>, r: Array<U32> & Image) -> Drawing & Image:
  (pixels,image) = r
  (Drawing{tris,offsets,ids,pixels},image)

def tile_done(x: U32, y: U32, b: Drawing) -> Drawing & Image:
  Drawing{tris,offsets,ids,pixels} = b
  tile_image(tris,offsets,ids,square8(x,y,pixels))

def tile(~background: U32 -> U32 -> Fragment, +x: U32, +y: U32, b: Drawing, old: Image) -> Drawing & Image:
  tile_done(x,y,raster(~background,x,y,b))

def join(a: Drawing, b: Drawing) -> Drawing:
  Drawing{at,ao,ai,ap} = a
  Drawing{bt,bo,bi,bp} = b
  Drawing{Array.join(Triangle,at,bt),Array.join(U32,ao,bo),Array.join(U32,ai,bi),Array.join(U32,ap,bp)}

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
def tree(~background: U32 -> U32 -> Fragment, +depth: Nat, +x: U32, +y: U32, +b: Drawing, old: Four) -> Drawing & Image:
  match depth:
    case 0n:
      Four{a,c,d,e} = old
      tile(~background,x,y,b,Qua{a,c,d,e})
    case 1n+p:
      Four{oa,ob,oc,od} = old
      +h = U32.shln(8,p)
      a c d e = tree(~background,p,x,y,b,open(oa)) tree(~background,p,(x + h : U32),y,b,open(ob))
        tree(~background,p,x,(y + h : U32),b,open(oc)) tree(~background,p,(x + h : U32),(y + h : U32),b,open(od))
      joined(a,c,d,e)

def render(~background: U32 -> U32 -> Fragment, gpu: Bool, b: Drawing, old: Image) -> Drawing & Image:
  match gpu:
    case True{}: tree!(~background,6n,0,0,b,open(old))
    case False{}: tree(~background,6n,0,0,b,open(old))
