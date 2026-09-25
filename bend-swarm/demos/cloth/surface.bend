import Base
import ./world.bend as W
import ./physics.bend as P
import ./contact.bend as G
import ../../engine/core/vec3.bend as V
import ../../engine/spatial.bend as Spatial
import ../../engine/spatial/layout.bend as L
import ../../engine/parallel/regions.bend as Region

# One reusable flat sample per vertex, shared read-only during the stencil.
# The six incident mesh edges and two outgoing faces cover the whole surface.
type Sample is Data:
  Sample{p: L.Point, r: L.Point, d: L.Point, q: L.Point, l: L.Point, u: L.Point, v: L.Point, op: L.Point, or: L.Point, od: L.Point, oq: L.Point, ol: L.Point, ou: L.Point, ov: L.Point}
type Source is Type:
  Source{current: W.Positions, previous: W.Positions, samples: Array<Sample>, side: U32}

def blank() -> Sample:
  Sample{V.zero(),V.zero(),V.zero(),V.zero(),V.zero(),V.zero(),V.zero(),V.zero(),V.zero(),V.zero(),V.zero(),V.zero(),V.zero(),V.zero()}
def join(a: Source, b: Source) -> Source:
  Source{ac,ap,as,side} = a
  Source{bc,bp,bs,_} = b
  Source{W.join(ac,bc),W.join(ap,bp),Array.join(Sample,as,bs),side}

def neighbor(k: U32, +i: U32, +side: U32) -> U32:
  match k:
    case 0: i
    case 1: L.word((i % side < side - 1 : U32),(i + 1 : U32),i)
    case 2: L.word((i < side * (side - 1) : U32),(i + side : U32),i)
    case 3: L.word((i % side < side - 1 : U32) && (i < side * (side - 1) : U32),(i + side + 1 : U32),i)
    case 4: L.word((i % side > 0 : U32),(i - 1 : U32),i)
    case 5: L.word((i >= side : U32),(i - side : U32),i)
    case _: L.word((i % side > 0 : U32) && (i >= side : U32),(i - side - 1 : U32),i)

def loaded_13(+i: U32, +side: U32, other: W.Positions, samples: Array<Sample>, p: L.Point, r: L.Point, d: L.Point, q: L.Point, l: L.Point, u: L.Point, v: L.Point, op: L.Point, or: L.Point, od: L.Point, oq: L.Point, ol: L.Point, ou: L.Point, value: W.Positions & L.Point) -> Source:
  (positions,ov) = value
  Source{other,positions,Array.set(Sample,samples,i,Sample{p,r,d,q,l,u,v,op,or,od,oq,ol,ou,ov}),side}

def loaded_12(+i: U32, +side: U32, other: W.Positions, samples: Array<Sample>, p: L.Point, r: L.Point, d: L.Point, q: L.Point, l: L.Point, u: L.Point, v: L.Point, op: L.Point, or: L.Point, od: L.Point, oq: L.Point, ol: L.Point, value: W.Positions & L.Point) -> Source:
  (positions,ou) = value
  loaded_13(i,side,other,samples,p,r,d,q,l,u,v,op,or,od,oq,ol,ou,W.read(neighbor(6,i,side),positions))

def loaded_11(+i: U32, +side: U32, other: W.Positions, samples: Array<Sample>, p: L.Point, r: L.Point, d: L.Point, q: L.Point, l: L.Point, u: L.Point, v: L.Point, op: L.Point, or: L.Point, od: L.Point, oq: L.Point, value: W.Positions & L.Point) -> Source:
  (positions,ol) = value
  loaded_12(i,side,other,samples,p,r,d,q,l,u,v,op,or,od,oq,ol,W.read(neighbor(5,i,side),positions))

def loaded_10(+i: U32, +side: U32, other: W.Positions, samples: Array<Sample>, p: L.Point, r: L.Point, d: L.Point, q: L.Point, l: L.Point, u: L.Point, v: L.Point, op: L.Point, or: L.Point, od: L.Point, value: W.Positions & L.Point) -> Source:
  (positions,oq) = value
  loaded_11(i,side,other,samples,p,r,d,q,l,u,v,op,or,od,oq,W.read(neighbor(4,i,side),positions))

def loaded_9(+i: U32, +side: U32, other: W.Positions, samples: Array<Sample>, p: L.Point, r: L.Point, d: L.Point, q: L.Point, l: L.Point, u: L.Point, v: L.Point, op: L.Point, or: L.Point, value: W.Positions & L.Point) -> Source:
  (positions,od) = value
  loaded_10(i,side,other,samples,p,r,d,q,l,u,v,op,or,od,W.read(neighbor(3,i,side),positions))

