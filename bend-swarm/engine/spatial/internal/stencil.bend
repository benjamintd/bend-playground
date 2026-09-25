import Base
import ../layout.bend as L
import ./index.bend as I
import ../../parallel/regions.bend as Region

# Every axis is visited at most once, including periodic spaces smaller than
# the query diameter. Large radii are exact, not a capped 3x3x3 approximation.
type Box is Data:
  Box{x: U32, y: U32, z: U32, nx: U32, ny: U32, nz: U32}

def axis_range(periodic: Bool, +cell: U32, +cells: U32, +reach: U32) -> U32 & U32:
  match periodic:
    case True{}:
      (U32.and((cell + cells - reach % cells : U32),(cells - 1 : U32)),U32.min(cells,(2 * reach + 1 : U32)))
    case False{}:
      +start = (cell - U32.min(cell,reach) : U32)
      (start,(U32.min((cells - 1 : U32),(cell + reach : U32)) - start + 1 : U32))

def ranges(rx: U32 & U32, ry: U32 & U32, rz: U32 & U32) -> Box:
  (x,nx) = rx
  (y,ny) = ry
  (z,nz) = rz
  Box{x,y,z,nx,ny,nz}

def bounds(c: L.Layout, radius: F32, p: L.Point) -> Box:
  L.Layout{dims,+xb,+yb,+zb,+size,ox,oy,oz,+periodic} = c
  L.Point{x,y,z} = p
  +reach = F32.to_u32(F32.min(F32.ceil((radius / size : F32)),
    U32.to_f32(U32.shln(1,Nat.add(Nat.add(xb,yb),zb)))))
  ranges(axis_range(periodic,L.axis(periodic,xb,size,ox,x),U32.shln(1,xb),reach),
    axis_range(periodic,L.axis(periodic,yb,size,oy,y),U32.shln(1,yb),reach),
    axis_range(periodic,L.axis(periodic,zb,size,oz,z),U32.shln(1,zb),L.word(U32.is_eq(dims,3),reach,0)))

def box_size(b: Box) -> U32:
  Box{_,_,_,nx,ny,nz} = b
  (nx * ny * nz : U32)

def box_cell(c: L.Layout, b: Box, +k: U32) -> U32:
  L.Layout{_,+xb,+yb,zb,_,_,_,_,_} = c
  Box{x,y,z,+nx,+ny,_} = b
  (U32.and((x + k % nx : U32),(U32.shln(1,xb) - 1 : U32))
    + U32.shln(U32.and((y + k / nx % ny : U32),(U32.shln(1,yb) - 1 : U32)),xb)
    + U32.shln(U32.and((z + k / (nx * ny) : U32),(U32.shln(1,zb) - 1 : U32)),Nat.add(xb,yb)) : U32)

type Query<-S: Type, -T: Data, -A: Data, -C: Data> is Type:
  Query{source: S, offsets: Array<U32>, ids: Array<U32>, self_id: U32,
    self: T, context: C, acc: A, radius2: F32, include_self: Bool, checks: Nat, neighbors: Nat}

type Work<-S: Type, -O: Type, -C: Data> is Type:
  Work{source: S, output: O, offsets: Array<U32>, ids: Array<U32>, context: C,
    radius: F32, include_self: Bool, checks: Nat, neighbors: Nat}

type Step<-space: L.Layout, -S: Type, -O: Type> is Type:
  Step{snapshot: I.Snapshot<space,S>, output: O, checks: Nat, neighbors: Nat}

def considered(~S: Type, ~T: Data, ~A: Data, ~C: Data,
  ~visit: U32 -> T -> U32 -> T -> L.Delta -> C -> A -> A,
  yes: Bool, id: U32, other: T, delta: L.Delta, q: Query<S,T,A,C>) -> Query<S,T,A,C>:
  match yes:
    case False{}:
      Query{s,o,ids,i,self,ctx,acc,r2,inc,k,n} = q
      Query{s,o,ids,i,self,ctx,acc,r2,inc,1n+k,n}
    case True{}:
      Query{s,o,ids,+i,+self,+ctx,acc,r2,inc,k,n} = q
      Query{s,o,ids,i,self,ctx,visit(i,self,id,other,delta,ctx,acc),r2,inc,1n+k,1n+n}

