import Base
import ../spatial/layout.bend as L

def unpack(+c: U32) -> L.Point:
  L.Point{U32.to_f32(U32.and(U32.shrn(c,16n),255)),U32.to_f32(U32.and(U32.shrn(c,8n),255)),U32.to_f32(U32.and(c,255))}
def channel(v: F32) -> U32:
  F32.to_u32(F32.min(255.0,F32.max(0.0,v)))
def pack(c: L.Point) -> U32:
  L.Point{r,g,b} = c
  (channel(r) * 65536 + channel(g) * 256 + channel(b) : U32)
def luma(c: L.Point) -> F32:
  L.Point{r,g,b} = c
  (r * 0.299 + g * 0.587 + b * 0.114 : F32)
