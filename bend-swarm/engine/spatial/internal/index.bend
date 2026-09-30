import Base
import ../layout.bend as L
import ../../parallel/regions.bend as Region

# The layout is part of the type; a grid cannot be queried with another layout.
type Index<-space: L.Layout> is Type:
  Index{capacity: U32, counts: Array<U32>, offsets: Array<U32>, cursors: Array<U32>, ids: Array<U32>}

type Snapshot<-space: L.Layout, -S: Type> is Type:
  Snapshot{count: U32, source: S, index: Index<space>}

def allocate(~space: L.Layout, +depth: Nat) -> Index<space>:
  +bits = L.bits(space)
  Index{U32.shln(1,depth),Array.new(U32,bits,0),Array.new(U32,1n+bits,0),
    Array.new(U32,bits,0),Array.new(U32,depth,0)}

def create_if(~space: L.Layout, good: Bool, depth: Nat) -> Result<String,Index<space>>:
  match good:
    case False{}: Fail{"Spatial.create: invalid layout or capacity depth (maximum 20)"}
    case True{}: Done{allocate(~space,depth)}

def create(~space: L.Layout, +depth: Nat) -> Result<String,Index<space>>:
  create_if(~space,L.valid(space) && Nat.is_le(depth,20n),depth)

type Build<-S: Type> is Type:
  Build{source: S, counts: Array<U32>, ids: Array<U32>}

def merge(~S: Type, ~join: S -> S -> S, a: Build<S>, b: Build<S>) -> Build<S>:
  Build{as,ac,ai} = a
  Build{bs,bc,bi} = b
  Build{join(as,bs),Array.join(U32,ac,bc),Array.join(U32,ai,bi)}

def counted(~S: Type, s: S, ids: Array<U32>, r: Array<U32> & U32) -> Build<S>:
  (counts,_) = r
  Build{s,counts,ids}

def histogram_point(~space: L.Layout, ~S: Type, i: U32, counts: Array<U32>, ids: Array<U32>, r: S & L.Point) -> Build<S>:
  (s,p) = r
  counted(~S,s,ids,Array.atomic.add(counts,L.cell(space,p),1))

# Both stages visit the same active intervals. The closed operation keeps one
# position read and one atomic increment per ID, without a runtime callback.
def visit_loop(~S: Type, ~position: @+i:U32 -> S -> S & L.Point,
  ~point: U32 -> Array<U32> -> Array<U32> -> S & L.Point -> Build<S>,
  n: Nat, +i: U32, b: Build<S>) -> Build<S>:
  match n:
    case 0n: b
    case 1n+p:
      Build{s,counts,ids} = b
      visit_loop(~S,~position,~point,p,(i + 1 : U32),point(i,counts,ids,position(i,s)))

def visit_leaf(~S: Type, ~position: @+i:U32 -> S -> S & L.Point,
  ~point: U32 -> Array<U32> -> Array<U32> -> S & L.Point -> Build<S>,
  start: U32, n: U32, b: Build<S>) -> Build<S>:
  visit_loop(~S,~position,~point,U32.to_nat(n),start,b)

def visit(~S: Type, ~position: @+i:U32 -> S -> S & L.Point,
  ~point: U32 -> Array<U32> -> Array<U32> -> S & L.Point -> Build<S>,
  ~join: S -> S -> S, depth: Nat, +n: U32, b: Build<S>) -> Build<S>:
  Region.run(~Build<S>,~visit_leaf(~S,~position,~point),~merge(~S,~join),
    Nat.min(depth,U32.log2(U32.max(n,1))),0,n,b)

def histogram_run(~space: L.Layout, ~S: Type, ~position: @+i:U32 -> S -> S & L.Point,
  ~join: S -> S -> S, gpu: Bool, depth: Nat, n: U32, b: Build<S>) -> Build<S>:
  match gpu:
    case True{}: visit!(~S,~position,~histogram_point(~space,~S),~join,depth,n,b)
    case False{}: visit(~S,~position,~histogram_point(~space,~S),~join,depth,n,b)

type Scan is Type:
  Scan{counts: Array<U32>, offsets: Array<U32>, cursors: Array<U32>, total: U32}

def scan_put(+i: U32, +sum: U32, offsets: Array<U32>, cursors: Array<U32>, r: Array<U32> & U32) -> Scan:
  (counts,n) = r
  Scan{Array.set(U32,counts,i,0),Array.set(U32,offsets,i,sum),Array.set(U32,cursors,i,sum),(sum + n : U32)}

def scan_loop(n: Nat, +i: U32, s: Scan) -> Scan:
  match n:
    case 0n:
      Scan{counts,offsets,cursors,+sum} = s
      Scan{counts,Array.set(U32,offsets,i,sum),cursors,sum}
    case 1n+p:
      Scan{counts,offsets,cursors,sum} = s
      scan_loop(p,(i + 1 : U32),scan_put(i,sum,offsets,cursors,Array.get(U32,counts,i)))

