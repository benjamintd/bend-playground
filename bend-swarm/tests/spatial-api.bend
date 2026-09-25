import Base
import ../engine/spatial.bend as S
import ../engine/spatial/layout.bend as L
import ../engine/spatial/internal/index.bend as I
import ../engine/spatial/internal/stencil.bend as K

type Points is Type:
  Points{x: Array<F32>, y: Array<F32>, z: Array<F32>}

def merge(a: Points, b: Points) -> Points:
  Points{ax,ay,az} = a
  Points{bx,by,bz} = b
  Points{Array.join(F32,ax,bx),Array.join(F32,ay,by),Array.join(F32,az,bz)}

def read_z(x: F32, y: F32, xs: Array<F32>, ys: Array<F32>, r: Array<F32> & F32) -> Points & L.Point:
  (zs,z) = r
  (Points{xs,ys,zs},L.Point{x,y,z})

def read_y(i: U32, x: F32, xs: Array<F32>, zs: Array<F32>, r: Array<F32> & F32) -> Points & L.Point:
  (ys,y) = r
  read_z(x,y,xs,ys,Array.get(F32,zs,i))

def read_x(+i: U32, ys: Array<F32>, zs: Array<F32>, r: Array<F32> & F32) -> Points & L.Point:
  (xs,x) = r
  read_y(i,x,xs,zs,Array.get(F32,ys,i))

def read(+i: U32, p: Points) -> Points & L.Point:
  Points{x,y,z} = p
  read_x(i,y,z,Array.get(F32,x,i))

def point(p: L.Point) -> L.Point:
  p

def begin(i: U32, p: L.Point, c: Unit) -> U32:
  0

def visit(i: U32, self: L.Point, id: U32, neighbor: L.Point, d: L.Delta, c: Unit, mask: U32) -> U32:
  U32.or(mask,U32.shln(1,U32.to_nat(id)))

def finish(i: U32, p: L.Point, c: Unit, mask: U32, a: Array<U32>) -> Array<U32>:
  Array.set(U32,a,i,mask)

def periodic2() -> L.Layout:
  L.Layout{2,2n,2n,0n,1.0,0.0,0.0,0.0,True{}}

def bounded3() -> L.Layout:
  L.Layout{3,2n,2n,2n,1.0,F32.neg(2.0),F32.neg(2.0),F32.neg(2.0),False{}}

def tiny3() -> L.Layout:
  L.Layout{3,1n,0n,1n,1.0,0.0,0.0,0.0,True{}}

def run_built(~space: L.Layout, gpu: Bool, radius: F32, inc: Bool,
  r: Result<String,S.Snapshot(space,Points)>) -> Result<String,S.Step(space,Points,Array<U32>)>:
  match r:
    case Fail{e}: Fail{e}
    case Done{snapshot}:
      S.stencil(~space,~Points,~Array<U32>,~L.Point,~U32,~Unit,~read,~point,~begin,~visit,~finish,
        ~merge,~Array.join(U32),gpu,3n,radius,inc,Unit{},snapshot,Array.new(U32,5n,0))

def run_created(~space: L.Layout, +gpu: Bool, +n: U32, radius: F32, inc: Bool, p: Points,
  r: Result<String,S.Index(space)>) -> Result<String,S.Step(space,Points,Array<U32>)>:
  match r:
    case Fail{e}: Fail{e}
    case Done{g}:
      run_built(~space,gpu,radius,inc,S.build(~space,~Points,~read,~merge,gpu,3n,n,p,g))

def periodic(gpu: Bool, n: U32, radius: F32, inc: Bool, p: Points) -> Result<String,S.Step(periodic2(),Points,Array<U32>)>:
  run_created(~periodic2(),gpu,n,radius,inc,p,S.create(~periodic2(),5n))

def bounded(gpu: Bool, n: U32, radius: F32, inc: Bool, p: Points) -> Result<String,S.Step(bounded3(),Points,Array<U32>)>:
  run_created(~bounded3(),gpu,n,radius,inc,p,S.create(~bounded3(),5n))

def tiny(gpu: Bool, n: U32, radius: F32, inc: Bool, p: Points) -> Result<String,S.Step(tiny3(),Points,Array<U32>)>:
  run_created(~tiny3(),gpu,n,radius,inc,p,S.create(~tiny3(),5n))

def bad_layout() -> Result<String,S.Index(L.Layout{2,2n,2n,1n,1.0,0.0,0.0,0.0,True{}})>:
  S.create(~L.Layout{2,2n,2n,1n,1.0,0.0,0.0,0.0,True{}},5n)

def capacity(depth: Nat) -> Result<String,S.Index(bounded3())>:
  S.create(~bounded3(),depth)
