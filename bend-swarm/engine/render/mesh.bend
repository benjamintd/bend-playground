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

def extent(~high: Bool,visible: Bool, +x: F32, +y: F32, mx: F32, my: F32) -> Bounds:
  match visible:
    case False{}: Bounds{0,0,0,0}
    case True{}:
      +tx = F32.to_u32((F32.max(x,0.0) / L.pick(high,8.0,4.0) : F32))
      +ty = F32.to_u32((F32.max(y,0.0) / L.pick(high,8.0,4.0) : F32))
      Bounds{tx,ty,(F32.to_u32((F32.min(mx,L.pick(high,1023.0,511.0)) / L.pick(high,8.0,4.0) : F32)) - tx + 1 : U32),
        (F32.to_u32((F32.min(my,L.pick(high,1023.0,511.0)) / L.pick(high,8.0,4.0) : F32)) - ty + 1 : U32)}

def bounds_size(~high: Bool,t: Triangle) -> Bounds:
  Triangle{Vertex{+ax,+ay,az,_},Vertex{+bx,+by,bz,_},Vertex{+cx,+cy,cz,_},_} = t
  +x = F32.min(ax,F32.min(bx,cx))
  +y = F32.min(ay,F32.min(by,cy))
  +mx = F32.max(ax,F32.max(bx,cx))
  +my = F32.max(ay,F32.max(by,cy))
  extent(~high,(F32.min(az,F32.min(bz,cz)) > 0.1 : F32) && (mx >= 0.0 : F32) && (my >= 0.0 : F32)
    && (x < L.pick(high,1024.0,512.0) : F32) && (y < L.pick(high,1024.0,512.0) : F32),x,y,mx,my)

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

def cells(~high: Bool,+n: Nat, +x: U32, +y: U32, +width: U32, +scatter: Bool, +id: U32, b: Binning) -> Binning:
  match n:
    case 0n: b
    case 1n+k:
      Binning{tris,counts,ids} = b
      +i = U32.from_nat(k)
      cells(~high,k,x,y,width,scatter,id,incremented(scatter,id,tris,ids,
        Array.atomic.add(counts,(x + i % width + (y + i / width) * 128 : U32),1)))

def bounded(~high: Bool,scatter: Bool, id: U32, b: Binning, box: Bounds) -> Binning:
  Bounds{x,y,+width,height} = box
  cells(~high,U32.to_nat((width * height : U32)),x,y,width,scatter,id,b)

def bin_read(~high: Bool,scatter: Bool, id: U32, counts: Array<U32>, ids: Array<U32>, r: Array<Triangle> & Triangle) -> Binning:
  (tris,t) = r
  bounded(~high,scatter,id,Binning{tris,counts,ids},bounds_size(~high,t))

def bin_loop(~high: Bool,n: Nat, +i: U32, +scatter: Bool, b: Binning) -> Binning:
  match n:
    case 0n: b
    case 1n+k:
      Binning{tris,counts,ids} = b
      bin_loop(~high,k,(i + 1 : U32),scatter,bin_read(~high,scatter,i,counts,ids,Array.get(Triangle,tris,i)))

def bin_leaf(~high: Bool,~scatter: Bool, start: U32, n: U32, b: Binning) -> Binning:
  bin_loop(~high,U32.to_nat(n),start,scatter,b)

def bin_join(a: Binning, b: Binning) -> Binning:
  Binning{at,ac,ai} = a
  Binning{bt,bc,bi} = b
  Binning{Array.join(Triangle,at,bt),Array.join(U32,ac,bc),Array.join(U32,ai,bi)}

def bin(~high: Bool,~scatter: Bool, +n: U32, b: Binning) -> Binning:
  Region.run(~Binning,~bin_leaf(~high,~scatter),~bin_join,U32.log2(U32.max(n,1)),0,n,b)

def bin_run(~high: Bool,~scatter: Bool, gpu: Bool, n: U32, b: Binning) -> Binning:
  match gpu:
    case True{}: bin!(~high,~scatter,n,b)
    case False{}: bin_loop(~high,U32.to_nat(n),0,scatter,b)

def scatter_done(counts: Array<U32>, offsets: Array<U32>, cap: U32, b: Binning) -> Array<Triangle> & Index:
  Binning{tris,cursors,ids} = b
  (tris,Index{counts,offsets,cursors,ids,cap})