def scanned(~space: L.Layout, cap: U32, ids: Array<U32>, s: Scan) -> Index<space>:
  Scan{counts,offsets,cursors,_} = s
  Index{cap,counts,offsets,cursors,ids}

def scan(~space: L.Layout, g: Index<space>) -> Index<space>:
  Index{cap,counts,offsets,cursors,ids} = g
  scanned(~space,cap,ids,scan_loop(U32.to_nat(L.cells(space)),0,Scan{counts,offsets,cursors,0}))

def scattered(~S: Type, i: U32, s: S, ids: Array<U32>, r: Array<U32> & U32) -> Build<S>:
  (cursors,slot) = r
  Build{s,cursors,Array.set(U32,ids,slot,i)}

def scatter_point(~space: L.Layout, ~S: Type, i: U32, cursors: Array<U32>, ids: Array<U32>, r: S & L.Point) -> Build<S>:
  (s,p) = r
  scattered(~S,i,s,ids,Array.atomic.add(cursors,L.cell(space,p),1))

def scatter_run(~space: L.Layout, ~S: Type, ~position: @+i:U32 -> S -> S & L.Point,
  ~join: S -> S -> S, gpu: Bool, depth: Nat, n: U32, b: Build<S>) -> Build<S>:
  match gpu:
    case True{}: visit!(~S,~position,~scatter_point(~space,~S),~join,depth,n,b)
    case False{}: visit(~S,~position,~scatter_point(~space,~S),~join,depth,n,b)

def histogram_done(~space: L.Layout, ~S: Type, cap: U32, offsets: Array<U32>, cursors: Array<U32>, b: Build<S>) -> S & Index<space>:
  Build{s,counts,ids} = b
  (s,Index{cap,counts,offsets,cursors,ids})

def histogram_state(~space: L.Layout, ~S: Type, ~position: @+i:U32 -> S -> S & L.Point,
  ~join: S -> S -> S, gpu: Bool, depth: Nat, n: U32, s: S, g: Index<space>) -> S & Index<space>:
  Index{cap,counts,offsets,cursors,ids} = g
  histogram_done(~space,~S,cap,offsets,cursors,histogram_run(~space,~S,~position,~join,gpu,depth,n,Build{s,counts,ids}))

def scatter_done(~space: L.Layout, ~S: Type, n: U32, cap: U32, counts: Array<U32>, offsets: Array<U32>, b: Build<S>) -> Snapshot<space,S>:
  Build{s,cursors,ids} = b
  Snapshot{n,s,Index{cap,counts,offsets,cursors,ids}}

def scatter_state(~space: L.Layout, ~S: Type, ~position: @+i:U32 -> S -> S & L.Point,
  ~join: S -> S -> S, gpu: Bool, depth: Nat, +n: U32, s: S, g: Index<space>) -> Snapshot<space,S>:
  Index{cap,counts,offsets,cursors,ids} = g
  scatter_done(~space,~S,n,cap,counts,offsets,scatter_run(~space,~S,~position,~join,gpu,depth,n,Build{s,cursors,ids}))

def after_histogram(~space: L.Layout, ~S: Type, ~position: @+i:U32 -> S -> S & L.Point,
  ~join: S -> S -> S, gpu: Bool, depth: Nat, n: U32, r: S & Index<space>) -> Snapshot<space,S>:
  (s,g) = r
  scatter_state(~space,~S,~position,~join,gpu,depth,n,s,scan(~space,g))

def build_if(~space: L.Layout, ~S: Type, ~position: @+i:U32 -> S -> S & L.Point,
  ~join: S -> S -> S, valid: Bool, +gpu: Bool, +depth: Nat, +n: U32, s: S, g: Index<space>) -> Result<String,Snapshot<space,S>>:
  match valid:
    case False{}: Fail{"Spatial.build: active count exceeds index capacity"}
    case True{}:
      Done{after_histogram(~space,~S,~position,~join,gpu,depth,n,
        histogram_state(~space,~S,~position,~join,gpu,depth,n,s,g))}

def build(~space: L.Layout, ~S: Type, ~position: @+i:U32 -> S -> S & L.Point,
  ~join: S -> S -> S, gpu: Bool, depth: Nat, +n: U32, s: S, g: Index<space>) -> Result<String,Snapshot<space,S>>:
  Index{+cap,counts,offsets,cursors,ids} = g
  build_if(~space,~S,~position,~join,(n <= cap : U32),gpu,depth,n,s,Index{cap,counts,offsets,cursors,ids})

def recycle(~space: L.Layout, ~S: Type, s: Snapshot<space,S>) -> S & Index<space>:
  Snapshot{_,source,index} = s
  (source,index)
