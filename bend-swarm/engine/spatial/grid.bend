import Base
import ./layout.bend as L
import ./internal/index.bend as I

# Compatibility adapter for the 2D particle renderer and stage benchmarks.
# Histogram, scan and scatter all use the generic spatial implementation.
def space() -> L.Layout:
  L.Layout{2,7n,7n,0n,8.0,0.0,0.0,0.0,True{}}

type Grid is Type:
  Grid{counts: Array<U32>, offsets: Array<U32>, cursors: Array<U32>, ids: Array<U32>}

def from_index(~layout: L.Layout, g: I.Index<layout>) -> Grid:
  I.Index{_,counts,offsets,cursors,ids} = g
  Grid{counts,offsets,cursors,ids}

def empty(depth: Nat) -> Grid:
  from_index(~space(),I.allocate(~space(),depth))

def cell(x: F32, y: F32) -> U32:
  L.cell(space(),L.Point{x,y,0.0})

type XY is Type:
  XY{x: Array<F32>, y: Array<F32>}

def read_y(x: F32, xs: Array<F32>, r: Array<F32> & F32) -> XY & L.Point:
  (ys,y) = r
  (XY{xs,ys},L.Point{x,y,0.0})

def read_x(i: U32, ys: Array<F32>, r: Array<F32> & F32) -> XY & L.Point:
  (xs,x) = r
  read_y(x,xs,Array.get(F32,ys,i))

def read(+i: U32, p: XY) -> XY & L.Point:
  XY{x,y} = p
  read_x(i,y,Array.get(F32,x,i))

def join(a: XY, b: XY) -> XY:
  XY{ax,ay} = a
  XY{bx,by} = b
  XY{Array.join(F32,ax,bx),Array.join(F32,ay,by)}

type Build is Type:
  Build{px: Array<F32>, py: Array<F32>, counts: Array<U32>, ids: Array<U32>}

def built(b: I.Build<XY>) -> Build:
  I.Build{XY{x,y},counts,ids} = b
  Build{x,y,counts,ids}

def histogram_run(gpu: Bool, depth: Nat, n: U32, b: Build) -> Build:
  Build{x,y,counts,ids} = b
  built(I.histogram_run(~space(),~XY,~read,~join,gpu,depth,n,I.Build{XY{x,y},counts,ids}))

def scatter_run(gpu: Bool, depth: Nat, n: U32, b: Build) -> Build:
  Build{x,y,counts,ids} = b
  built(I.scatter_run(~space(),~XY,~read,~join,gpu,depth,n,I.Build{XY{x,y},counts,ids}))

def scan(g: Grid) -> Grid:
  Grid{counts,offsets,cursors,ids} = g
  from_index(~space(),I.scan(~space(),I.Index{0,counts,offsets,cursors,ids}))

# Internal adapter: caller has just completed all three build stages against
# this exact source. User-facing code should use Spatial.build instead.
def snapshot(~S: Type, n: U32, capacity: U32, source: S, g: Grid) -> I.Snapshot<space(),S>:
  Grid{counts,offsets,cursors,ids} = g
  I.Snapshot{n,source,I.Index{capacity,counts,offsets,cursors,ids}}
