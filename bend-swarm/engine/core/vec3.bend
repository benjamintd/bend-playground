import Base
import ../spatial/layout.bend as L

def add(a: L.Point, b: L.Point) -> L.Point:
  L.Point{x,y,z} = a
  L.Point{u,v,w} = b
  L.Point{(x + u : F32),(y + v : F32),(z + w : F32)}
def sub(a: L.Point, b: L.Point) -> L.Point:
  L.Point{x,y,z} = a
  L.Point{u,v,w} = b
  L.Point{(x - u : F32),(y - v : F32),(z - w : F32)}
def mul(a: L.Point, +s: F32) -> L.Point:
  L.Point{x,y,z} = a
  L.Point{(x * s : F32),(y * s : F32),(z * s : F32)}
def dot(a: L.Point, b: L.Point) -> F32:
  L.Point{x,y,z} = a
  L.Point{u,v,w} = b
  (x * u + y * v + z * w : F32)
def cross(a: L.Point, b: L.Point) -> L.Point:
  L.Point{+x,+y,+z} = a
  L.Point{+u,+v,+w} = b
  L.Point{(y * w - z * v : F32),(z * u - x * w : F32),(x * v - y * u : F32)}
def length(+p: L.Point) -> F32:
  F32.sqrt(dot(p,p))
def unit(+p: L.Point) -> L.Point:
  mul(p,(1.0 / F32.max(length(p),0.0000001) : F32))
def zero() -> L.Point:
  L.Point{0.0,0.0,0.0}
def clamp(x: F32) -> F32:
  F32.min(1.0,F32.max(0.0,x))
def lerp(+a: L.Point, b: L.Point, t: F32) -> L.Point:
  add(a,mul(sub(b,a),t))
def limited(+old: L.Point, next: L.Point, limit: F32) -> L.Point:
  +delta = sub(next,old)
  add(old,mul(delta,F32.min(1.0,(limit / F32.max(length(delta),0.0000001) : F32))))

def minimum(a: L.Point, b: L.Point) -> L.Point:
  L.Point{x,y,z} = a
  L.Point{u,v,w} = b
  L.Point{F32.min(x,u),F32.min(y,v),F32.min(z,w)}
def maximum(a: L.Point, b: L.Point) -> L.Point:
  L.Point{x,y,z} = a
  L.Point{u,v,w} = b
  L.Point{F32.max(x,u),F32.max(y,v),F32.max(z,w)}
