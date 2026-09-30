import Base

# Shared pixel-buffer to Image assembly. Template children expand to the same
# straight-line 2/4/8/16/32-pixel tiles: no runtime recursion, closures or forks.
def pixel(r: Array<U32> & U32) -> Array<U32> & Image:
  (pixels,c) = r
  (pixels,Pix{c})
def read(~width: U32, x: U32, y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  pixel(Array.get(U32,pixels,(x + y * width : U32)))
def combine(a: Image, b: Image, c: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels,d) = r
  (pixels,Qua{a,b,c,d})
def quad_c(~child: U32 -> U32 -> Array<U32> -> Array<U32> & Image,
  x: U32, y: U32, a: Image, b: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels,c) = r
  combine(a,b,c,child(x,y,pixels))
def quad_b(~span: U32, ~child: U32 -> U32 -> Array<U32> -> Array<U32> & Image,
  +x: U32, +y: U32, a: Image, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels,b) = r
  quad_c(~child,(x + span : U32),(y + span : U32),a,b,child(x,(y + span : U32),pixels))
def quad_a(~span: U32, ~child: U32 -> U32 -> Array<U32> -> Array<U32> & Image,
  +x: U32, +y: U32, r: Array<U32> & Image) -> Array<U32> & Image:
  (pixels,a) = r
  quad_b(~span,~child,x,y,a,child((x + span : U32),y,pixels))
def quad(~span: U32, ~child: U32 -> U32 -> Array<U32> -> Array<U32> & Image,
  +x: U32, +y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  quad_a(~span,~child,x,y,child(x,y,pixels))
def square2(~width: U32, x: U32, y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  quad(~1,~read(~width),x,y,pixels)
def square4(~width: U32, x: U32, y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  quad(~2,~square2(~width),x,y,pixels)
def square8(~width: U32, x: U32, y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  quad(~4,~square4(~width),x,y,pixels)
def square16(~width: U32, x: U32, y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  quad(~8,~square8(~width),x,y,pixels)
def square32(~width: U32, x: U32, y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  quad(~16,~square16(~width),x,y,pixels)
def gpu_leaf(~width: U32, level: U32, x: U32, y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  match level:
    case 0: square4(~width,x,y,pixels)
    case 1: square8(~width,x,y,pixels)
    case _: square16(~width,x,y,pixels)
def cpu_leaf(~width: U32, level: U32, x: U32, y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  match level:
    case 0: square8(~width,x,y,pixels)
    case 1: square16(~width,x,y,pixels)
    case _: square32(~width,x,y,pixels)
# Levels 0/1/2 mean 512/1024/2048. Small leaves are 4/8/16 pixels;
# CPU leaves are twice as wide. Callers provide an in-bounds tile origin.
def leaf(~level: Nat, small: Bool, x: U32, y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  match small:
    case True{}: gpu_leaf(~U32.shln(512,level),U32.from_nat(level),x,y,pixels)
    case False{}: cpu_leaf(~U32.shln(512,level),U32.from_nat(level),x,y,pixels)