def candidate_delta(~S: Type, ~T: Data, ~A: Data, ~C: Data,
  ~visit: U32 -> T -> U32 -> T -> L.Delta -> C -> A -> A,
  +id: U32, other: T, +d: L.Delta, q: Query<S,T,A,C>) -> Query<S,T,A,C>:
  L.Delta{_,_,_,d2} = d
  Query{s,o,ids,+i,self,ctx,acc,+r2,+inc,k,n} = q
  considered(~S,~T,~A,~C,~visit,(d2 < r2 : F32) && (inc || U32.is_ne(i,id)),id,other,d,
    Query{s,o,ids,i,self,ctx,acc,r2,inc,k,n})

def candidate_value(~space: L.Layout, ~S: Type, ~T: Data, ~A: Data, ~C: Data,
  ~read: @+i:U32 -> S -> S & T, ~point: T -> L.Point,
  ~visit: U32 -> T -> U32 -> T -> L.Delta -> C -> A -> A,
  id: U32, offsets: Array<U32>, ids: Array<U32>, i: U32, +self: T, ctx: C, acc: A,
  radius2: F32, inc: Bool, k: Nat, n: Nat, r: S & T) -> Query<S,T,A,C>:
  (s,+other) = r
  candidate_delta(~S,~T,~A,~C,~visit,id,other,L.delta(space,point(self),point(other)),
    Query{s,offsets,ids,i,self,ctx,acc,radius2,inc,k,n})

def candidate_id(~space: L.Layout, ~S: Type, ~T: Data, ~A: Data, ~C: Data,
  ~read: @+i:U32 -> S -> S & T, ~point: T -> L.Point,
  ~visit: U32 -> T -> U32 -> T -> L.Delta -> C -> A -> A,
  s: S, offsets: Array<U32>, i: U32, self: T, ctx: C, acc: A, radius2: F32, inc: Bool,
  k: Nat, n: Nat, r: Array<U32> & U32) -> Query<S,T,A,C>:
  (ids,+id) = r
  candidate_value(~space,~S,~T,~A,~C,~read,~point,~visit,id,offsets,ids,i,self,ctx,acc,radius2,inc,k,n,read(id,s))

def candidate(~space: L.Layout, ~S: Type, ~T: Data, ~A: Data, ~C: Data,
  ~read: @+i:U32 -> S -> S & T, ~point: T -> L.Point,
  ~visit: U32 -> T -> U32 -> T -> L.Delta -> C -> A -> A, slot: U32, q: Query<S,T,A,C>) -> Query<S,T,A,C>:
  Query{s,o,ids,i,self,ctx,acc,r2,inc,k,n} = q
  candidate_id(~space,~S,~T,~A,~C,~read,~point,~visit,s,o,i,self,ctx,acc,r2,inc,k,n,Array.get(U32,ids,slot))

def candidates(~space: L.Layout, ~S: Type, ~T: Data, ~A: Data, ~C: Data,
  ~read: @+i:U32 -> S -> S & T, ~point: T -> L.Point,
  ~visit: U32 -> T -> U32 -> T -> L.Delta -> C -> A -> A, n: Nat, +slot: U32, q: Query<S,T,A,C>) -> Query<S,T,A,C>:
  match n:
    case 0n: q
    case 1n+p: candidates(~space,~S,~T,~A,~C,~read,~point,~visit,p,(slot + 1 : U32),candidate(~space,~S,~T,~A,~C,~read,~point,~visit,slot,q))

