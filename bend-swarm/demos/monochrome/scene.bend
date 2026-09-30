import Base
import ../../engine/spatial/layout.bend as L
import ../../engine/geometry/solid.bend as S
import ../../engine/render/project.bend as P

# A moving stack and orbiting cubes expose silhouettes, overlap, thin surfaces
# and projection changes. Every face is exactly black or white, with unit light.
def stack(+n: Nat, +time: F32, out: List<&2, P.Triangle>) -> List<&2, P.Triangle>:
  match n:
    case 0n: out
    case 1n+k:
      +i = F32.from_nat(k)
      +angle = (time * 0.35 + i * 0.18 + 0.3 * F32.sin((time * 0.7 + i * 0.3 : F32)) : F32)
      stack(k,time,S.box(L.Point{0.0,(0.35 + i * 0.22 : F32),0.0},L.Point{1.45,0.055,1.45},angle,0.0,16777215,0,0,out))
def satellites(+n: Nat, +time: F32, out: List<&2, P.Triangle>) -> List<&2, P.Triangle>:
  match n:
    case 0n: out
    case 1n+k:
      +i = F32.from_nat(k)
      +a = (i * 0.785398163 + time * 0.22 : F32)
      satellites(k,time,S.box(L.Point{(3.7 * F32.cos(a) : F32),(1.8 + 0.75 * F32.sin((a * 2.0 + time : F32)) : F32),(3.7 * F32.sin(a) : F32)},
        L.Point{0.32,0.32,0.32},F32.neg(a),(time * 0.5 + i : F32),16777215,0,0,out))
def floor(+n: Nat, out: List<&2, P.Triangle>) -> List<&2, P.Triangle>:
  match n:
    case 0n: out
    case 1n+k:
      +i = U32.from_nat(k)
      +x = (U32.to_f32((i % 8 : U32)) - 4.0 : F32)
      +z = (U32.to_f32((i / 8 : U32)) - 4.0 : F32)
      floor(k,S.quad(L.Point{x,0.0,z},L.Point{(x + 1.0 : F32),0.0,z},L.Point{(x + 1.0 : F32),0.0,(z + 1.0 : F32)},L.Point{x,0.0,(z + 1.0 : F32)},
        L.word(U32.is_eq(U32.and((i + i / 8 : U32),1),0),0,16777215),out))
def triangles(+time: F32) -> List<&2, P.Triangle>:
  satellites(8n,time,stack(16n,time,floor(64n,Nil{})))
