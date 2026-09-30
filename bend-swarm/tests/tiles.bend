import Base
import ../engine/render/tiles.bend as Tiles
import ../engine/render/downsample.bend as Resolve

def written(i: U32, +color: U32, r: Array<U32> & U32) -> Array<U32> & Image:
  (pixels,previous) = r
  # Detect duplicate writers as well as holes and writes outside the region.
  (Array.set(U32,pixels,i,(color + Bool.to_u32(U32.is_ne(previous,1234567)) * 16777216 : U32)),Pix{color})
def leaf(x: U32, y: U32, pixels: Array<U32>, image: Image) -> Array<U32> & Image:
  +i = (x + y * 64 : U32)
  written(i,Resolve.color(image),Array.get(U32,pixels,i))
def run(gpu: Bool, depth: Nat, pixels: Array<U32>, image: Image) -> Array<U32> & Image:
  match gpu:
    case True{}: Tiles.tree!(~Array<U32>,~1,~leaf,~Array.join(U32),depth,0,0,pixels,Tiles.open(image))
    case False{}: Tiles.tree(~Array<U32>,~1,~leaf,~Array.join(U32),depth,0,0,pixels,Tiles.open(image))
def resolve(gpu: Bool, pixels: Array<U32>, image: Image) -> Array<U32> & Image:
  Resolve.render(~0n,gpu,pixels,image)