def storage(grow: Bool, +total: U32, ids: Array<U32>, cap: U32) -> Array<U32> & U32:
  match grow:
    case False{}: (ids,cap)
    case True{}:
      +depth = Nat.add(1n,U32.log2(U32.max((total - 1 : U32),1)))
      (Array.new(U32,depth,0),U32.shln(1,depth))

def ready(~high: Bool,gpu: Bool, n: U32, tris: Array<Triangle>, counts: Array<U32>, offsets: Array<U32>, cursors: Array<U32>,
  r: Array<U32> & U32) -> Array<Triangle> & Index:
  (ids,cap) = r
  scatter_done(counts,offsets,cap,bin_run(~high,~True{},gpu,n,Binning{tris,cursors,ids}))

def scanned(~high: Bool,gpu: Bool, n: U32, tris: Array<Triangle>, ids: Array<U32>, +cap: U32, s: Scan.Scan) -> Array<Triangle> & Index:
  Scan.Scan{counts,offsets,cursors,+total} = s
  ready(~high,gpu,n,tris,counts,offsets,cursors,storage((total > cap : U32),total,ids,cap))

def histogrammed(~high: Bool,gpu: Bool, n: U32, offsets: Array<U32>, cursors: Array<U32>, cap: U32, b: Binning) -> Array<Triangle> & Index:
  Binning{tris,counts,ids} = b
  scanned(~high,gpu,n,tris,ids,cap,Scan.scan_loop(16384n,0,Scan.Scan{counts,offsets,cursors,0}))

def build_size(~high: Bool,+gpu: Bool, +n: U32, tris: Array<Triangle>, index: Index) -> Array<Triangle> & Index:
  Index{counts,offsets,cursors,ids,cap} = index
  histogrammed(~high,gpu,n,offsets,cursors,cap,bin_run(~high,~False{},gpu,n,Binning{tris,counts,ids}))

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

# Static backdrops retain depth as well as color. Refill this persistent buffer
# only when the camera/background changes; raster workers read it immutably.
def backdrop_loop(~high: Bool, ~background: U32 -> U32 -> Fragment, n: Nat, +i: U32, out: Array<Fragment>) -> Array<Fragment>:
  match n:
    case 0n: out
    case 1n+k:
      +width = L.word(high,1024,512)
      backdrop_loop(~high,~background,k,(i + 1 : U32),Array.set(Fragment,out,i,background((i % width : U32),(i / width : U32))))
def backdrop_leaf(~high: Bool, ~background: U32 -> U32 -> Fragment, i: U32, n: U32, out: Array<Fragment>) -> Array<Fragment>:
  backdrop_loop(~high,~background,U32.to_nat(n),i,out)
def backdrop(~high: Bool, ~background: U32 -> U32 -> Fragment, out: Array<Fragment>) -> Array<Fragment>:
  Region.run(~Array<Fragment>,~backdrop_leaf(~high,~background),~Array.join(Fragment),6n,0,L.word(high,1048576,262144),out)

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

def written(i: U32, offsets: Array<U32>, pixels: Array<U32>, background: Array<Fragment>, q: Query) -> Drawing:
  Query{tris,ids,Fragment{_,color}} = q
  Drawing{tris,offsets,ids,Array.set(U32,pixels,i,color),background}

def background_read(i: U32, x: F32, y: F32, start: U32, count: U32,
  tris: Array<Triangle>, offsets: Array<U32>, ids: Array<U32>, out: Array<U32>, r: Array<Fragment> & Fragment) -> Drawing:
  (background,fragment) = r
  written(i,offsets,out,background,query(U32.to_nat(count),start,x,y,Query{tris,ids,fragment}))

def pixels(~high: Bool, +n: Nat, +x: U32, +y: U32, +start: U32, +count: U32, b: Drawing) -> Drawing:
  match n:
    case 0n: b
    case 1n+k:
      Drawing{tris,offsets,ids,out,background} = b
      +i = U32.from_nat(k)
      +px = (x + U32.and(i,L.word(high,7,3)) : U32)
      +py = (y + U32.shrn(i,Bool.pick(Nat,high,3n,2n)) : U32)
      pixels(~high,k,x,y,start,count,background_read((px + py * L.word(high,1024,512) : U32),
        (U32.to_f32(px) + 0.5 : F32),(U32.to_f32(py) + 0.5 : F32),start,count,tris,offsets,ids,out,
        Array.get(Fragment,background,(px + py * L.word(high,1024,512) : U32))))

