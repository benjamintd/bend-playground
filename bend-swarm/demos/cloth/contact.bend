import Base
import ../../engine/spatial/layout.bend as L
import ../../engine/core/vec3.bend as V

# Surface contact geometry; all values are flat scalars. Previous positions
# preserve which side of a face/edge a moving feature approached from.

type Push is Data:
  Push{delta: L.Point, weight: F32}
def none() -> Push:
  Push{V.zero(),0.0}
def sum(a: Push, b: Push) -> Push:
  Push{ad,aw} = a
  Push{bd,bw} = b
  Push{V.add(ad,bd),(aw + bw : F32)}
def result(p: L.Point, a: Push) -> L.Point:
  Push{d,w} = a
  V.add(p,V.mul(d,(1.0 / F32.max(w,1.0) : F32)))

# The barycentric test uses a small margin only for floating point edge ties.
def face_inside(+p: L.Point, +a: L.Point, +b: L.Point, c: L.Point) -> Bool:
  +e = V.sub(b,a)
  +f = V.sub(c,a)
  +q = V.sub(p,a)
  +ee = V.dot(e,e)
  +ff = V.dot(f,f)
  +ef = V.dot(e,f)
  +qe = V.dot(q,e)
  +qf = V.dot(q,f)
  +den = (ee * ff - ef * ef : F32)
  +u = ((ff * qe - ef * qf) / F32.max(den,0.0000000001) : F32)
  +v = ((ee * qf - ef * qe) / F32.max(den,0.0000000001) : F32)
  (den > 0.0000000001 : F32) && (u >= F32.neg(0.00001) : F32)
    && (v >= F32.neg(0.00001) : F32) && (u + v <= 1.00001 : F32)

def face_push(hit: Bool, normal: L.Point, signed: F32) -> Push:
  match hit:
    case False{}: none()
    case True{}: Push{V.mul(normal,F32.min(0.04,(0.018 - signed : F32))),1.0}

def face_unchecked(+p: L.Point, old: L.Point, +a: L.Point, +b: L.Point, +c: L.Point,
  +oa: L.Point, ob: L.Point, oc: L.Point) -> Push:
  +normal = V.unit(V.cross(V.sub(b,a),V.sub(c,a)))
  +previous = V.dot(V.sub(old,oa),V.unit(V.cross(V.sub(ob,oa),V.sub(oc,oa))))
  +oriented = V.mul(normal,L.pick((previous >= 0.0 : F32),1.0,F32.neg(1.0)))
  +signed = V.dot(V.sub(p,a),oriented)
  face_push((signed < 0.018 : F32) && (signed > F32.neg(0.08) : F32)
    && face_inside(p,a,b,c),oriented,signed)

def axis_point(+x: F32, +a: F32, +b: F32, +c: F32) -> Bool:
  (x >= F32.min(a,F32.min(b,c)) - 0.08 : F32) && (x <= F32.max(a,F32.max(b,c)) + 0.08 : F32)
def face_bounds(p: L.Point, a: L.Point, b: L.Point, c: L.Point) -> Bool:
  L.Point{x,y,z} = p
  L.Point{ax,ay,az} = a
  L.Point{bx,by,bz} = b
  L.Point{cx,cy,cz} = c
  axis_point(x,ax,bx,cx) && axis_point(y,ay,by,cy) && axis_point(z,az,bz,cz)
def face_if(near: Bool, p: L.Point, old: L.Point, a: L.Point, b: L.Point, c: L.Point,
  oa: L.Point, ob: L.Point, oc: L.Point) -> Push:
  match near:
    case False{}: none()
    case True{}: face_unchecked(p,old,a,b,c,oa,ob,oc)
def face(+p: L.Point, old: L.Point, +a: L.Point, +b: L.Point, +c: L.Point,
  oa: L.Point, ob: L.Point, oc: L.Point) -> Push:
  face_if(face_bounds(p,a,b,c),p,old,a,b,c,oa,ob,oc)

# Closest points of two finite segments, including parallel/degenerate cases.
type Parameters is Data:
  Parameters{s: F32, t: F32}
def parameters(+a: L.Point, b: L.Point, +c: L.Point, d: L.Point) -> Parameters:
  +u = V.sub(b,a)
  +v = V.sub(d,c)
  +r = V.sub(a,c)
  +aa = V.dot(u,u)
  +bb = V.dot(u,v)
  +cc = V.dot(v,v)
  +dd = V.dot(u,r)
  +ee = V.dot(v,r)
  +den = (aa * cc - bb * bb : F32)
  +s0 = V.clamp(((bb * ee - cc * dd) / F32.max(den,0.0000000001) : F32))
  +t = V.clamp(((bb * s0 + ee) / F32.max(cc,0.0000000001) : F32))
  Parameters{V.clamp(((bb * t - dd) / F32.max(aa,0.0000000001) : F32)),t}

def edge_push(hit: Bool, direction: L.Point, signed: F32, +endpoint: F32) -> Push:
  match hit:
    case False{}: none()
    case True{}: Push{V.mul(direction,(F32.min(0.04,(0.018 - signed : F32)) * endpoint : F32)),endpoint}

def edge_pair(+a: L.Point, b: L.Point, +c: L.Point, d: L.Point,
  oa: L.Point, ob: L.Point, oc: L.Point, od: L.Point, pair: Parameters) -> Push:
  Parameters{+s,+t} = pair
  +delta = V.sub(V.lerp(a,b,s),V.lerp(c,d,t))
  +prior = V.sub(V.lerp(oa,ob,s),V.lerp(oc,od,t))
  +distance = V.length(delta)
  # Previous separation supplies a stable normal at zero distance and crossing.
  +normal = V.unit(prior)
  +signed = V.dot(delta,normal)
  edge_push((distance < 0.04 : F32) && (signed < 0.018 : F32)
    && (V.length(prior) > 0.0000001 : F32),normal,signed,(1.0 - s : F32))

def edge_unchecked(+a: L.Point, +b: L.Point, +c: L.Point, +d: L.Point,
  oa: L.Point, ob: L.Point, oc: L.Point, od: L.Point) -> Push:
  edge_pair(a,b,c,d,oa,ob,oc,od,parameters(a,b,c,d))

def axis_overlap(+a: F32, +b: F32, +c: F32, +d: F32) -> Bool:
  (F32.min(a,b) <= F32.max(c,d) + 0.04 : F32) && (F32.min(c,d) <= F32.max(a,b) + 0.04 : F32)
def overlap(a: L.Point, b: L.Point, c: L.Point, d: L.Point) -> Bool:
  L.Point{ax,ay,az} = a
  L.Point{bx,by,bz} = b
  L.Point{cx,cy,cz} = c
  L.Point{dx,dy,dz} = d
  axis_overlap(ax,bx,cx,dx) && axis_overlap(ay,by,cy,dy) && axis_overlap(az,bz,cz,dz)
def edge_if(near: Bool, a: L.Point, b: L.Point, c: L.Point, d: L.Point,
  oa: L.Point, ob: L.Point, oc: L.Point, od: L.Point) -> Push:
  match near:
    case False{}: none()
    case True{}: edge_unchecked(a,b,c,d,oa,ob,oc,od)
def edge(+a: L.Point, +b: L.Point, +c: L.Point, +d: L.Point,
  oa: L.Point, ob: L.Point, oc: L.Point, od: L.Point) -> Push:
  edge_if(overlap(a,b,c,d),a,b,c,d,oa,ob,oc,od)