def cell_end(~space: L.Layout, ~S: Type, ~T: Data, ~A: Data, ~C: Data,
  ~read: @+i:U32 -> S -> S & T, ~point: T -> L.Point,
  ~visit: U32 -> T -> U32 -> T -> L.Delta -> C -> A -> A, +start: U32, s: S, ids: Array<U32>, i: U32, self: T,
  ctx: C, acc: A, r2: F32, inc: Bool, k: Nat, n: Nat, r: Array<U32> & U32) -> Query<S,T,A,C>:
  (o,end) = r
  candidates(~space,~S,~T,~A,~C,~read,~point,~visit,U32.to_nat((end - start : U32)),start,Query{s,o,ids,i,self,ctx,acc,r2,inc,k,n})

def cell_start(~space: L.Layout, ~S: Type, ~T: Data, ~A: Data, ~C: Data,
  ~read: @+i:U32 -> S -> S & T, ~point: T -> L.Point,
  ~visit: U32 -> T -> U32 -> T -> L.Delta -> C -> A -> A, cell: U32, s: S, ids: Array<U32>, i: U32, self: T,
  ctx: C, acc: A, r2: F32, inc: Bool, k: Nat, n: Nat, r: Array<U32> & U32) -> Query<S,T,A,C>:
  (o,start) = r
  cell_end(~space,~S,~T,~A,~C,~read,~point,~visit,start,s,ids,i,self,ctx,acc,r2,inc,k,n,Array.get(U32,o,(cell + 1 : U32)))

def cell(~space: L.Layout, ~S: Type, ~T: Data, ~A: Data, ~C: Data,
  ~read: @+i:U32 -> S -> S & T, ~point: T -> L.Point,
  ~visit: U32 -> T -> U32 -> T -> L.Delta -> C -> A -> A, +cell: U32, q: Query<S,T,A,C>) -> Query<S,T,A,C>:
  Query{s,o,ids,i,self,ctx,acc,r2,inc,k,n} = q
  cell_start(~space,~S,~T,~A,~C,~read,~point,~visit,cell,s,ids,i,self,ctx,acc,r2,inc,k,n,Array.get(U32,o,cell))

def neighborhood(~space: L.Layout, ~S: Type, ~T: Data, ~A: Data, ~C: Data,
  ~read: @+i:U32 -> S -> S & T, ~point: T -> L.Point,
  ~visit: U32 -> T -> U32 -> T -> L.Delta -> C -> A -> A, +n: Nat, +box: Box, q: Query<S,T,A,C>) -> Query<S,T,A,C>:
  match n:
    case 0n: q
    case 1n+p:
      neighborhood(~space,~S,~T,~A,~C,~read,~point,~visit,p,box,cell(~space,~S,~T,~A,~C,~read,~point,~visit,box_cell(space,box,U32.from_nat(p)),q))

def search(~space: L.Layout, ~S: Type, ~T: Data, ~A: Data, ~C: Data,
  ~read: @+i:U32 -> S -> S & T, ~point: T -> L.Point,
  ~visit: U32 -> T -> U32 -> T -> L.Delta -> C -> A -> A, +box: Box, q: Query<S,T,A,C>) -> Query<S,T,A,C>:
  neighborhood(~space,~S,~T,~A,~C,~read,~point,~visit,U32.to_nat(box_size(box)),box,q)

def finished(~S: Type, ~O: Type, ~T: Data, ~A: Data, ~C: Data,
  ~finish: U32 -> T -> C -> A -> O -> O,
  output: O, radius: F32, previous_checks: Nat, previous_neighbors: Nat,
  q: Query<S,T,A,C>) -> Work<S,O,C>:
  Query{s,o,ids,i,self,+ctx,acc,_,inc,k,n} = q
  Work{s,finish(i,self,ctx,acc,output),o,ids,ctx,radius,inc,Nat.add(previous_checks,k),Nat.add(previous_neighbors,n)}

