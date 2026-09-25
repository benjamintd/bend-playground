import Base
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
def address(+width: U32, +i: U32, dx: F32, dy: F32) -> U32:
  +last = U32.to_f32((width - 1 : U32))
  +x = F32.to_u32(F32.min(last,F32.max(0.0,(U32.to_f32((i % width : U32)) + dx : F32))))
  +y = F32.to_u32(F32.min(last,F32.max(0.0,(U32.to_f32((i / width : U32)) + dy : F32))))
  (width * width + x + y * width : U32)
def radius(s: Settings, depth: F32) -> F32:
  Settings{_,on,focus,aperture} = s
  L.pick(on,F32.min(3.0,(F32.max(0.0,aperture) * F32.abs((1.0 - focus / F32.max(depth,0.01) : F32)) : F32)),0.0)
type Sum is Data:
  Sum{r: F32, g: F32, b: F32, weight: F32}
def added(sum: Sum, p: L.Point) -> Sum:
  Sum{r,g,b,w} = sum
  L.Point{x,y,z} = p
  Sum{(r + x : F32),(g + y : F32),(b + z : F32),(w + 1.0 : F32)}
def add(accept: Bool, color: U32, sum: Sum) -> Sum:
  match accept:
    case False{}: sum
    case True{}: added(sum,Color.unpack(color))
def gathered(+z: F32, sum: Sum, r: Array<M.Fragment> & M.Fragment) -> Array<M.Fragment> & Sum:
  (a,M.Fragment{depth,color}) = r
  (a,add((F32.abs((depth - z : F32)) < F32.max(0.2,(z * 0.1 : F32)) : F32),color,sum))
def gather(+width: U32, +n: Nat, +i: U32, +size: F32, +z: F32, r: Array<M.Fragment> & Sum) -> Array<M.Fragment> & Sum:
  match n:
    case 0n: r
    case 1n+k:
      (a,sum) = r
      +j = U32.from_nat(k)
      gather(width,k,i,size,z,gathered(z,sum,Array.get(M.Fragment,a,address(width,i,
        ((U32.to_f32((j % 3 : U32)) - 1.0) * size : F32),((U32.to_f32((j / 3 : U32)) - 1.0) * size : F32)))))
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
      blurred(i,color,p,settings,gather(width,9n,i,F32.floor((radius + 0.5 : F32)),z,(a,Sum{0.0,0.0,0.0,0.0})))
    case False{}:
      State{a,p,+settings} = s
      Settings{aa,_,_,_} = settings
      smooth(aa,width,i,color,State{a,p,settings})
def read(width: U32, i: U32, pixels: Array<U32>, +settings: Settings, r: Array<M.Fragment> & M.Fragment) -> State:
  (a,M.Fragment{+z,color}) = r
  +r = radius(settings,z)
  filtered((r >= 0.75 : F32),width,i,z,color,r,State{a,pixels,settings})
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
  image_done(a,settings,M.square_leaf_level(~level,small,x,y,p))
def tile(~level: Nat, +small: Bool, +x: U32, +y: U32, s: State, old: Image) -> State & Image:
  +size = (L.word(small,4,8) * U32.shln(1,level) : U32)
  tile_image(~level,small,x,y,tile_loop(U32.shln(512,level),size,U32.to_nat((size * size : U32)),x,y,s))
def join(a: State, b: State) -> State:
  State{af,ap,c} = a
  State{bf,bp,_} = b
  State{Array.join(M.Fragment,af,bf),Array.join(U32,ap,bp),c}
def joined(a: State & Image, b: State & Image, c: State & Image, d: State & Image) -> State & Image:
  (as,ai) = a
  (bs,bi) = b
  (cs,ci) = c
  (ds,di) = d
  (join(join(as,bs),join(cs,ds)),Qua{ai,bi,ci,di})
# Immutable resolved fragments plus disjoint output pixels; only aliases of
# these same allocations are rejoined. The previous Image is reclaimed by tile.
@unsafe
def tree(~level: Nat, ~small: Bool, +depth: Nat, +x: U32, +y: U32, +s: State, old: M.Four) -> State & Image:
  match depth:
    case 0n:
      M.Four{a,b,c,d} = old
      tile(~level,small,x,y,s,Qua{a,b,c,d})
    case 1n+k:
      M.Four{a,b,c,d} = old
      +h = U32.shln((L.word(small,4,8) * U32.shln(1,level) : U32),k)
      ra rb rc rd = tree(~level,~small,k,x,y,s,M.open(a)) tree(~level,~small,k,(x + h : U32),y,s,M.open(b))
        tree(~level,~small,k,x,(y + h : U32),s,M.open(c)) tree(~level,~small,k,(x + h : U32),(y + h : U32),s,M.open(d))
      joined(ra,rb,rc,rd)
def render_level(~level: Nat, gpu: Bool, s: State, old: Image) -> State & Image:
  match gpu:
    case True{}: tree!(~level,~True{},7n,0,0,s,M.open(old))
    case False{}: tree(~level,~False{},6n,0,0,s,M.open(old))

def render(~high: Bool, gpu: Bool, s: State, old: Image) -> State & Image:
  render_level(~Bool.pick(Nat,high,1n,0n),gpu,s,old)
