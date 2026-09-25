import Base

# Consume the actual presentation tree and compare every represented pixel
# with the raster buffer. This catches quadtree/tile assembly errors that a
# framebuffer checksum alone cannot see. Verification executes on the host.
type Check is Type:
  Check{pixels: Array<U32>, compared: U32, mismatches: U32}
def compared(color: U32, count: U32, errors: U32, r: Array<U32> & U32) -> Check:
  (pixels,value) = r
  Check{pixels,(count + 1 : U32),(errors + Bool.to_u32(U32.is_ne(color,value)) : U32)}
def at(i: U32, color: U32, s: Check) -> Check:
  Check{pixels,count,errors} = s
  compared(color,count,errors,Array.get(U32,pixels,i))
def square(+width: U32, +size: U32, +x: U32, +y: U32, +color: U32, +n: Nat, s: Check) -> Check:
  match n:
    case 0n: s
    case 1n+k:
      +i = U32.from_nat(k)
      square(width,size,x,y,color,k,at((x + i % size + (y + i / size) * width : U32),color,s))
def image(img: Image, +width: U32, +size: U32, +x: U32, +y: U32, s: Check) -> Check:
  match img:
    case Pix{color}: square(width,size,x,y,color,U32.to_nat((size * size : U32)),s)
    case Qua{a,b,c,d}:
      +h = U32.max(1,(size / 2 : U32))
      image(d,width,h,(x + h : U32),(y + h : U32),
        image(c,width,h,x,(y + h : U32),
          image(b,width,h,(x + h : U32),y,image(a,width,h,x,y,s))))
