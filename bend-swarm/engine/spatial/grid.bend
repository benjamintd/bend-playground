import Base
import ../parallel/regions.bend as Region

# 128 x 128 periodic cells, 8 world units per cell.
# Offsets has double capacity so offsets[16384] is a real sentinel.
type Grid is Type:
  Grid{counts: Array<U32>, offsets: Array<U32>, cursors: Array<U32>, ids: Array<U32>}

def empty(depth: Nat) -> Grid:
  Grid{Array.new(U32, 14n, 0), Array.new(U32, 15n, 0),
    Array.new(U32, 14n, 0), Array.new(U32, depth, 0)}

def cell(x: F32, y: F32) -> U32:
  (U32.and(U32.shrn(F32.to_u32(x), 3n), 127)
    + U32.shln(U32.and(U32.shrn(F32.to_u32(y), 3n), 127), 7n) : U32)

type Build is Type:
  Build{px: Array<F32>, py: Array<F32>, counts: Array<U32>, ids: Array<U32>}

def join(a: Build, b: Build) -> Build:
  Build{ax, ay, ac, ai} = a
  Build{bx, by, bc, bi} = b
  Build{Array.join(F32, ax, bx), Array.join(F32, ay, by),
    Array.join(U32, ac, bc), Array.join(U32, ai, bi)}

def counted(px: Array<F32>, py: Array<F32>, ids: Array<U32>, r: Array<U32> & U32) -> Build:
  (counts, _) = r
  Build{px, py, counts, ids}

def histogram_y(x: F32, px: Array<F32>, counts: Array<U32>, ids: Array<U32>,
  r: Array<F32> & F32) -> Build:
  (py, y) = r
  counted(px, py, ids, Array.atomic.add(counts, cell(x, y), 1))

def histogram_x(i: U32, py: Array<F32>, counts: Array<U32>, ids: Array<U32>,
  r: Array<F32> & F32) -> Build:
  (px, x) = r
  histogram_y(x, px, counts, ids, Array.get(F32, py, i))

def histogram_one(+i: U32, s: Build) -> Build:
  Build{px, py, counts, ids} = s
  histogram_x(i, py, counts, ids, Array.get(F32, px, i))

def histogram_loop(n: Nat, +i: U32, s: Build) -> Build:
  match n:
    case 0n: s
    case 1n+p: histogram_loop(p, (i + 1 : U32), histogram_one(i, s))

def histogram_leaf(i: U32, n: U32, s: Build) -> Build:
  histogram_loop(U32.to_nat(n), i, s)

def histogram(depth: Nat, +n: U32, s: Build) -> Build:
  Region.run(~Build, ~histogram_leaf, ~join, Nat.min(depth, U32.log2(n)), 0, n, s)

def histogram_run(gpu: Bool, depth: Nat, n: U32, s: Build) -> Build:
  match gpu:
    case True{}: histogram!(depth, n, s)
    case False{}: histogram(depth, n, s)

# Safe sequential exclusive scan is the first reference. It also resets counts
# for the next frame. Every cell is consumed exactly once; no sharing here.
type Scan is Type:
  Scan{counts: Array<U32>, offsets: Array<U32>, cursors: Array<U32>, total: U32}

def scan_put(+i: U32, +sum: U32, offsets: Array<U32>, cursors: Array<U32>,
  r: Array<U32> & U32) -> Scan:
  (counts, value) = r
  Scan{Array.set(U32, counts, i, 0), Array.set(U32, offsets, i, sum),
    Array.set(U32, cursors, i, sum), (sum + value : U32)}

def scan_loop(n: Nat, +i: U32, s: Scan) -> Scan:
  match n:
    case 0n:
      Scan{counts, offsets, cursors, +sum} = s
      Scan{counts, Array.set(U32, offsets, i, sum), cursors, sum}
    case 1n+p:
      Scan{counts, offsets, cursors, sum} = s
      scan_loop(p, (i + 1 : U32), scan_put(i, sum, offsets, cursors, Array.get(U32, counts, i)))

def scan_done(ids: Array<U32>, s: Scan) -> Grid:
  Scan{counts, offsets, cursors, _} = s
  Grid{counts, offsets, cursors, ids}

def scan(g: Grid) -> Grid:
  Grid{counts, offsets, cursors, ids} = g
  scan_done(ids, scan_loop(16384n, 0, Scan{counts, offsets, cursors, 0}))

def scattered(i: U32, px: Array<F32>, py: Array<F32>, ids: Array<U32>,
  r: Array<U32> & U32) -> Build:
  (cursors, slot) = r
  Build{px, py, cursors, Array.set(U32, ids, slot, i)}

def scatter_y(i: U32, x: F32, px: Array<F32>, cursors: Array<U32>, ids: Array<U32>,
  r: Array<F32> & F32) -> Build:
  (py, y) = r
  scattered(i, px, py, ids, Array.atomic.add(cursors, cell(x, y), 1))

def scatter_x(+i: U32, py: Array<F32>, cursors: Array<U32>, ids: Array<U32>,
  r: Array<F32> & F32) -> Build:
  (px, x) = r
  scatter_y(i, x, px, cursors, ids, Array.get(F32, py, i))

def scatter_one(+i: U32, s: Build) -> Build:
  Build{px, py, cursors, ids} = s
  scatter_x(i, py, cursors, ids, Array.get(F32, px, i))

def scatter_loop(n: Nat, +i: U32, s: Build) -> Build:
  match n:
    case 0n: s
    case 1n+p: scatter_loop(p, (i + 1 : U32), scatter_one(i, s))

def scatter_leaf(i: U32, n: U32, s: Build) -> Build:
  scatter_loop(U32.to_nat(n), i, s)

def scatter(depth: Nat, +n: U32, s: Build) -> Build:
  Region.run(~Build, ~scatter_leaf, ~join, Nat.min(depth, U32.log2(n)), 0, n, s)

def scatter_run(gpu: Bool, depth: Nat, n: U32, s: Build) -> Build:
  match gpu:
    case True{}: scatter!(depth, n, s)
    case False{}: scatter(depth, n, s)
