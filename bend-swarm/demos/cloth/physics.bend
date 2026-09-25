import Base
import ./world.bend as W
import ../../engine/core/vec3.bend as Contact
import ../../engine/spatial/layout.bend as L
import ../../engine/parallel/regions.bend as Region

def space() -> L.Layout:
  L.Layout{3,5n,5n,5n,0.25,F32.neg(4.0),F32.neg(2.0),F32.neg(4.0),False{}}

type Controls is Data:
  Controls{side: U32, grab: U32, gx: F32, gy: F32, gz: F32, time: F32, wind: F32}

def pinned(+side: U32, +i: U32) -> Bool:
  U32.is_eq(i,0) || U32.is_eq(i,(side * side - 1 : U32))

def pick(c: Bool, a: L.Point, b: L.Point) -> L.Point:
  match c:
    case True{}: a
    case False{}: b

def sphere_projection(tiny: Bool, r: F32, dx: F32, dy: F32, dz: F32) -> L.Point:
  match tiny:
    case True{}: L.Point{0.0,0.97,0.0}
    case False{}:
      +scale = (1.22 / r : F32)
      L.Point{(dx * scale : F32),(dy * scale - 0.25 : F32),(dz * scale : F32)}

def contact_sphere(hit: Bool, x: F32, +y: F32, z: F32, +r: F32, dx: F32, dy: F32, dz: F32) -> L.Point:
  match hit:
    case False{}: L.Point{x,F32.max(y,F32.neg(1.6)),z}
    case True{}: sphere_projection((r < 0.000001 : F32),r,dx,dy,dz)

def contact(p: L.Point) -> L.Point:
  L.Point{+x,+y,+z} = p
  +dy = (y + 0.25 : F32)
  +r = F32.sqrt((x * x + dy * dy + z * z : F32))
  contact_sphere((r < 1.22 : F32),x,y,z,r,x,dy,z)

def constrained(i: U32, c: Controls, p: L.Point) -> L.Point:
  Controls{+side,grab,gx,gy,gz,_,_} = c
  +id = i
  pick(pinned(side,id),W.rest(side,id),contact(p))

def predicted(+i: U32, +c: Controls, old: L.Point, now: L.Point) -> L.Point:
  Controls{_,grab,gx,gy,gz,time,wind} = c
  L.Point{ox,oy,oz} = old
  L.Point{+x,+y,+z} = now
  # Verlet prediction at 120 Hz; bounded compliant dragging avoids teleportation.
  +gust = (wind * (0.65 + 0.35 * F32.sin((time * 1.7 + x * 2.0 + z : F32))) : F32)
  Contact.limited(L.Point{x,y,z},constrained(i,c,Contact.lerp(L.Point{
    (x + (x - ox) * 0.995 + gust * 0.00006944445 : F32),
    (y + (y - oy) * 0.995 - 9.81 * 0.00006944445 : F32),
    (z + (z - oz) * 0.995 + gust * 0.7 * 0.00006944445 : F32)},contact(L.Point{gx,gy,gz}),L.pick(U32.is_eq(i,grab),0.04,0.0))),0.02)

type Prediction is Type:
  Prediction{current: W.Positions, previous: W.Positions, output: W.Positions, controls: Controls}

def predict_previous(+i: U32, +c: Controls, current: W.Positions, out: W.Positions, self: L.Point,
  r: W.Positions & L.Point) -> Prediction:
  (old,prior) = r
  Prediction{current,old,W.write(i,out,predicted(i,c,prior,self)),c}

def predict_current(+i: U32, +c: Controls, old: W.Positions, out: W.Positions, r: W.Positions & L.Point) -> Prediction:
  (current,self) = r
  predict_previous(i,c,current,out,self,W.read(i,old))

def predict_loop(n: Nat, +i: U32, p: Prediction) -> Prediction:
  match n:
    case 0n: p
    case 1n+k:
      Prediction{current,old,out,c} = p
      predict_loop(k,(i + 1 : U32),predict_current(i,c,old,out,W.read(i,current)))

def predict_leaf(start: U32, n: U32, p: Prediction) -> Prediction:
  predict_loop(U32.to_nat(n),start,p)

def predict_join(a: Prediction, b: Prediction) -> Prediction:
  Prediction{ac,ap,ao,c} = a
  Prediction{bc,bp,bo,_} = b
  Prediction{W.join(ac,bc),W.join(ap,bp),W.join(ao,bo),c}

def predict(depth: Nat, +n: U32, p: Prediction) -> Prediction:
  Region.run(~Prediction,~predict_leaf,~predict_join,Nat.min(depth,U32.log2(n)),0,n,p)

def predict_run(gpu: Bool, depth: Nat, n: U32, p: Prediction) -> Prediction:
  match gpu:
    case True{}: predict!(depth,n,p)
    case False{}: predict(depth,n,p)

# Twelve distance constraints: structural, shear and bending neighbors.
type Link is Data:
  Link{valid: Bool, id: U32, rest: F32}

