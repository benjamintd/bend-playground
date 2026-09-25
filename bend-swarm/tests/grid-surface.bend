import Base
import ../engine/geometry/grid_surface.bend as G
import ../engine/spatial/layout.bend as L

def read(+i: U32, visits: U32) -> U32 & L.Point:
  +x = U32.to_f32((i % 8 : U32))
  +y = U32.to_f32((i / 8 : U32))
  ((visits + 1 : U32),L.Point{x,(2.0 * x + 3.0 * y : F32),y})
def sample(x: F32, y: F32) -> U32 & G.Sample:
  G.sample(~U32,~read,8,x,y,0)
