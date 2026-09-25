import Base
import ./mesh.bend as M
import ../spatial/layout.bend as L

# Exact four-sample box resolve. The source Image is owned and consumed,
# so output pixels may reuse the larger raster array without read/write aliasing.
def channel(+a: U32, +b: U32, +c: U32, +d: U32, +shift: Nat) -> U32:
  ((U32.and(U32.shrn(a,shift),255) + U32.and(U32.shrn(b,shift),255)
    + U32.and(U32.shrn(c,shift),255) + U32.and(U32.shrn(d,shift),255)) / 4 : U32)
def average(+a: U32, +b: U32, +c: U32, +d: U32) -> U32:
  (channel(a,b,c,d,16n) * 65536 + channel(a,b,c,d,8n) * 256 + channel(a,b,c,d,0n) : U32)
def color(image: Image) -> U32:
  match image:
    case Pix{c}: c
    case Qua{a,b,c,d}: average(color(a),color(b),color(c),color(d))
def fill(~level: Nat, +n: Nat, +x: U32, +y: U32, image: M.Four, p: Array<U32>) -> Array<U32>:
  match n:
    case 0n:
      M.Four{a,b,c,d} = image
      Array.set(U32,p,(x + y * U32.shln(512,level) : U32),color(Qua{a,b,c,d}))
    case 1n+k:
      M.Four{a,b,c,d} = image
      +h = U32.shln(1,k)
      fill(~level,k,(x + h : U32),(y + h : U32),M.open(d),
        fill(~level,k,x,(y + h : U32),M.open(c),
          fill(~level,k,(x + h : U32),y,M.open(b),fill(~level,k,x,y,M.open(a),p))))
def joined(a: Array<U32> & Image, b: Array<U32> & Image, c: Array<U32> & Image, d: Array<U32> & Image) -> Array<U32> & Image:
  (ap,ai) = a
  (bp,bi) = b
  (cp,ci) = c
  (dp,di) = d
  (Array.join(U32,Array.join(U32,ap,bp),Array.join(U32,cp,dp)),Qua{ai,bi,ci,di})
# Owned disjoint source subtrees; exclusive output rectangles; same-array joins.
@unsafe
def tree(~level: Nat, ~small: Bool, +depth: Nat, +x: U32, +y: U32, image: M.Four, +pixels: Array<U32>) -> Array<U32> & Image:
  match depth:
    case 0n:
      M.Four{a,b,c,d} = image
      M.square_leaf_level(~level,small,x,y,fill(~level,Nat.add(level,Bool.pick(Nat,small,2n,3n)),x,y,M.Four{a,b,c,d},pixels))
    case 1n+k:
      M.Four{a,b,c,d} = image
      +h = U32.shln(U32.shln(L.word(small,4,8),level),k)
      ra rb rc rd = tree(~level,~small,k,x,y,M.open(a),pixels) tree(~level,~small,k,(x + h : U32),y,M.open(b),pixels)
        tree(~level,~small,k,x,(y + h : U32),M.open(c),pixels) tree(~level,~small,k,(x + h : U32),(y + h : U32),M.open(d),pixels)
      joined(ra,rb,rc,rd)
def render(~level: Nat, gpu: Bool, pixels: Array<U32>, image: Image) -> Array<U32> & Image:
  match gpu:
    case True{}: tree!(~level,~True{},7n,0,0,M.open(image),pixels)
    case False{}: tree(~level,~False{},6n,0,0,M.open(image),pixels)