def link(k: U32, +i: U32, +side: U32) -> Link:
  match k:
    case 0: Link{(i % side > 0 : U32),(i - 1 : U32),1.0}
    case 1: Link{(i % side < side - 1 : U32),(i + 1 : U32),1.0}
    case 2: Link{(i >= side : U32),(i - side : U32),1.0}
    case 3: Link{(i < side * (side - 1) : U32),(i + side : U32),1.0}
    case 4: Link{((i % side > 0) && (i >= side) : U32),(i - side - 1 : U32),1.41421356}
    case 5: Link{((i % side < side - 1) && (i >= side) : U32),(i - side + 1 : U32),1.41421356}
    case 6: Link{((i % side > 0) && (i < side * (side - 1)) : U32),(i + side - 1 : U32),1.41421356}
    case 7: Link{((i % side < side - 1) && (i < side * (side - 1)) : U32),(i + side + 1 : U32),1.41421356}
    case 8: Link{(i % side > 1 : U32),(i - 2 : U32),2.0}
    case 9: Link{(i % side < side - 2 : U32),(i + 2 : U32),2.0}
    case 10: Link{(i >= side * 2 : U32),(i - side * 2 : U32),2.0}
    case _: Link{(i < side * (side - 2) : U32),(i + side * 2 : U32),2.0}

type Correction is Data:
  Correction{x: F32, y: F32, z: F32, count: U32}

def spring(self: L.Point, other: L.Point, rest: F32, fixed: Bool, a: Correction) -> Correction:
  L.Point{x,y,z} = self
  L.Point{nx,ny,nz} = other
  Correction{ax,ay,az,n} = a
  +dx = (nx - x : F32)
  +dy = (ny - y : F32)
  +dz = (nz - z : F32)
  +length = F32.max(F32.sqrt((dx * dx + dy * dy + dz * dz : F32)),0.000001)
  +scale = ((length - rest) / length * L.pick(fixed,1.0,0.5) : F32)
  Correction{(ax + dx * scale : F32),(ay + dy * scale : F32),(az + dz * scale : F32),(n + 1 : U32)}

def spring_read(self: L.Point, rest: F32, fixed: Bool, a: Correction, r: W.Positions & L.Point) -> W.Positions & Correction:
  (p,other) = r
  (p,spring(self,other,rest,fixed,a))

def spring_valid(valid: Bool, +id: U32, side: U32, grab: U32, self: L.Point, rest: F32,
  r: W.Positions & Correction) -> W.Positions & Correction:
  match valid:
    case False{}: r
    case True{}:
      (p,a) = r
      spring_read(self,rest,pinned(side,id),a,W.read(id,p))

def spring_link(side: U32, grab: U32, self: L.Point, spacing: F32, l: Link,
  r: W.Positions & Correction) -> W.Positions & Correction:
  Link{valid,id,multiple} = l
  spring_valid(valid,id,side,grab,self,(spacing * multiple : F32),r)

def springs(+n: Nat, +i: U32, +side: U32, +grab: U32, +self: L.Point,
  r: W.Positions & Correction) -> W.Positions & Correction:
  match n:
    case 0n: r
    case 1n+k:
      springs(k,i,side,grab,self,spring_link(side,grab,self,(3.6 / U32.to_f32((side - 1 : U32)) : F32),link(U32.from_nat(k),i,side),r))

def corrected(self: L.Point, a: Correction) -> L.Point:
  L.Point{x,y,z} = self
  Correction{dx,dy,dz,n} = a
  +scale = (1.4 / U32.to_f32(U32.max(n,1)) : F32)
  L.Point{(x + dx * scale : F32),(y + dy * scale : F32),(z + dz * scale : F32)}

type Relaxation is Type:
  Relaxation{source: W.Positions, output: W.Positions, controls: Controls}

def relaxed(+i: U32, self: L.Point, out: W.Positions, +c: Controls, r: W.Positions & Correction) -> Relaxation:
  (p,a) = r
  +original = self
  Relaxation{p,W.write(i,out,constrained(i,c,corrected(original,a))),c}

def relax_read(+i: U32, out: W.Positions, +c: Controls, r: W.Positions & L.Point) -> Relaxation:
  Controls{side,grab,_,_,_,_,_} = c
  (p,+self) = r
  relaxed(i,self,out,c,springs(12n,i,side,grab,self,(p,Correction{0.0,0.0,0.0,0})))

def relax_loop(n: Nat, +i: U32, r: Relaxation) -> Relaxation:
  match n:
    case 0n: r
    case 1n+p:
      Relaxation{s,out,c} = r
      relax_loop(p,(i + 1 : U32),relax_read(i,out,c,W.read(i,s)))

def relax_leaf(start: U32, n: U32, r: Relaxation) -> Relaxation:
  relax_loop(U32.to_nat(n),start,r)

def relax_join(a: Relaxation, b: Relaxation) -> Relaxation:
  Relaxation{as,ao,c} = a
  Relaxation{bs,bo,_} = b
  Relaxation{W.join(as,bs),W.join(ao,bo),c}

def relax(depth: Nat, +n: U32, r: Relaxation) -> Relaxation:
  Region.run(~Relaxation,~relax_leaf,~relax_join,Nat.min(depth,U32.log2(n)),0,n,r)

def relax_run(gpu: Bool, depth: Nat, n: U32, r: Relaxation) -> Relaxation:
  match gpu:
    case True{}: relax!(depth,n,r)
    case False{}: relax(depth,n,r)

# Grid-distance exclusion shared by the surface stencil.
def diff(+a: U32, +b: U32) -> U32:
  (U32.max(a,b) - U32.min(a,b) : U32)
