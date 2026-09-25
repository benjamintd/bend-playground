import Base
import ../spatial/layout.bend as L
import ../core/vec3.bend as V

def quadratic(a: L.Point, b: L.Point, c: L.Point, +t: F32) -> L.Point:
  +s = (1.0 - t : F32)
  V.add(V.mul(a,(s * s : F32)),V.add(V.mul(b,(2.0 * s * t : F32)),V.mul(c,(t * t : F32))))
def tangent(a: L.Point, +b: L.Point, c: L.Point, +t: F32) -> L.Point:
  V.mul(V.add(V.mul(V.sub(b,a),(1.0 - t : F32)),V.mul(V.sub(c,b),t)),2.0)