def loaded_8(+i: U32, +side: U32, other: W.Positions, samples: Array<Sample>, p: L.Point, r: L.Point, d: L.Point, q: L.Point, l: L.Point, u: L.Point, v: L.Point, op: L.Point, value: W.Positions & L.Point) -> Source:
  (positions,or) = value
  loaded_9(i,side,other,samples,p,r,d,q,l,u,v,op,or,W.read(neighbor(2,i,side),positions))

def loaded_7(+i: U32, +side: U32, other: W.Positions, samples: Array<Sample>, p: L.Point, r: L.Point, d: L.Point, q: L.Point, l: L.Point, u: L.Point, v: L.Point, value: W.Positions & L.Point) -> Source:
  (positions,op) = value
  loaded_8(i,side,other,samples,p,r,d,q,l,u,v,op,W.read(neighbor(1,i,side),positions))

def loaded_6(+i: U32, +side: U32, other: W.Positions, samples: Array<Sample>, p: L.Point, r: L.Point, d: L.Point, q: L.Point, l: L.Point, u: L.Point, value: W.Positions & L.Point) -> Source:
  (positions,v) = value
  loaded_7(i,side,positions,samples,p,r,d,q,l,u,v,W.read(neighbor(0,i,side),other))

def loaded_5(+i: U32, +side: U32, other: W.Positions, samples: Array<Sample>, p: L.Point, r: L.Point, d: L.Point, q: L.Point, l: L.Point, value: W.Positions & L.Point) -> Source:
  (positions,u) = value
  loaded_6(i,side,other,samples,p,r,d,q,l,u,W.read(neighbor(6,i,side),positions))

def loaded_4(+i: U32, +side: U32, other: W.Positions, samples: Array<Sample>, p: L.Point, r: L.Point, d: L.Point, q: L.Point, value: W.Positions & L.Point) -> Source:
  (positions,l) = value
  loaded_5(i,side,other,samples,p,r,d,q,l,W.read(neighbor(5,i,side),positions))

def loaded_3(+i: U32, +side: U32, other: W.Positions, samples: Array<Sample>, p: L.Point, r: L.Point, d: L.Point, value: W.Positions & L.Point) -> Source:
  (positions,q) = value
  loaded_4(i,side,other,samples,p,r,d,q,W.read(neighbor(4,i,side),positions))

def loaded_2(+i: U32, +side: U32, other: W.Positions, samples: Array<Sample>, p: L.Point, r: L.Point, value: W.Positions & L.Point) -> Source:
  (positions,d) = value
  loaded_3(i,side,other,samples,p,r,d,W.read(neighbor(3,i,side),positions))

def loaded_1(+i: U32, +side: U32, other: W.Positions, samples: Array<Sample>, p: L.Point, value: W.Positions & L.Point) -> Source:
  (positions,r) = value
  loaded_2(i,side,other,samples,p,r,W.read(neighbor(2,i,side),positions))

def loaded_0(+i: U32, +side: U32, other: W.Positions, samples: Array<Sample>, value: W.Positions & L.Point) -> Source:
  (positions,p) = value
  loaded_1(i,side,other,samples,p,W.read(neighbor(1,i,side),positions))

def cache_loop(n: Nat, +i: U32, s: Source) -> Source:
  match n:
    case 0n: s
    case 1n+k:
      Source{now,old,samples,+side} = s
      cache_loop(k,(i + 1 : U32),loaded_0(i,side,old,samples,W.read(i,now)))
def cache_leaf(i: U32, n: U32, s: Source) -> Source:
  cache_loop(U32.to_nat(n),i,s)
def cache(depth: Nat, +n: U32, s: Source) -> Source:
  Region.run(~Source,~cache_leaf,~join,Nat.min(depth,U32.log2(U32.max(n,1))),0,n,s)
def cache_run(gpu: Bool, depth: Nat, n: U32, s: Source) -> Source:
  match gpu:
    case True{}: cache!(depth,n,s)
    case False{}: cache(depth,n,s)
def sampled(now: W.Positions, old: W.Positions, side: U32, r: Array<Sample> & Sample) -> Source & Sample:
  (samples,p) = r
  (Source{now,old,samples,side},p)
def read(+i: U32, s: Source) -> Source & Sample:
  Source{now,old,samples,side} = s
  sampled(now,old,side,Array.get(Sample,samples,i))
