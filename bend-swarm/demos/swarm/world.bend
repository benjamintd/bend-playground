import Base
import ../../engine/core/math.bend as M
import ../../engine/parallel/regions.bend as Region

type World is Type:
  World{count: U32, capacity: U32, px: Array<F32>, py: Array<F32>,
    vx: Array<F32>, vy: Array<F32>}

def join(a: World, b: World) -> World:
  World{n, cap, ax, ay, avx, avy} = a
  World{_, _, bx, by, bvx, bvy} = b
  World{n, cap, Array.join(F32, ax, bx), Array.join(F32, ay, by),
    Array.join(F32, avx, bvx), Array.join(F32, avy, bvy)}

def empty(+depth: Nat, count: U32) -> World:
  World{count, U32.shln(1, depth), Array.new(F32, depth, 0.0),
    Array.new(F32, depth, 0.0), Array.new(F32, depth, 0.0), Array.new(F32, depth, 0.0)}

def initialize(n: Nat, +i: U32, w: World) -> World:
  match n:
    case 0n: w
    case 1n+p:
      World{count, cap, px, py, vx, vy} = w
      initialize(p, (i + 1 : U32), World{count, cap,
        Array.set(F32, px, i, (M.random(i, 42) * 1024.0 : F32)),
        Array.set(F32, py, i, (M.random(i, 9876) * 1024.0 : F32)),
        Array.set(F32, vx, i, ((M.random(i, 3456) - 0.5) * 60.0 : F32)),
        Array.set(F32, vy, i, ((M.random(i, 7890) - 0.5) * 60.0 : F32))})

def fill(start: U32, n: U32, w: World) -> World:
  initialize(U32.to_nat(n), start, w)

def create(+depth: Nat) -> World:
  Region.run(~World, ~fill, ~join, Nat.min(depth, 12n), 0,
    U32.shln(1, depth), empty(depth, U32.shln(1, depth)))


type Sample is Data:
  Sample{x: F32, y: F32, vx: F32, vy: F32}

def read4(n: U32, cap: U32, px: Array<F32>, py: Array<F32>, vx: Array<F32>,
  x: F32, y: F32, dx: F32, r: Array<F32> & F32) -> World & Sample:
  (vy, dy) = r
  (World{n, cap, px, py, vx, vy}, Sample{x, y, dx, dy})

def read3(i: U32, n: U32, cap: U32, px: Array<F32>, py: Array<F32>, vy: Array<F32>,
  x: F32, y: F32, r: Array<F32> & F32) -> World & Sample:
  (vx, dx) = r
  read4(n, cap, px, py, vx, x, y, dx, Array.get(F32, vy, i))

def read2(+i: U32, n: U32, cap: U32, px: Array<F32>, vx: Array<F32>, vy: Array<F32>,
  x: F32, r: Array<F32> & F32) -> World & Sample:
  (py, y) = r
  read3(i, n, cap, px, py, vy, x, y, Array.get(F32, vx, i))

def read1(+i: U32, n: U32, cap: U32, py: Array<F32>, vx: Array<F32>, vy: Array<F32>,
  r: Array<F32> & F32) -> World & Sample:
  (px, x) = r
  read2(i, n, cap, px, vx, vy, x, Array.get(F32, py, i))

def read(+i: U32, w: World) -> World & Sample:
  World{n, cap, px, py, vx, vy} = w
  read1(i, n, cap, py, vx, vy, Array.get(F32, px, i))

def write(+i: U32, w: World, v: Sample) -> World:
  World{n, cap, px, py, vx, vy} = w
  Sample{x, y, dx, dy} = v
  World{n, cap, Array.set(F32, px, i, x), Array.set(F32, py, i, y),
    Array.set(F32, vx, i, dx), Array.set(F32, vy, i, dy)}

# First measured pipeline: ballistic points, explicitly NOT boids.
def moved(i: U32, +dt: F32, r: World & Sample) -> World:
  (w, Sample{x, y, +dx, +dy}) = r
  write(i, w, Sample{M.wrap((x + dx * dt : F32)), M.wrap((y + dy * dt : F32)), dx, dy})

def move(n: Nat, +i: U32, +dt: F32, w: World) -> World:
  match n:
    case 0n: w
    case 1n+p:
      move(p, (i + 1 : U32), dt, moved(i, dt, read(i, w)))

def move_leaf(i: U32, n: U32, w: World) -> World:
  move(U32.to_nat(n), i, 0.016666667, w)

def step(depth: Nat, w: World) -> World:
  World{n, +cap, px, py, vx, vy} = w
  Region.run(~World, ~move_leaf, ~join, Nat.min(depth, U32.log2(cap)), 0, cap,
    World{n, cap, px, py, vx, vy})

def execute(gpu: Bool, depth: Nat, w: World) -> World:
  match gpu:
    case True{}: step!(depth, w)
    case False{}: step(depth, w)
