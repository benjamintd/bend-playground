import Base
import ./world.bend as W
import ../../engine/spatial/grid.bend as G
import ../../engine/render/particles.bend as R
import ../../engine/core/time.bend as Time

type Scene is Type:
  Scene{world: W.World, grid: G.Grid}

type Metrics is Data:
  Metrics{update: U32, histogram: U32, scan: U32, scatter: U32, render: U32, total: U32}

type Frame is Type:
  Frame{scene: Scene, pixels: Array<U32>, image: Image, metrics: Metrics}

def create(depth: Nat) -> Frame:
  +d = depth
  Frame{Scene{W.create(d), G.empty(d)}, Array.new(U32, 20n, 0), Pix{395279}, Metrics{0,0,0,0,0,0}}

def move(gpu: Bool, depth: Nat, scene: Scene) -> Scene:
  Scene{w, g} = scene
  Scene{W.execute(gpu, depth, w), g}

def histogram_done(n: U32, cap: U32, vx: Array<F32>, vy: Array<F32>, offsets: Array<U32>,
  cursors: Array<U32>, b: G.Build) -> Scene:
  G.Build{px, py, counts, ids} = b
  Scene{W.World{n, cap, px, py, vx, vy}, G.Grid{counts, offsets, cursors, ids}}

def histogram(gpu: Bool, depth: Nat, scene: Scene) -> Scene:
  Scene{W.World{+n, cap, px, py, vx, vy}, G.Grid{counts, offsets, cursors, ids}} = scene
  histogram_done(n, cap, vx, vy, offsets, cursors,
    G.histogram_run(gpu, depth, n, G.Build{px, py, counts, ids}))

def scan(scene: Scene) -> Scene:
  Scene{w, g} = scene
  Scene{w, G.scan(g)}

def scatter_done(n: U32, cap: U32, vx: Array<F32>, vy: Array<F32>, counts: Array<U32>,
  offsets: Array<U32>, b: G.Build) -> Scene:
  G.Build{px, py, cursors, ids} = b
  Scene{W.World{n, cap, px, py, vx, vy}, G.Grid{counts, offsets, cursors, ids}}

def scatter(gpu: Bool, depth: Nat, scene: Scene) -> Scene:
  Scene{W.World{+n, cap, px, py, vx, vy}, G.Grid{counts, offsets, cursors, ids}} = scene
  scatter_done(n, cap, vx, vy, counts, offsets,
    G.scatter_run(gpu, depth, n, G.Build{px, py, cursors, ids}))

def render_done(n: U32, cap: U32, vx: Array<F32>, vy: Array<F32>, counts: Array<U32>, cursors: Array<U32>,
  r: R.Buffers & Image) -> Frame:
  (R.Buffers{px, py, offsets, ids, pixels}, image) = r
  Frame{Scene{W.World{n, cap, px, py, vx, vy}, G.Grid{counts, offsets, cursors, ids}},
    pixels, image, Metrics{0,0,0,0,0,0}}

def render(gpu: Bool, scene: Scene, pixels: Array<U32>, old: Image) -> Frame:
  Scene{W.World{n, cap, px, py, vx, vy}, G.Grid{counts, offsets, cursors, ids}} = scene
  render_done(n, cap, vx, vy, counts, cursors, R.render(gpu, R.Buffers{px, py, offsets, ids, pixels}, old))

def measured(m: Metrics, f: Frame) -> Frame:
  Frame{s, p, i, _} = f
  Frame{s, p, i, m}

def step(+gpu: Bool, +depth: Nat, f: Frame) -> IO(Frame):
  Frame{scene, pixels, old, _} = f
  do IO<Frame>:
    +t0 : Nat <- Time.micros()
    scene : Scene = move(gpu, depth, scene)
    +t1 : Nat <- Time.micros()
    scene : Scene = histogram(gpu, depth, scene)
    +t2 : Nat <- Time.micros()
    scene : Scene = scan(scene)
    +t3 : Nat <- Time.micros()
    scene : Scene = scatter(gpu, depth, scene)
    +t4 : Nat <- Time.micros()
    f : Frame = render(gpu, scene, pixels, old)
    +t5 : Nat <- Time.micros()
    return measured(Metrics{Time.elapsed(t0,t1),Time.elapsed(t1,t2),Time.elapsed(t2,t3),
      Time.elapsed(t3,t4),Time.elapsed(t4,t5),Time.elapsed(t0,t5)}, f)

def csv(m: Metrics) -> String:
  Metrics{a,b,c,d,e,f} = m
  U32.show(a) ++ "," ++ U32.show(b) ++ "," ++ U32.show(c) ++ "," ++ U32.show(d) ++ ","
    ++ U32.show(e) ++ "," ++ U32.show(f)

def report(f: Frame) -> IO(Frame):
  Frame{s, p, i, +m} = f
  do IO<Frame>:
    Unit <- IO.print(csv(m))
    return Frame{s,p,i,m}

def maybe_report(reporting: Bool, f: Frame) -> IO(Frame):
  match reporting:
    case True{}: report(f)
    case False{}: IO.pure(Frame, f)

def frames(n: Nat, +gpu: Bool, +depth: Nat, f: Frame, +reporting: Bool) -> IO(Frame):
  match n:
    case 0n: IO.pure(Frame, f)
    case 1n+p:
      do IO<Frame>:
        f : Frame <- step(gpu, depth, f)
        f : Frame <- maybe_report(reporting, f)
        frames(p, gpu, depth, f, reporting)