def point(s: Sample) -> L.Point:
  Sample{p,_,_,_,_,_,_,_,_,_,_,_,_,_} = s
  p
def positioned(old: W.Positions, samples: Array<Sample>, side: U32, r: W.Positions & L.Point) -> Source & L.Point:
  (now,p) = r
  (Source{now,old,samples,side},p)
def position(+i: U32, s: Source) -> Source & L.Point:
  Source{now,old,samples,side} = s
  positioned(old,samples,side,W.read(i,now))
def begin(i: U32, s: Sample, c: P.Controls) -> G.Push:
  G.none()

def edges_near(near: Bool, +a: L.Point, +b: L.Point, +oa: L.Point, +ob: L.Point,
  +p: L.Point, +r: L.Point, +d: L.Point, +q: L.Point, +op: L.Point, +or: L.Point, +od: L.Point, +oq: L.Point) -> G.Push:
  match near:
    case False{}: G.none()
    case True{}: G.sum(G.edge(a,b,p,r,oa,ob,op,or),G.sum(G.edge(a,b,p,d,oa,ob,op,od),G.edge(a,b,p,q,oa,ob,op,oq)))

def edges(+a: L.Point, +b: L.Point, oa: L.Point, ob: L.Point,
  lo: L.Point, hi: L.Point, p: L.Point, r: L.Point, d: L.Point, q: L.Point,
  op: L.Point, or: L.Point, od: L.Point, oq: L.Point) -> G.Push:
  edges_near(G.overlap(a,b,lo,hi),a,b,oa,ob,p,r,d,q,op,or,od,oq)

def visit_far(far: Bool, self: Sample, other: Sample, acc: G.Push) -> G.Push:
  match far:
    case False{}: acc
    case True{}:
      Sample{+a,r,d,q,l,u,v,+oa,or,od,oq,ol,ou,ov} = self
      Sample{+b,+br,+bd,+bq,_,_,_,+ob,+obr,+obd,+obq,_,_,_} = other
      +lo = V.minimum(V.minimum(b,br),V.minimum(bd,bq))
      +hi = V.maximum(V.maximum(b,br),V.maximum(bd,bq))
      G.sum(acc,G.sum(G.face(a,oa,b,br,bq,ob,obr,obq),G.sum(G.face(a,oa,b,bq,bd,ob,obq,obd),
        G.sum(edges(a,r,oa,or,lo,hi,b,br,bd,bq,ob,obr,obd,obq),G.sum(edges(a,d,oa,od,lo,hi,b,br,bd,bq,ob,obr,obd,obq),G.sum(edges(a,q,oa,oq,lo,hi,b,br,bd,bq,ob,obr,obd,obq),G.sum(edges(a,l,oa,ol,lo,hi,b,br,bd,bq,ob,obr,obd,obq),G.sum(edges(a,u,oa,ou,lo,hi,b,br,bd,bq,ob,obr,obd,obq),edges(a,v,oa,ov,lo,hi,b,br,bd,bq,ob,obr,obd,obq)))))))))

def visit(i: U32, self: Sample, j: U32, other: Sample, delta: L.Delta, c: P.Controls, acc: G.Push) -> G.Push:
  P.Controls{+side,_,_,_,_,_,_} = c
  +si = i
  +sj = j
  visit_far((P.diff((si % side : U32),(sj % side : U32)) > 1 : U32)
    || (P.diff((si / side : U32),(sj / side : U32)) > 1 : U32),self,other,acc)
def finish(i: U32, self: Sample, c: P.Controls, acc: G.Push, out: W.Positions) -> W.Positions:
  P.Controls{+side,_,_,_,_,_,_} = c
  +id = i
  W.write(id,out,P.pick(P.pinned(side,id),W.rest(side,id),P.contact(G.result(point(self),acc))))
def collide(gpu: Bool, depth: Nat, +c: P.Controls, s: Spatial.Snapshot(P.space(),Source), out: W.Positions)
  -> Result<String,Spatial.Step(P.space(),Source,W.Positions)>:
  P.Controls{side,_,_,_,_,_,_} = c
  Spatial.stencil(~P.space(),~Source,~W.Positions,~Sample,~G.Push,~P.Controls,
    ~read,~point,~begin,~visit,~finish,~join,~W.join,
    gpu,depth,(3.6 / U32.to_f32((side - 1 : U32)) * 2.8 + 0.08 : F32),False{},c,s,out)
