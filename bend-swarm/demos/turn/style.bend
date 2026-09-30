import Base
import ./model.bend as G
import ../../engine/core/math.bend as Math

# Art direction belongs to TURN. All colors are packed display-space RGB.
def cream() -> U32: 15396836
def muted() -> U32: 8098474
def mint() -> U32: 10154954
def amber() -> U32: 16761485
def channel(v: F32) -> U32: F32.to_u32(F32.clamp(v,0.0,255.0))
def rgb(r: F32, g: F32, b: F32) -> U32:
  (channel(r) * 65536 + channel(g) * 256 + channel(b) : U32)
def blend_channel(+a: U32, b: U32, t: F32) -> U32:
  channel((U32.to_f32(a) + (U32.to_f32(b) - U32.to_f32(a)) * t : F32))
def mix(+a: U32, +b: U32, +t: F32) -> U32:
  (blend_channel(U32.and(U32.shrn(a,16n),255),U32.and(U32.shrn(b,16n),255),t) * 65536
    + blend_channel(U32.and(U32.shrn(a,8n),255),U32.and(U32.shrn(b,8n),255),t) * 256
    + blend_channel(U32.and(a,255),U32.and(b,255),t) : U32)
def wall(q: G.Point) -> U32:
  G.Point{+x,+y,+z} = q
  +height = ((U32.to_f32(y) + U32.to_f32(z) * 0.35) / 12.15 : F32)
  mix(8890019,14213330,F32.clamp((height + Math.pick(U32.is_eq(((x + y + z) % 2 : U32),0),0.025,0.0) : F32),0.0,1.0))
def pulse(t: F32) -> F32: (0.5 + 0.5 * F32.sin(t) : F32)