def self_read(~space: L.Layout, ~S: Type, ~O: Type, ~T: Data, ~A: Data, ~C: Data,
  ~read: @+i:U32 -> S -> S & T, ~point: T -> L.Point,
  ~begin: U32 -> T -> C -> A, ~visit: U32 -> T -> U32 -> T -> L.Delta -> C -> A -> A,
  ~finish: U32 -> T -> C -> A -> O -> O, +i: U32, out: O, offsets: Array<U32>, ids: Array<U32>,
  +ctx: C, +radius: F32, inc: Bool, k: Nat, n: Nat, r: S & T) -> Work<S,O,C>:
  (s,+self) = r
  finished(~S,~O,~T,~A,~C,~finish,out,radius,k,n,
    search(~space,~S,~T,~A,~C,~read,~point,~visit,bounds(space,radius,point(self)),
      Query{s,offsets,ids,i,self,ctx,begin(i,self,ctx),(radius * radius : F32),inc,0n,0n}))

def one(~space: L.Layout, ~S: Type, ~O: Type, ~T: Data, ~A: Data, ~C: Data,
  ~read: @+i:U32 -> S -> S & T, ~point: T -> L.Point,
  ~begin: U32 -> T -> C -> A, ~visit: U32 -> T -> U32 -> T -> L.Delta -> C -> A -> A,
  ~finish: U32 -> T -> C -> A -> O -> O, +i: U32, w: Work<S,O,C>) -> Work<S,O,C>:
  Work{s,out,o,ids,ctx,radius,inc,k,n} = w
  self_read(~space,~S,~O,~T,~A,~C,~read,~point,~begin,~visit,~finish,i,out,o,ids,ctx,radius,inc,k,n,read(i,s))

def loop(~space: L.Layout, ~S: Type, ~O: Type, ~T: Data, ~A: Data, ~C: Data,
  ~read: @+i:U32 -> S -> S & T, ~point: T -> L.Point,
  ~begin: U32 -> T -> C -> A, ~visit: U32 -> T -> U32 -> T -> L.Delta -> C -> A -> A,
  ~finish: U32 -> T -> C -> A -> O -> O, n: Nat, +i: U32, w: Work<S,O,C>) -> Work<S,O,C>:
  match n:
    case 0n: w
    case 1n+p: loop(~space,~S,~O,~T,~A,~C,~read,~point,~begin,~visit,~finish,p,(i + 1 : U32),one(~space,~S,~O,~T,~A,~C,~read,~point,~begin,~visit,~finish,i,w))

def leaf(~space: L.Layout, ~S: Type, ~O: Type, ~T: Data, ~A: Data, ~C: Data,
  ~read: @+i:U32 -> S -> S & T, ~point: T -> L.Point,
  ~begin: U32 -> T -> C -> A, ~visit: U32 -> T -> U32 -> T -> L.Delta -> C -> A -> A,
  ~finish: U32 -> T -> C -> A -> O -> O, start: U32, n: U32, w: Work<S,O,C>) -> Work<S,O,C>:
  Work{s,out,o,ids,ctx,radius,inc,_,_} = w
  loop(~space,~S,~O,~T,~A,~C,~read,~point,~begin,~visit,~finish,U32.to_nat(n),start,Work{s,out,o,ids,ctx,radius,inc,0n,0n})

def merge(~S: Type, ~O: Type, ~C: Data, ~join_source: S -> S -> S, ~join_output: O -> O -> O,
  a: Work<S,O,C>, b: Work<S,O,C>) -> Work<S,O,C>:
  Work{as,ao,ar,ai,ctx,radius,inc,ak,an} = a
  Work{bs,bo,br,bi,_,_,_,bk,bn} = b
  Work{join_source(as,bs),join_output(ao,bo),Array.join(U32,ar,br),Array.join(U32,ai,bi),
    ctx,radius,inc,Nat.add(ak,bk),Nat.add(an,bn)}