def range_end(~high: Bool, x: U32, y: U32, +start: U32,
  tris: Array<Triangle>, ids: Array<U32>, out: Array<U32>, background: Array<Fragment>, r: Array<U32> & U32) -> Drawing:
  (offsets,end) = r
  pixels(~high,Bool.pick(Nat,high,64n,16n),x,y,start,(end - start : U32),Drawing{tris,offsets,ids,out,background})

def range_start(~high: Bool, x: U32, y: U32, cell: U32,
  tris: Array<Triangle>, ids: Array<U32>, out: Array<U32>, background: Array<Fragment>, r: Array<U32> & U32) -> Drawing:
  (offsets,start) = r
  range_end(~high,x,y,start,tris,ids,out,background,Array.get(U32,offsets,(cell + 1 : U32)))

def raster(~high: Bool, +x: U32, +y: U32, b: Drawing) -> Drawing:
  Drawing{tris,offsets,ids,out,background} = b
  +cell = (U32.shrn(x,Bool.pick(Nat,high,3n,2n)) + U32.shrn(y,Bool.pick(Nat,high,3n,2n)) * 128 : U32)
  range_start(~high,x,y,cell,tris,ids,out,background,Array.get(U32,offsets,cell))

def pixel(r: Array<U32> & U32) -> Array<U32> & Image:
  (pixels, c) = r
  (pixels, Pix{c})

def combine(a: Image, b: Image, c: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, d) = r
  (pixels, Qua{a, b, c, d})

