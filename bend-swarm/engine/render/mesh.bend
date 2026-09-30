import Base
import ./tiles.bend as Tiles
import ./image.bend as ImageBuffer
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

# RGB occupies 24 bits. Prepared camera triangles carry two explicit flags in
# unused bits: bit 25 = clipped camera geometry, bit 24 = orthographic depth.
# Keeping the packed layout avoids widening every raster candidate. Legacy
# triangles retain their historical near threshold and lighting interpolation.
def projected(a: Vertex, b: Vertex, c: Vertex, color: U32, orthographic: Bool) -> Triangle:
  Triangle{a,b,c,U32.or(U32.and(color,16777215),L.word(orthographic,50331648,33554432))}
def near_threshold(color: U32) -> F32:
  L.pick(U32.is_eq(U32.and(color,33554432),0),0.1,0.0)

def extent(~level: Nat,visible: Bool, +x: F32, +y: F32, mx: F32, my: F32) -> Bounds:
  match visible:
    case False{}: Bounds{0,0,0,0}
    case True{}:
      +tx = F32.to_u32((F32.max(x,0.0) / U32.to_f32(U32.shln(4,level)) : F32))
      +ty = F32.to_u32((F32.max(y,0.0) / U32.to_f32(U32.shln(4,level)) : F32))
      Bounds{tx,ty,(F32.to_u32((F32.min(mx,U32.to_f32((U32.shln(512,level) - 1 : U32))) / U32.to_f32(U32.shln(4,level)) : F32)) - tx + 1 : U32),
        (F32.to_u32((F32.min(my,U32.to_f32((U32.shln(512,level) - 1 : U32))) / U32.to_f32(U32.shln(4,level)) : F32)) - ty + 1 : U32)}

