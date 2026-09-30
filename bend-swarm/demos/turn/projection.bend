import Base
import ./model.bend as G
import ../../engine/render/mesh.bend as M

# Canonical world-to-camera transform. It never receives a character position.
# Each frame starts from immutable world coordinates, never the previous frame.
type V is Data:
  V{x: F32, y: F32, z: F32}
type Camera is Data:
  Camera{plane: G.Plane, cosine: F32, sine: F32, scale: F32}
def local(p: G.Plane, q: V) -> V:
  match p:
    case G.XY{}: q
    case G.YZ{}:
      V{x,y,z} = q
      V{y,z,x}
    case G.ZX{}:
      V{x,y,z} = q
      V{z,x,y}
def world(p: G.Plane, q: V) -> V:
  match p:
    case G.XY{}: q
    case G.YZ{}:
      V{x,y,z} = q
      V{z,x,y}
    case G.ZX{}:
      V{x,y,z} = q
      V{y,z,x}
def point(q: G.Point) -> V:
  G.Point{x,y,z} = q
  V{U32.to_f32(x),U32.to_f32(y),U32.to_f32(z)}
def camera(p: G.Plane, +turn: F32) -> Camera:
  +smooth = (turn * turn * (3.0 - 2.0 * turn) : F32)
  +angle = (smooth * 2.094395102 : F32)
  Camera{p,F32.cos(angle),F32.sin(angle),(30.0 - 10.0 * F32.sin((turn * F32.pi() : F32)) : F32)}
# Rodrigues rotation about (1,1,1), negative 120 degrees. Endpoints map
# (x,y,z) to (y,z,x) exactly up to floating point rendering precision.
def rotated_local(+co: F32, +si: F32, q: V) -> V:
  V{x,y,z} = q
  +a = (x - 4.5 : F32)
  +b = (y - 4.5 : F32)
  +d = (z - 4.5 : F32)
  +sum = ((a + b + d) * (1.0 - co) / 3.0 : F32)
  +s = (si * 0.577350269 : F32)
  V{(a * co + (b - d) * s + sum : F32),(b * co + (d - a) * s + sum : F32),
    (d * co + (a - b) * s + sum : F32)}
def rotated(c: Camera, q: V) -> V:
  Camera{p,co,si,_} = c
  rotated_local(co,si,local(p,q))
def projected(+scale: F32, q: V) -> M.Vertex:
  V{x,y,z} = q
  # Mesh interpolates reciprocal depth. Encode orthographic depth so 1/z
  # remains affine across a face; separate coplanar paintings then agree.
  M.Vertex{(256.0 + x * scale : F32),(282.0 - y * scale : F32),(900.0 / (30.0 + z) : F32),1.0}
def project(+c: Camera, q: V) -> M.Vertex:
  Camera{_,_,_,scale} = c
  projected(scale,rotated(c,q))

def depth(q: V) -> F32:
  V{_,_,z} = q
  z
