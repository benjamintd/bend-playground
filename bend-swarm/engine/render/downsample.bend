import Base
import ./image.bend as ImageBuffer
import ./tiles.bend as Tiles

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
def fill(~level: Nat, +n: Nat, +x: U32, +y: U32, image: Tiles.Four, p: Array<U32>) -> Array<U32>:
  match n:
    case 0n:
      Tiles.Four{a,b,c,d} = image
      Array.set(U32,p,(x + y * U32.shln(512,level) : U32),color(Qua{a,b,c,d}))
    case 1n+k:
      Tiles.Four{a,b,c,d} = image
      +h = U32.shln(1,k)
      fill(~level,k,(x + h : U32),(y + h : U32),Tiles.open(d),
        fill(~level,k,x,(y + h : U32),Tiles.open(c),
          fill(~level,k,(x + h : U32),y,Tiles.open(b),fill(~level,k,x,y,Tiles.open(a),p))))
# The image is input here, not discarded history. Its owned subtree must reach
# fill before being consumed; output writes may reuse the larger pixel array.
def leaf(~level: Nat, ~small: Bool, +x: U32, +y: U32, pixels: Array<U32>, image: Image) -> Array<U32> & Image:
  ImageBuffer.leaf(~level,small,x,y,fill(~level,Nat.add(level,Bool.pick(Nat,small,2n,3n)),x,y,Tiles.open(image),pixels))
def tile(~level: Nat, ~small: Bool, x: U32, y: U32, pixels: Array<U32>, image: Image) -> Array<U32> & Image:
  leaf(~level,~small,x,y,pixels,image)
def render(~level: Nat, gpu: Bool, pixels: Array<U32>, image: Image) -> Array<U32> & Image:
  match gpu:
    case True{}: Tiles.tree!(~Array<U32>,~U32.shln(4,level),~tile(~level,~True{}),~Array.join(U32),7n,0,0,pixels,Tiles.open(image))
    case False{}: Tiles.tree(~Array<U32>,~U32.shln(8,level),~tile(~level,~False{}),~Array.join(U32),6n,0,0,pixels,Tiles.open(image))
