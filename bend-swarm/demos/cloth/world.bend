import Base
import ../../engine/spatial/layout.bend as L
import ../../engine/parallel/regions.bend as Region

type Positions is Type:
  Positions{x: Array<F32>, y: Array<F32>, z: Array<F32>}

def empty(depth: Nat) -> Positions:
  +d = depth
  Positions{Array.new(F32,d,0.0),Array.new(F32,d,0.0),Array.new(F32,d,0.0)}

def join(a: Positions, b: Positions) -> Positions:
  Positions{ax,ay,az} = a
  Positions{bx,by,bz} = b
  Positions{Array.join(F32,ax,bx),Array.join(F32,ay,by),Array.join(F32,az,bz)}

def read_z(x: F32, y: F32, xs: Array<F32>, ys: Array<F32>, r: Array<F32> & F32) -> Positions & L.Point:
  (zs,z) = r
  (Positions{xs,ys,zs},L.Point{x,y,z})

def read_y(i: U32, x: F32, xs: Array<F32>, zs: Array<F32>, r: Array<F32> & F32) -> Positions & L.Point:
  (ys,y) = r
  read_z(x,y,xs,ys,Array.get(F32,zs,i))

def read_x(+i: U32, ys: Array<F32>, zs: Array<F32>, r: Array<F32> & F32) -> Positions & L.Point:
  (xs,x) = r
  read_y(i,x,xs,zs,Array.get(F32,ys,i))

def read(+i: U32, p: Positions) -> Positions & L.Point:
  Positions{x,y,z} = p
  read_x(i,y,z,Array.get(F32,x,i))

def write(+i: U32, p: Positions, value: L.Point) -> Positions:
  Positions{x,y,z} = p
  L.Point{px,py,pz} = value
  Positions{Array.set(F32,x,i,px),Array.set(F32,y,i,py),Array.set(F32,z,i,pz)}

def rest(+side: U32, +i: U32) -> L.Point:
  +spacing = (3.6 / U32.to_f32((side - 1 : U32)) : F32)
  L.Point{(U32.to_f32((i % side : U32)) * spacing - 1.8 : F32),1.55,
    (U32.to_f32((i / side : U32)) * spacing - 1.8 : F32)}

def fill(n: Nat, +i: U32, +side: U32, p: Positions) -> Positions:
  match n:
    case 0n: p
    case 1n+k: fill(k,(i + 1 : U32),side,write(i,p,rest(side,i)))

# Small startup allocation; every simulation step reuses these arrays.
def create(+side_bits: Nat) -> Positions:
  fill(U32.to_nat(U32.shln(1,Nat.add(side_bits,side_bits))),0,U32.shln(1,side_bits),empty(Nat.add(side_bits,side_bits)))
