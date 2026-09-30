import Base
import ./tiles.bend as Tiles
import ./image.bend as ImageBuffer
import ./mesh.bend as M
import ./color.bend as Color
import ../core/vec3.bend as V
import ../spatial/layout.bend as L

# Lightweight spatial edge smoothing and depth-aware defocus. This is not TAA,
# the full FXAA algorithm, HDR processing, or a physically accurate bokeh lens.
# Scene fragments are immutable; each tile exclusively writes output pixels.
type Settings is Data:
  Settings{aa: Bool, dof: Bool, focus: F32, aperture: F32}
type State is Type:
  State{fragments: Array<M.Fragment>, pixels: Array<U32>, settings: Settings}
def address_xy(+width: U32, x: F32, y: F32, dx: F32, dy: F32) -> U32:
  +last = U32.to_f32((width - 1 : U32))
  +x = F32.to_u32(F32.min(last,F32.max(0.0,(x + dx : F32))))
  +y = F32.to_u32(F32.min(last,F32.max(0.0,(y + dy : F32))))
  (width * width + x + y * width : U32)
def address(+width: U32, +i: U32, dx: F32, dy: F32) -> U32:
  address_xy(width,U32.to_f32((i % width : U32)),U32.to_f32((i / width : U32)),dx,dy)
def radius(s: Settings, depth: F32) -> F32:
  Settings{_,on,focus,aperture} = s
  L.pick(on,F32.min(3.0,(F32.max(0.0,aperture) * F32.abs((1.0 - focus / F32.max(depth,0.01) : F32)) : F32)),0.0)
# Radius is expressed in pixels at 1024 px, so changing render resolution
# preserves the lens in screen space. Sample continuously, never round the CoC.
def radius_pixels(width: U32, s: Settings, depth: F32) -> F32:
  (radius(s,depth) * U32.to_f32(width) / 1024.0 : F32)
type Sum is Data:
  Sum{r: F32, g: F32, b: F32, weight: F32}
def added(sum: Sum, +weight: F32, p: L.Point) -> Sum:
  Sum{r,g,b,w} = sum
  L.Point{x,y,z} = p
  Sum{(r + x * weight : F32),(g + y * weight : F32),(b + z * weight : F32),(w + weight : F32)}
def add(accept: Bool, color: U32, weight: F32, sum: Sum) -> Sum:
  match accept:
    case False{}: sum
    case True{}: added(sum,weight,Color.unpack(color))
def gathered(+z: F32, weight: F32, sum: Sum, r: Array<M.Fragment> & M.Fragment) -> Array<M.Fragment> & Sum:
  (a,M.Fragment{depth,color}) = r
  (a,add((F32.abs((depth - z : F32)) < F32.max(0.2,(z * 0.1 : F32)) : F32),color,weight,sum))
# A bilinear 3x3 Gaussian has at most five distinct coordinates on each
# axis: -ceil(step), -floor(step), 0, floor(step), ceil(step). Accumulate
# these 25 weighted texels directly instead of fetching 36 bilinear corners.
# This is the same filter, including per-corner depth rejection and clamping.
def kernel_offset(i: U32, +whole: F32) -> F32:
  match i:
    case 0: (0.0 - whole - 1.0 : F32)
    case 1: F32.neg(whole)
    case 2: 0.0
    case 3: whole
    case _: (whole + 1.0 : F32)
def kernel_weight(i: U32, +fraction: F32) -> F32:
  match i:
    case 0: fraction
    case 1: (1.0 - fraction : F32)
    case 2: 2.0
    case 3: (1.0 - fraction : F32)
    case _: fraction
def tap(on: Bool, width: U32, x: F32, y: F32, dx: F32, dy: F32, z: F32, weight: F32, r: Array<M.Fragment> & Sum) -> Array<M.Fragment> & Sum:
  match on:
    case False{}: r
    case True{}:
      (a,sum) = r
      gathered(z,weight,sum,Array.get(M.Fragment,a,address_xy(width,x,y,dx,dy)))
