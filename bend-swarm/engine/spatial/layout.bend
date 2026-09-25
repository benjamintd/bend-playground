import Base

# All configuration is supplied as a template argument; no shared config record
# is read in a neighbor loop. A two-dimensional space ignores point.z.
type Layout is Data:
  Layout{dimensions: U32, x_bits: Nat, y_bits: Nat, z_bits: Nat,
    cell_size: F32, origin_x: F32, origin_y: F32, origin_z: F32, periodic: Bool}

type Point is Data:
  Point{x: F32, y: F32, z: F32}

type Delta is Data:
  Delta{x: F32, y: F32, z: F32, squared: F32}

def finite(+x: F32) -> Bool:
  (x > F32.neg(1000000000.0) : F32) && (x < 1000000000.0 : F32)

def valid(c: Layout) -> Bool:
  Layout{+dims,+xb,+yb,+zb,+size,ox,oy,oz,_} = c
  (U32.is_eq(dims,2) || U32.is_eq(dims,3))
    && (U32.is_eq(dims,3) || Nat.is_eq(zb,0n))
    && Nat.is_le(Nat.add(Nat.add(xb,yb),zb),20n)
    && (size > 0.0 : F32) && finite(size) && finite(ox) && finite(oy) && finite(oz)

def bits(c: Layout) -> Nat:
  Layout{_,x,y,z,_,_,_,_,_} = c
  Nat.add(Nat.add(x,y),z)

def cells(c: Layout) -> U32:
  U32.shln(1,bits(c))

def pick(c: Bool, a: F32, b: F32) -> F32:
  match c:
    case True{}: a
    case False{}: b

def wrap(+x: F32, +span: F32) -> F32:
  (x - F32.floor((x / span : F32)) * span : F32)

def axis(periodic: Bool, +bits: Nat, size: F32, origin: F32, value: F32) -> U32:
  match periodic:
    case True{}:
      U32.and(F32.to_u32(wrap(((value - origin) / size : F32),U32.to_f32(U32.shln(1,bits)))),
        (U32.shln(1,bits) - 1 : U32))
    case False{}:
      F32.to_u32(F32.max(0.0,F32.min((U32.to_f32(U32.shln(1,bits)) - 1.0 : F32),
        F32.floor(((value - origin) / size : F32)))))

def word(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}: a
    case False{}: b

def cell(c: Layout, p: Point) -> U32:
  Layout{dims,+xb,+yb,zb,+size,ox,oy,oz,+periodic} = c
  Point{x,y,z} = p
  (axis(periodic,xb,size,ox,x) + U32.shln(axis(periodic,yb,size,oy,y),xb)
    + U32.shln(word(U32.is_eq(dims,3),axis(periodic,zb,size,oz,z),0),Nat.add(xb,yb)) : U32)

def displacement(periodic: Bool, +span: F32, +d: F32) -> F32:
  match periodic:
    case False{}: d
    case True{}: (d - F32.floor((d / span + 0.5 : F32)) * span : F32)

def delta_done(+x: F32, +y: F32, +z: F32) -> Delta:
  Delta{x,y,z,(x * x + y * y + z * z : F32)}

def delta(c: Layout, a: Point, b: Point) -> Delta:
  Layout{dims,xb,yb,zb,+size,_,_,_,+periodic} = c
  Point{x,y,z} = a
  Point{nx,ny,nz} = b
  delta_done(displacement(periodic,(U32.to_f32(U32.shln(1,xb)) * size : F32),(nx - x : F32)),
    displacement(periodic,(U32.to_f32(U32.shln(1,yb)) * size : F32),(ny - y : F32)),
    pick(U32.is_eq(dims,3),displacement(periodic,(U32.to_f32(U32.shln(1,zb)) * size : F32),(nz - z : F32)),0.0))