def bounds_level(~level: Nat,t: Triangle) -> Bounds:
  Triangle{Vertex{+ax,+ay,az,_},Vertex{+bx,+by,bz,_},Vertex{+cx,+cy,cz,_},color} = t
  +x = F32.min(ax,F32.min(bx,cx))
  +y = F32.min(ay,F32.min(by,cy))
  +mx = F32.max(ax,F32.max(bx,cx))
  +my = F32.max(ay,F32.max(by,cy))
  extent(~level,(F32.min(az,F32.min(bz,cz)) > near_threshold(color) : F32) && (mx >= 0.0 : F32) && (my >= 0.0 : F32)
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

def perspective_light(modern: Bool, u: F32, +v: F32, +w: F32, az: F32, bz: F32, cz: F32,
  +al: F32, bl: F32, cl: F32, depth: F32) -> F32:
  match modern:
    case False{}: (al + v * (bl - al) + w * (cl - al) : F32)
    case True{}: (al + depth * (v * (bl - al) / bz + w * (cl - al) / cz) : F32)
def interpolated(ortho: Bool, modern: Bool, +u: F32, +v: F32, +w: F32, +az: F32, +bz: F32, +cz: F32,
  +al: F32, +bl: F32, +cl: F32, color: U32, old: Fragment) -> Fragment:
  match ortho:
    case True{}: choose(True{},(u * az + v * bz + w * cz : F32),shaded(color,F32.max(0.0,(al + v * (bl - al) + w * (cl - al) : F32))),old)
    case False{}:
      +depth = (1.0 / F32.max((u / az + v / bz + w / cz : F32),0.000001) : F32)
      choose(True{},depth,shaded(color,F32.max(0.0,perspective_light(modern,u,v,w,az,bz,cz,al,bl,cl,depth))),old)
def interpolation_legacy(+u: F32, +v: F32, +w: F32, az: F32, bz: F32, cz: F32, +al: F32, bl: F32, cl: F32, color: U32, old: Fragment) -> Fragment:
  choose(True{},(1.0 / F32.max((u / az + v / bz + w / cz : F32),0.000001) : F32),
    shaded(color,F32.max(0.0,(al + v * (bl - al) + w * (cl - al) : F32))),old)
def interpolation_camera(u: F32, v: F32, w: F32, az: F32, bz: F32, cz: F32, al: F32, bl: F32, cl: F32, +color: U32, old: Fragment) -> Fragment:
  interpolated(U32.is_ne(U32.and(color,16777216),0),True{},u,v,w,az,bz,cz,al,bl,cl,color,old)
# Keep selection first-order. Selecting curried functions here leaves heap
# closures in generated pixel code on the pinned Bend compiler.
def interpolation_choice(camera: Bool,
  u: F32, v: F32, w: F32, az: F32, bz: F32, cz: F32, al: F32, bl: F32, cl: F32, color: U32, old: Fragment) -> Fragment:
  match camera:
    case True{}: interpolation_camera(u,v,w,az,bz,cz,al,bl,cl,color,old)
    case False{}: interpolation_legacy(u,v,w,az,bz,cz,al,bl,cl,color,old)
def interpolation(~camera: Bool, u: F32, v: F32, w: F32, az: F32, bz: F32, cz: F32, al: F32, bl: F32, cl: F32, color: U32, old: Fragment) -> Fragment:
  interpolation_choice(camera,u,v,w,az,bz,cz,al,bl,cl,color,old)
def barycentric_mode(~camera: Bool,valid: Bool, u: F32, v: F32, w: F32, az: F32, bz: F32, cz: F32, al: F32, bl: F32, cl: F32, +color: U32, old: Fragment) -> Fragment:
  match valid:
    case False{}: old
    case True{}: interpolation(~camera,u,v,w,az,bz,cz,al,bl,cl,color,old)

def weights_mode(~camera: Bool,nonzero: Bool, +x: F32, +y: F32, +ax: F32, +ay: F32, +az: F32,
  +bx: F32, +by: F32, +bz: F32, +cx: F32, +cy: F32, +cz: F32, +den: F32, al: F32, bl: F32, cl: F32, +color: U32, old: Fragment) -> Fragment:
  match nonzero:
    case False{}: old
    case True{}:
      +u = (((by - cy) * (x - cx) + (cx - bx) * (y - cy)) / den : F32)
      +v = (((cy - ay) * (x - cx) + (ax - cx) * (y - cy)) / den : F32)
      +w = (1.0 - u - v : F32)
      # Bend evaluates arguments eagerly. Reject misses before depth and
      # lighting work, rather than computing a color that choose discards.
      barycentric_mode(~camera,(F32.min(az,F32.min(bz,cz)) > Bool.pick(F32,camera,0.0,0.1) : F32) && (u >= 0.0 : F32)
        && (v >= 0.0 : F32) && (w >= 0.0 : F32),u,v,w,az,bz,cz,al,bl,cl,color,old)

def sample_mode(~camera: Bool,x: F32, y: F32, t: Triangle, old: Fragment) -> Fragment:
  Triangle{Vertex{+ax,+ay,az,al},Vertex{+bx,+by,bz,bl},Vertex{+cx,+cy,cz,cl},color} = t
  +den = ((by - cy) * (ax - cx) + (cx - bx) * (ay - cy) : F32)
  weights_mode(~camera,(F32.abs(den) > 0.00001 : F32),x,y,ax,ay,az,bx,by,bz,cx,cy,cz,den,al,bl,cl,color,old)

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
  Query{tris,ids,sample_mode(~False{},x,y,t,old)}

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

# Read a tile candidate once for four adjacent pixels. Each sample keeps its
# independent background/depth/color and uses the unchanged sample equation.
type BlockQuery is Type:
  BlockQuery{triangles: Array<Triangle>, ids: Array<U32>, a: Fragment, b: Fragment, c: Fragment, d: Fragment}
def block_sampled_mode(~camera: Bool,+x: F32, +y: F32, ids: Array<U32>, a: Fragment, b: Fragment, c: Fragment, d: Fragment,
  r: Array<Triangle> & Triangle) -> BlockQuery:
  (tris,+t) = r
  BlockQuery{tris,ids,sample_mode(~camera,x,y,t,a),sample_mode(~camera,(x + 1.0 : F32),y,t,b),
    sample_mode(~camera,x,(y + 1.0 : F32),t,c),sample_mode(~camera,(x + 1.0 : F32),(y + 1.0 : F32),t,d)}
def block_identified_mode(~camera: Bool,x: F32, y: F32, tris: Array<Triangle>, a: Fragment, b: Fragment, c: Fragment, d: Fragment,
  r: Array<U32> & U32) -> BlockQuery:
  (ids,id) = r
  block_sampled_mode(~camera,x,y,ids,a,b,c,d,Array.get(Triangle,tris,id))
def block_query_mode(~camera: Bool,n: Nat, +i: U32, +x: F32, +y: F32, q: BlockQuery) -> BlockQuery:
  match n:
    case 0n: q
    case 1n+k:
      BlockQuery{tris,ids,a,b,c,d} = q
      block_query_mode(~camera,k,(i + 1 : U32),x,y,block_identified_mode(~camera,x,y,tris,a,b,c,d,Array.get(U32,ids,i)))
def block_written(~level: Nat,+i: U32,offsets: Array<U32>,pixels: Array<U32>,background: Array<Fragment>,q: BlockQuery) -> Drawing:
  BlockQuery{tris,ids,+a,+b,+c,+d} = q
  Fragment{_,ac} = a
  Fragment{_,bc} = b
  Fragment{_,cc} = c
  Fragment{_,dc} = d
  +width = U32.shln(512,level)
  +base = (U32.shln(262144,Nat.add(level,level)) + i : U32)
  Drawing{tris,offsets,ids,
    Array.set(U32,Array.set(U32,Array.set(U32,Array.set(U32,pixels,i,ac),(i + 1 : U32),bc),(i + width : U32),cc),(i + width + 1 : U32),dc),
    Array.set(Fragment,Array.set(Fragment,Array.set(Fragment,Array.set(Fragment,background,base,a),(base + 1 : U32),b),(base + width : U32),c),(base + width + 1 : U32),d)}
def block_background_d_mode(~camera: Bool,~level: Nat,i: U32,x: F32,y: F32,start: U32,count: U32,
  tris: Array<Triangle>,offsets: Array<U32>,ids: Array<U32>,pixels: Array<U32>,a: Fragment,b: Fragment,c: Fragment,r: Array<Fragment> & Fragment) -> Drawing:
  (background,d) = r
  block_written(~level,i,offsets,pixels,background,block_query_mode(~camera,U32.to_nat(count),start,x,y,BlockQuery{tris,ids,a,b,c,d}))
def block_background_c_mode(~camera: Bool,~level: Nat,+i: U32,x: F32,y: F32,start: U32,count: U32,
  tris: Array<Triangle>,offsets: Array<U32>,ids: Array<U32>,pixels: Array<U32>,a: Fragment,b: Fragment,r: Array<Fragment> & Fragment) -> Drawing:
  (background,c) = r
  block_background_d_mode(~camera,~level,i,x,y,start,count,tris,offsets,ids,pixels,a,b,c,Array.get(Fragment,background,(i + U32.shln(512,level) + 1 : U32)))
def block_background_b_mode(~camera: Bool,~level: Nat,+i: U32,x: F32,y: F32,start: U32,count: U32,
  tris: Array<Triangle>,offsets: Array<U32>,ids: Array<U32>,pixels: Array<U32>,a: Fragment,r: Array<Fragment> & Fragment) -> Drawing:
  (background,b) = r
  block_background_c_mode(~camera,~level,i,x,y,start,count,tris,offsets,ids,pixels,a,b,Array.get(Fragment,background,(i + U32.shln(512,level) : U32)))
def block_background_a_mode(~camera: Bool,~level: Nat,+i: U32,x: F32,y: F32,start: U32,count: U32,
  tris: Array<Triangle>,offsets: Array<U32>,ids: Array<U32>,pixels: Array<U32>,r: Array<Fragment> & Fragment) -> Drawing:
  (background,a) = r
  block_background_b_mode(~camera,~level,i,x,y,start,count,tris,offsets,ids,pixels,a,Array.get(Fragment,background,(i + 1 : U32)))
def blocks_mode(~camera: Bool,~level: Nat, +n: Nat, +x: U32, +y: U32, +start: U32, +count: U32, b: Drawing) -> Drawing:
  match n:
    case 0n: b
    case 1n+k:
      Drawing{tris,offsets,ids,out,background} = b
      +j = U32.from_nat(k)
      +px = (x + U32.and(j,(U32.shln(2,level) - 1 : U32)) * 2 : U32)
      +py = (y + U32.shrn(j,Nat.add(level,1n)) * 2 : U32)
      +i = (px + py * U32.shln(512,level) : U32)
      blocks_mode(~camera,~level,k,x,y,start,count,block_background_a_mode(~camera,~level,i,(U32.to_f32(px) + 0.5 : F32),
        (U32.to_f32(py) + 0.5 : F32),start,count,tris,offsets,ids,out,Array.get(Fragment,background,i)))
def pixels_mode(~camera: Bool,~level: Nat,n: Nat,x: U32,y: U32,start: U32,count: U32,b: Drawing) -> Drawing:
  blocks_mode(~camera,~level,U32.to_nat((U32.from_nat(n) / 4 : U32)),x,y,start,count,b)

def range_end_mode(~camera: Bool,~level: Nat, x: U32, y: U32, +start: U32,
  tris: Array<Triangle>, ids: Array<U32>, out: Array<U32>, background: Array<Fragment>, r: Array<U32> & U32) -> Drawing:
  (offsets,end) = r
  pixels_mode(~camera,~level,U32.to_nat(U32.shln(16,Nat.add(level,level))),x,y,start,(end - start : U32),Drawing{tris,offsets,ids,out,background})

def range_start_mode(~camera: Bool,~level: Nat, x: U32, y: U32, cell: U32,
  tris: Array<Triangle>, ids: Array<U32>, out: Array<U32>, background: Array<Fragment>, r: Array<U32> & U32) -> Drawing:
  (offsets,start) = r
  range_end_mode(~camera,~level,x,y,start,tris,ids,out,background,Array.get(U32,offsets,(cell + 1 : U32)))

def raster_mode(~camera: Bool,~level: Nat, +x: U32, +y: U32, b: Drawing) -> Drawing:
  Drawing{tris,offsets,ids,out,background} = b
  +cell = (U32.shrn(x,Nat.add(level,2n)) + U32.shrn(y,Nat.add(level,2n)) * 128 : U32)
  range_start_mode(~camera,~level,x,y,cell,tris,ids,out,background,Array.get(U32,offsets,cell))

def tile_image(tris: Array<Triangle>, offsets: Array<U32>, ids: Array<U32>, background: Array<Fragment>, r: Array<U32> & Image) -> Drawing & Image:
  (pixels,image) = r
  (Drawing{tris,offsets,ids,pixels,background},image)

def tile_done(~level: Nat,x: U32, y: U32, b: Drawing) -> Drawing & Image:
  Drawing{tris,offsets,ids,pixels,background} = b
  tile_image(tris,offsets,ids,background,ImageBuffer.leaf(~level,True{},x,y,pixels))

def tile_mode(~camera: Bool,~level: Nat, +x: U32, +y: U32, b: Drawing, old: Image) -> Drawing & Image:
  tile_done(~level,x,y,raster_mode(~camera,~level,x,y,b))

def tile8_done(~level: Nat,x: U32, y: U32, b: Drawing) -> Drawing & Image:
  Drawing{tris,offsets,ids,pixels,background} = b
  tile_image(tris,offsets,ids,background,ImageBuffer.leaf(~level,False{},x,y,pixels))
def tile8_mode(~camera: Bool,~level: Nat, +x: U32, +y: U32, b: Drawing, old: Image) -> Drawing & Image:
  tile8_done(~level,x,y,raster_mode(~camera,~level,(x + U32.shln(4,level) : U32),(y + U32.shln(4,level) : U32),
    raster_mode(~camera,~level,x,(y + U32.shln(4,level) : U32),raster_mode(~camera,~level,(x + U32.shln(4,level) : U32),y,raster_mode(~camera,~level,x,y,b)))))
def tile_size_mode(~camera: Bool,~level: Nat, small: Bool, x: U32, y: U32, b: Drawing, old: Image) -> Drawing & Image:
  match small:
    case True{}: tile_mode(~camera,~level,x,y,b,old)
    case False{}: tile8_mode(~camera,~level,x,y,b,old)

def join(a: Drawing, b: Drawing) -> Drawing:
  Drawing{at,ao,ai,ap,ab} = a
  Drawing{bt,bo,bi,bp,bb} = b
  Drawing{Array.join(Triangle,at,bt),Array.join(U32,ao,bo),Array.join(U32,ai,bi),Array.join(U32,ap,bp),Array.join(Fragment,ab,bb)}

def render_level_mode(~camera: Bool,~level: Nat, gpu: Bool, b: Drawing, old: Image) -> Drawing & Image:
  match gpu:
    case True{}: Tiles.tree!(~Drawing,~U32.shln(4,level),~tile_size_mode(~camera,~level,True{}),~join,7n,0,0,b,Tiles.open(old))
    case False{}: Tiles.tree(~Drawing,~U32.shln(8,level),~tile_size_mode(~camera,~level,False{}),~join,6n,0,0,b,Tiles.open(old))

def bounds(t: Triangle) -> Bounds:
  bounds_level(~0n,t)
def build(gpu: Bool, n: U32, tris: Array<Triangle>, index: Index) -> Array<Triangle> & Index:
  build_level(~0n,gpu,n,tris,index)
def build_quality(level: Bool, gpu: Bool, n: U32, tris: Array<Triangle>, index: Index) -> Array<Triangle> & Index:
  match level:
    case True{}: build_level(~1n,gpu,n,tris,index)
    case False{}: build_level(~0n,gpu,n,tris,index)
def render( gpu: Bool, b: Drawing, old: Image) -> Drawing & Image:
  render_level_mode(~False{},~0n,gpu,b,old)

# Buffer-only path for post-processing. Static fragments occupy [0, area);
# resolved color/depth occupy [area, 2*area), with one writer per screen pixel.
# The backdrop_level allocation must have twice the render area.
def buffer_loop_mode(~camera: Bool,~level: Nat, n: Nat, +i: U32, b: Drawing) -> Drawing:
  match n:
    case 0n: b
    case 1n+k:
      +tile = U32.shln(4,level)
      buffer_loop_mode(~camera,~level,k,(i + 1 : U32),raster_mode(~camera,~level,((i % 128) * tile : U32),((i / 128) * tile : U32),b))
def buffer_leaf_mode(~camera: Bool,~level: Nat, i: U32, n: U32, b: Drawing) -> Drawing:
  buffer_loop_mode(~camera,~level,U32.to_nat(n),i,b)
def buffer_mode(~camera: Bool,~level: Nat, depth: Nat, b: Drawing) -> Drawing:
  Region.run(~Drawing,~buffer_leaf_mode(~camera,~level),~join,depth,0,16384,b)
def buffer_level_mode(~camera: Bool,~level: Nat, gpu: Bool, b: Drawing) -> Drawing:
  match gpu:
    case True{}: buffer_mode!(~camera,~level,14n,b)
    case False{}: buffer_mode(~camera,~level,8n,b)

# Stable 512/1024 API. Resolution-level entry points also support level 2 (2048).
def backdrop(~high: Bool, ~background: U32 -> U32 -> Fragment, out: Array<Fragment>) -> Array<Fragment>:
  backdrop_level(~Bool.pick(Nat,high,1n,0n),~background,out)
def render_size(~high: Bool, gpu: Bool, b: Drawing, old: Image) -> Drawing & Image:
  render_level_mode(~False{},~Bool.pick(Nat,high,1n,0n),gpu,b,old)
def render_buffer(~high: Bool, gpu: Bool, b: Drawing) -> Drawing:
  buffer_level_mode(~False{},~Bool.pick(Nat,high,1n,0n),gpu,b)

# Legacy entry points remain statically specialized to the original equations.
# Camera batches must use the corresponding camera renderer/sample entry point.
def sample(x: F32, y: F32, t: Triangle, old: Fragment) -> Fragment:
  sample_mode(~False{},x,y,t,old)
def sample_camera(x: F32, y: F32, t: Triangle, old: Fragment) -> Fragment:
  sample_mode(~True{},x,y,t,old)
def block_query(n: Nat, i: U32, x: F32, y: F32, q: BlockQuery) -> BlockQuery:
  block_query_mode(~False{},n,i,x,y,q)
def raster(~level: Nat, x: U32, y: U32, b: Drawing) -> Drawing:
  raster_mode(~False{},~level,x,y,b)
def render_level(~level: Nat, gpu: Bool, b: Drawing, old: Image) -> Drawing & Image:
  render_level_mode(~False{},~level,gpu,b,old)
def render_camera_level(~level: Nat, gpu: Bool, b: Drawing, old: Image) -> Drawing & Image:
  render_level_mode(~True{},~level,gpu,b,old)
def buffer_level(~level: Nat, gpu: Bool, b: Drawing) -> Drawing:
  buffer_level_mode(~False{},~level,gpu,b)