def kernel(+width: U32, +n: Nat, +cx: F32, +cy: F32, +whole: F32, +fraction: F32, +z: F32, r: Array<M.Fragment> & Sum) -> Array<M.Fragment> & Sum:
  match n:
    case 0n: r
    case 1n+k:
      +j = U32.from_nat(k)
      +x = (j % 5 : U32)
      +y = (j / 5 : U32)
      +w = (kernel_weight(x,fraction) * kernel_weight(y,fraction) : F32)
      kernel(width,k,cx,cy,whole,fraction,z,tap((w > 0.0 : F32),width,cx,cy,kernel_offset(x,whole),kernel_offset(y,whole),z,w,r))
# The center is invariant across all 25 taps; divide and convert only once.
def gather(+width: U32, +i: U32, +size: F32, z: F32, r: Array<M.Fragment> & Sum) -> Array<M.Fragment> & Sum:
  kernel(width,25n,U32.to_f32((i % width : U32)),U32.to_f32((i / width : U32)),F32.floor(size),(size - F32.floor(size) : F32),z,r)
def resolved(fallback: U32, sum: Sum) -> U32:
  Sum{r,g,b,+w} = sum
  +inv = (1.0 / F32.max(w,1.0) : F32)
  L.word((w > 0.0 : F32),Color.pack(L.Point{(r * inv : F32),(g * inv : F32),(b * inv : F32)}),fallback)
def blurred(i: U32, color: U32, pixels: Array<U32>, settings: Settings, r: Array<M.Fragment> & Sum) -> State:
  (a,sum) = r
  State{a,Array.set(U32,pixels,i,resolved(color,sum)),settings}

def edge_color(+center: U32, north: U32, south: U32, east: U32, west: U32) -> U32:
  +c = Color.unpack(center)
  +n = Color.unpack(north)
  +s = Color.unpack(south)
  +e = Color.unpack(east)
  +w = Color.unpack(west)
  +lc = Color.luma(c)
  +ln = Color.luma(n)
  +ls = Color.luma(s)
  +le = Color.luma(e)
  +lw = Color.luma(w)
  +lo = F32.min(lc,F32.min(F32.min(ln,ls),F32.min(le,lw)))
  +hi = F32.max(lc,F32.max(F32.max(ln,ls),F32.max(le,lw)))
  +pair = Bool.pick(L.Point,(F32.abs((ln - ls : F32)) > F32.abs((le - lw : F32)) : F32),V.add(n,s),V.add(e,w))
  L.word((hi - lo > F32.max(10.0,(hi * 0.12 : F32)) : F32),Color.pack(V.add(V.mul(c,0.75),V.mul(pair,0.125))),center)
def west(i: U32, c: U32, n: U32, s: U32, e: U32, pixels: Array<U32>, settings: Settings, r: Array<M.Fragment> & M.Fragment) -> State:
  (a,M.Fragment{_,w}) = r
  State{a,Array.set(U32,pixels,i,edge_color(c,n,s,e,w)),settings}
def east(+width: U32, +i: U32, c: U32, n: U32, s: U32, pixels: Array<U32>, settings: Settings, r: Array<M.Fragment> & M.Fragment) -> State:
  (a,M.Fragment{_,e}) = r
  west(i,c,n,s,e,pixels,settings,Array.get(M.Fragment,a,address(width,i,F32.neg(1.0),0.0)))
def south(+width: U32, +i: U32, c: U32, n: U32, pixels: Array<U32>, settings: Settings, r: Array<M.Fragment> & M.Fragment) -> State:
  (a,M.Fragment{_,s}) = r
  east(width,i,c,n,s,pixels,settings,Array.get(M.Fragment,a,address(width,i,1.0,0.0)))
def north(+width: U32, +i: U32, c: U32, pixels: Array<U32>, settings: Settings, r: Array<M.Fragment> & M.Fragment) -> State:
  (a,M.Fragment{_,n}) = r
  south(width,i,c,n,pixels,settings,Array.get(M.Fragment,a,address(width,i,0.0,1.0)))