# Statically unrolled tiles; no recursive continuation or fork per pixel.
def square1(~high: Bool,x: U32, y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  pixel(Array.get(U32, pixels, (x + y * L.word(high,1024,512) : U32)))

def square2_c(~high: Bool,x: U32, y: U32, a: Image, b: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, c) = r
  combine(a, b, c, square1(~high,x, y, pixels))

def square2_b(~high: Bool,+x: U32, +y: U32, a: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, b) = r
  square2_c(~high,(x + 1 : U32), (y + 1 : U32), a, b, square1(~high,x, (y + 1 : U32), pixels))

def square2_a(~high: Bool,+x: U32, +y: U32, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, a) = r
  square2_b(~high,x, y, a, square1(~high,(x + 1 : U32), y, pixels))

def square2(~high: Bool,+x: U32, +y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  square2_a(~high,x, y, square1(~high,x, y, pixels))

def square4_c(~high: Bool,x: U32, y: U32, a: Image, b: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, c) = r
  combine(a, b, c, square2(~high,x, y, pixels))

def square4_b(~high: Bool,+x: U32, +y: U32, a: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, b) = r
  square4_c(~high,(x + 2 : U32), (y + 2 : U32), a, b, square2(~high,x, (y + 2 : U32), pixels))

def square4_a(~high: Bool,+x: U32, +y: U32, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, a) = r
  square4_b(~high,x, y, a, square2(~high,(x + 2 : U32), y, pixels))

def square4(~high: Bool,+x: U32, +y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  square4_a(~high,x, y, square2(~high,x, y, pixels))

def square8_c(~high: Bool,x: U32, y: U32, a: Image, b: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, c) = r
  combine(a, b, c, square4(~high,x, y, pixels))

def square8_b(~high: Bool,+x: U32, +y: U32, a: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, b) = r
  square8_c(~high,(x + 4 : U32), (y + 4 : U32), a, b, square4(~high,x, (y + 4 : U32), pixels))

def square8_a(~high: Bool,+x: U32, +y: U32, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, a) = r
  square8_b(~high,x, y, a, square4(~high,(x + 4 : U32), y, pixels))

def square8(~high: Bool,+x: U32, +y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  square8_a(~high,x, y, square4(~high,x, y, pixels))
def square16_c(~high: Bool,x: U32, y: U32, a: Image, b: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, c) = r
  combine(a, b, c, square8(~high,x, y, pixels))

def square16_b(~high: Bool,+x: U32, +y: U32, a: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, b) = r
  square16_c(~high,(x + 8 : U32), (y + 8 : U32), a, b, square8(~high,x, (y + 8 : U32), pixels))

def square16_a(~high: Bool,+x: U32, +y: U32, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels, a) = r
  square16_b(~high,x, y, a, square8(~high,(x + 8 : U32), y, pixels))

def square16(~high: Bool,+x: U32, +y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  square16_a(~high,x, y, square8(~high,x, y, pixels))

def tile_image(tris: Array<Triangle>, offsets: Array<U32>, ids: Array<U32>, background: Array<Fragment>, r: Array<U32> & Image) -> Drawing & Image:
  (pixels,image) = r
  (Drawing{tris,offsets,ids,pixels,background},image)

def square_gpu(~high: Bool, large: Bool, x: U32, y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  match large:
    case True{}: square8(~high,x,y,pixels)
    case False{}: square4(~high,x,y,pixels)
def square_cpu(~high: Bool, large: Bool, x: U32, y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  match large:
    case True{}: square16(~high,x,y,pixels)
    case False{}: square8(~high,x,y,pixels)
def square_leaf(~high: Bool, small: Bool, x: U32, y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  match small:
    case True{}: square_gpu(~high,high,x,y,pixels)
    case False{}: square_cpu(~high,high,x,y,pixels)

def tile_done(~high: Bool,x: U32, y: U32, b: Drawing) -> Drawing & Image:
  Drawing{tris,offsets,ids,pixels,background} = b
  tile_image(tris,offsets,ids,background,square_leaf(~high,True{},x,y,pixels))

def tile(~high: Bool, +x: U32, +y: U32, b: Drawing, old: Image) -> Drawing & Image:
  tile_done(~high,x,y,raster(~high,x,y,b))

def tile8_done(~high: Bool,x: U32, y: U32, b: Drawing) -> Drawing & Image:
  Drawing{tris,offsets,ids,pixels,background} = b
  tile_image(tris,offsets,ids,background,square_leaf(~high,False{},x,y,pixels))
def tile8(~high: Bool, +x: U32, +y: U32, b: Drawing, old: Image) -> Drawing & Image:
  tile8_done(~high,x,y,raster(~high,(x + L.word(high,8,4) : U32),(y + L.word(high,8,4) : U32),
    raster(~high,x,(y + L.word(high,8,4) : U32),raster(~high,(x + L.word(high,8,4) : U32),y,raster(~high,x,y,b)))))
def tile_size(~high: Bool, small: Bool, x: U32, y: U32, b: Drawing, old: Image) -> Drawing & Image:
  match small:
    case True{}: tile(~high,x,y,b,old)
    case False{}: tile8(~high,x,y,b,old)

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
def tree(~high: Bool, ~small: Bool, +depth: Nat, +x: U32, +y: U32, +b: Drawing, old: Four) -> Drawing & Image:
  match depth:
    case 0n:
      Four{a,c,d,e} = old
      tile_size(~high,small,x,y,b,Qua{a,c,d,e})
    case 1n+p:
      Four{oa,ob,oc,od} = old
      +h = U32.shln((L.word(small,4,8) * L.word(high,2,1) : U32),p)
      a c d e = tree(~high,~small,p,x,y,b,open(oa)) tree(~high,~small,p,(x + h : U32),y,b,open(ob))
        tree(~high,~small,p,x,(y + h : U32),b,open(oc)) tree(~high,~small,p,(x + h : U32),(y + h : U32),b,open(od))
      joined(a,c,d,e)

def render_size(~high: Bool, gpu: Bool, b: Drawing, old: Image) -> Drawing & Image:
  match gpu:
    case True{}: tree!(~high,~True{},7n,0,0,b,open(old))
    case False{}: tree(~high,~False{},6n,0,0,b,open(old))

def bounds(t: Triangle) -> Bounds:
  bounds_size(~False{},t)
def build(gpu: Bool, n: U32, tris: Array<Triangle>, index: Index) -> Array<Triangle> & Index:
  build_size(~False{},gpu,n,tris,index)
def build_quality(high: Bool, gpu: Bool, n: U32, tris: Array<Triangle>, index: Index) -> Array<Triangle> & Index:
  match high:
    case True{}: build_size(~True{},gpu,n,tris,index)
    case False{}: build_size(~False{},gpu,n,tris,index)
def render( gpu: Bool, b: Drawing, old: Image) -> Drawing & Image:
  render_size(~False{},gpu,b,old)
