import Base
import ../engine/render/image.bend as Pixels

def tile(size: U32, x: U32, y: U32, pixels: Array<U32>) -> Array<U32> & Image:
  match size:
    case 2: Pixels.square2(~64,x,y,pixels)
    case 4: Pixels.square4(~64,x,y,pixels)
    case 8: Pixels.square8(~64,x,y,pixels)
    case 16: Pixels.square16(~64,x,y,pixels)
    case _: Pixels.square32(~64,x,y,pixels)