def smooth(on: Bool, +width: U32, +i: U32, c: U32, s: State) -> State:
  match on:
    case False{}:
      State{a,p,settings} = s
      State{a,Array.set(U32,p,i,c),settings}
    case True{}:
      State{a,p,settings} = s
      north(width,i,c,p,settings,Array.get(M.Fragment,a,address(width,i,0.0,F32.neg(1.0))))
def filtered(blur: Bool, width: U32, +i: U32, z: F32, color: U32, radius: F32, s: State) -> State:
  match blur:
    case True{}:
      State{a,p,settings} = s
      blurred(i,color,p,settings,gather(width,i,(radius * 0.70710678 : F32),z,(a,Sum{0.0,0.0,0.0,0.0})))
    case False{}:
      State{a,p,+settings} = s
      Settings{aa,_,_,_} = settings
      smooth(aa,width,i,color,State{a,p,settings})
def read(+width: U32, i: U32, pixels: Array<U32>, +settings: Settings, r: Array<M.Fragment> & M.Fragment) -> State:
  (a,M.Fragment{+z,color}) = r
  +r = radius_pixels(width,settings,z)
  filtered((r > 0.001 : F32),width,i,z,color,r,State{a,pixels,settings})
def pixel(+width: U32, +i: U32, s: State) -> State:
  State{a,p,settings} = s
  read(width,i,p,settings,Array.get(M.Fragment,a,(width * width + i : U32)))
def tile_loop(+width: U32, +size: U32, +n: Nat, +x: U32, +y: U32, s: State) -> State:
  match n:
    case 0n: s
    case 1n+k:
      +j = U32.from_nat(k)
      tile_loop(width,size,k,x,y,pixel(width,(x + j % size + (y + j / size) * width : U32),s))
def image_done(a: Array<M.Fragment>, settings: Settings, r: Array<U32> & Image) -> State & Image:
  (p,image) = r
  (State{a,p,settings},image)
def tile_image(~level: Nat, small: Bool, x: U32, y: U32, s: State) -> State & Image:
  State{a,p,settings} = s
  image_done(a,settings,ImageBuffer.leaf(~level,small,x,y,p))
def tile(~level: Nat, filter: Bool, +small: Bool, +x: U32, +y: U32, s: State, old: Image) -> State & Image:
  match filter:
    case False{}: tile_image(~level,small,x,y,s)
    case True{}:
      +size = (L.word(small,4,8) * U32.shln(1,level) : U32)
      tile_image(~level,small,x,y,tile_loop(U32.shln(512,level),size,U32.to_nat((size * size : U32)),x,y,s))
def join(a: State, b: State) -> State:
  State{af,ap,c} = a
  State{bf,bp,_} = b
  State{Array.join(M.Fragment,af,bf),Array.join(U32,ap,bp),c}
def leaf(~level: Nat, ~filter: Bool, ~small: Bool, x: U32, y: U32, s: State, old: Image) -> State & Image:
  tile(~level,filter,small,x,y,s,old)
def render_filtered(~level: Nat, ~filter: Bool, gpu: Bool, s: State, old: Image) -> State & Image:
  match gpu:
    case True{}: Tiles.tree!(~State,~U32.shln(4,level),~leaf(~level,~filter,~True{}),~join,7n,0,0,s,Tiles.open(old))
    case False{}: Tiles.tree(~State,~U32.shln(8,level),~leaf(~level,~filter,~False{}),~join,6n,0,0,s,Tiles.open(old))
def render_level(~level: Nat, gpu: Bool, s: State, old: Image) -> State & Image:
  render_filtered(~level,~True{},gpu,s,old)
# Coverage already wrote resolved pixels: specialize away filtering/writes.
def present_level(~level: Nat, gpu: Bool, s: State, old: Image) -> State & Image:
  render_filtered(~level,~False{},gpu,s,old)

def render(~high: Bool, gpu: Bool, s: State, old: Image) -> State & Image:
  render_level(~Bool.pick(Nat,high,1n,0n),gpu,s,old)
