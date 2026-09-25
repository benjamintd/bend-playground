import Base
import ../spatial/layout.bend as L
import ../core/vec3.bend as V

# Catmull-Rom surface evaluation over any dense regular grid. The sample
# callback specializes away. Analytic derivatives supply smooth normals.
type Sample is Data:
  Sample{point: L.Point, du: L.Point, dv: L.Point}
def zero() -> Sample:
  Sample{V.zero(),V.zero(),V.zero()}
def weight(k: U32, +t: F32) -> F32:
  match k:
    case 0: ((F32.neg(t) + 2.0 * t * t - t * t * t) * 0.5 : F32)
    case 1: (1.0 - 2.5 * t * t + 1.5 * t * t * t : F32)
    case 2: ((t + 4.0 * t * t - 3.0 * t * t * t) * 0.5 : F32)
    case _: ((F32.neg((t * t : F32)) + t * t * t) * 0.5 : F32)
def derivative(k: U32, +t: F32) -> F32:
  match k:
    case 0: ((F32.neg(1.0) + 4.0 * t - 3.0 * t * t) * 0.5 : F32)
    case 1: (F32.neg(5.0) * t + 4.5 * t * t : F32)
    case 2: ((1.0 + 8.0 * t - 9.0 * t * t) * 0.5 : F32)
    case _: (F32.neg(t) + 1.5 * t * t : F32)
def index(+side: U32, +base: U32, +k: U32) -> U32:
  L.word(U32.is_eq(k,0),(base - U32.min(base,1) : U32),U32.min((side - 1 : U32),(base + k - 1 : U32)))
def accumulated(~S: Type, +wx: F32, +wy: F32, dx: F32, dy: F32, acc: Sample, r: S & L.Point) -> S & Sample:
  Sample{p,u,v} = acc
  (s,+value) = r
  (s,Sample{V.add(p,V.mul(value,(wx * wy : F32))),V.add(u,V.mul(value,(dx * wy : F32))),V.add(v,V.mul(value,(wx * dy : F32)))})
def sample_loop(~S: Type, ~read: @+i:U32 -> S -> S & L.Point, +n: Nat,
  +side: U32, +x: U32, +y: U32, +u: F32, +v: F32, r: S & Sample) -> S & Sample:
  match n:
    case 0n: r
    case 1n+k:
      (s,a) = r
      +cx = U32.and(U32.from_nat(k),3)
      +cy = U32.shrn(U32.from_nat(k),2n)
      sample_loop(~S,~read,k,side,x,y,u,v,accumulated(~S,weight(cx,u),weight(cy,v),derivative(cx,u),derivative(cy,v),a,
        read((index(side,x,cx) + index(side,y,cy) * side : U32),s)))
def sample_clamped(~S: Type, ~read: @+i:U32 -> S -> S & L.Point, +side: U32, +x: F32, +y: F32, s: S) -> S & Sample:
  sample_loop(~S,~read,16n,side,F32.to_u32(F32.floor(x)),F32.to_u32(F32.floor(y)),
    (x - F32.floor(x) : F32),(y - F32.floor(y) : F32),(s,zero()))

# The source must contain side*side points and side must be positive. Queries
# outside the grid clamp to its boundary; callback ownership is preserved.
def sample(~S: Type, ~read: @+i:U32 -> S -> S & L.Point, +side: U32, x: F32, y: F32, s: S) -> S & Sample:
  +last = U32.to_f32((side - 1 : U32))
  sample_clamped(~S,~read,side,F32.min(last,F32.max(0.0,x)),F32.min(last,F32.max(0.0,y)),s)