def root(~space: L.Layout, ~S: Type, ~O: Type, ~T: Data, ~A: Data, ~C: Data,
  ~read: @+i:U32 -> S -> S & T, ~point: T -> L.Point,
  ~begin: U32 -> T -> C -> A, ~visit: U32 -> T -> U32 -> T -> L.Delta -> C -> A -> A,
  ~finish: U32 -> T -> C -> A -> O -> O,
  ~join_source: S -> S -> S, ~join_output: O -> O -> O, depth: Nat, +n: U32, w: Work<S,O,C>) -> Work<S,O,C>:
  Region.run(~Work<S,O,C>,~leaf(~space,~S,~O,~T,~A,~C,~read,~point,~begin,~visit,~finish),~merge(~S,~O,~C,~join_source,~join_output),
    Nat.min(depth,U32.log2(U32.max(n,1))),0,n,w)

def execute(~space: L.Layout, ~S: Type, ~O: Type, ~T: Data, ~A: Data, ~C: Data,
  ~read: @+i:U32 -> S -> S & T, ~point: T -> L.Point,
  ~begin: U32 -> T -> C -> A, ~visit: U32 -> T -> U32 -> T -> L.Delta -> C -> A -> A,
  ~finish: U32 -> T -> C -> A -> O -> O,
  ~join_source: S -> S -> S, ~join_output: O -> O -> O, gpu: Bool, depth: Nat, n: U32, w: Work<S,O,C>) -> Work<S,O,C>:
  match gpu:
    case True{}: root!(~space,~S,~O,~T,~A,~C,~read,~point,~begin,~visit,~finish,~join_source,~join_output,depth,n,w)
    case False{}: root(~space,~S,~O,~T,~A,~C,~read,~point,~begin,~visit,~finish,~join_source,~join_output,depth,n,w)

def completed(~space: L.Layout, ~S: Type, ~O: Type, ~C: Data,
  count: U32, capacity: U32, counts: Array<U32>, cursors: Array<U32>, w: Work<S,O,C>) -> Step<space,S,O>:
  Work{s,out,offsets,ids,_,_,_,checks,neighbors} = w
  Step{I.Snapshot{count,s,I.Index{capacity,counts,offsets,cursors,ids}},out,checks,neighbors}

def stencil_if(~space: L.Layout, ~S: Type, ~O: Type, ~T: Data, ~A: Data, ~C: Data,
  ~read: @+i:U32 -> S -> S & T, ~point: T -> L.Point,
  ~begin: U32 -> T -> C -> A, ~visit: U32 -> T -> U32 -> T -> L.Delta -> C -> A -> A,
  ~finish: U32 -> T -> C -> A -> O -> O,
  ~join_source: S -> S -> S, ~join_output: O -> O -> O, good: Bool, gpu: Bool, depth: Nat, radius: F32, include_self: Bool,
  ctx: C, source: I.Snapshot<space,S>, output: O) -> Result<String,Step<space,S,O>>:
  match good:
    case False{}: Fail{"Spatial.stencil: radius must be finite and nonnegative"}
    case True{}:
      I.Snapshot{+n,s,I.Index{cap,counts,offsets,cursors,ids}} = source
      Done{completed(~space,~S,~O,~C,n,cap,counts,cursors,
        execute(~space,~S,~O,~T,~A,~C,~read,~point,~begin,~visit,~finish,~join_source,~join_output,gpu,depth,n,Work{s,output,offsets,ids,ctx,radius,include_self,0n,0n}))}

def stencil(~space: L.Layout, ~S: Type, ~O: Type, ~T: Data, ~A: Data, ~C: Data,
  ~read: @+i:U32 -> S -> S & T, ~point: T -> L.Point,
  ~begin: U32 -> T -> C -> A, ~visit: U32 -> T -> U32 -> T -> L.Delta -> C -> A -> A,
  ~finish: U32 -> T -> C -> A -> O -> O,
  ~join_source: S -> S -> S, ~join_output: O -> O -> O, gpu: Bool, depth: Nat, +radius: F32, include_self: Bool,
  ctx: C, source: I.Snapshot<space,S>, output: O) -> Result<String,Step<space,S,O>>:
  stencil_if(~space,~S,~O,~T,~A,~C,~read,~point,~begin,~visit,~finish,~join_source,~join_output,L.finite(radius) && (radius >= 0.0 : F32),gpu,depth,radius,include_self,ctx,source,output)
