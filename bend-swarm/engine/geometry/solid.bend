import Base
import ../spatial/layout.bend as L
import ../core/vec3.bend as V
import ../render/project.bend as P

def quad(+a: L.Point, b: L.Point, +c: L.Point, d: L.Point, +color: U32, out: List<&2, P.Triangle>) -> List<&2, P.Triangle>:
  P.Triangle{P.Vertex{a,1.0},P.Vertex{b,1.0},P.Vertex{c,1.0},color}
    <> P.Triangle{P.Vertex{a,1.0},P.Vertex{c,1.0},P.Vertex{d,1.0},color} <> out
def rotate(p: L.Point, +yaw: F32, +tilt: F32) -> L.Point:
  L.Point{+x,+y,+z} = p
  +a = (x * F32.cos(yaw) - z * F32.sin(yaw) : F32)
  +b = (x * F32.sin(yaw) + z * F32.cos(yaw) : F32)
  L.Point{a,(y * F32.cos(tilt) - b * F32.sin(tilt) : F32),(y * F32.sin(tilt) + b * F32.cos(tilt) : F32)}
def corner(+center: L.Point, half: L.Point, yaw: F32, tilt: F32, +i: U32) -> L.Point:
  L.Point{x,y,z} = half
  V.add(center,rotate(L.Point{(x * L.pick(U32.is_eq(U32.and(i,1),0),F32.neg(1.0),1.0) : F32),
    (y * L.pick(U32.is_eq(U32.and(i,2),0),F32.neg(1.0),1.0) : F32),
    (z * L.pick(U32.is_eq(U32.and(i,4),0),F32.neg(1.0),1.0) : F32)},yaw,tilt))
def box(+center: L.Point, +half: L.Point, +yaw: F32, +tilt: F32, +top: U32, +side: U32, +front: U32, out: List<&2, P.Triangle>) -> List<&2, P.Triangle>:
  +a = corner(center,half,yaw,tilt,0)
  +b = corner(center,half,yaw,tilt,1)
  +c = corner(center,half,yaw,tilt,2)
  +d = corner(center,half,yaw,tilt,3)
  +e = corner(center,half,yaw,tilt,4)
  +f = corner(center,half,yaw,tilt,5)
  +g = corner(center,half,yaw,tilt,6)
  +h = corner(center,half,yaw,tilt,7)
  quad(a,b,d,c,front,quad(e,g,h,f,front,quad(a,c,g,e,side,quad(b,f,h,d,side,quad(c,d,h,g,top,quad(a,e,f,b,side,out))))))
