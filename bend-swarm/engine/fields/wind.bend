import Base
import ../spatial/layout.bend as L

# Coherent traveling gusts. Scalar sampling works for grass, cloth or particles.
def sample(+x: F32, +z: F32, +time: F32) -> L.Point:
  +wave = (0.55 + 0.25 * F32.sin((x * 0.74 + z * 0.42 - time * 1.8 : F32))
    + 0.2 * F32.sin((z * 1.2 - x * 0.35 - time * 2.4 : F32)) : F32)
  L.Point{(wave * (0.85 + 0.15 * F32.sin((time * 0.37 : F32))) : F32),0.0,
    (wave * 0.3 + F32.sin((x * 0.43 + z * 0.83 - time * 1.2 : F32)) * 0.16 : F32)}
