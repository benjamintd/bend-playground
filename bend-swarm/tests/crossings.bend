import Base
import ../demos/swarm/world.bend as W
import ../demos/swarm/points.bend as Points
import ../demos/swarm/pipeline.bend as P
import ../engine/spatial/grid.bend as G

# Pairs move through 8px cells, large image quadrants, and the periodic seam.
def edge(k: U32) -> F32:
  match k:
    case 0: 8.0
    case 1: 256.0
    case 2: 512.0
    case _: 1024.0

def sample(horizontal: Bool, along: F32, across: F32) -> W.Sample:
  match horizontal:
    case True{}: W.Sample{along,across,40.0,0.0}
    case False{}: W.Sample{across,along,0.0,40.0}

def fixture(n: Nat, +i: U32, w: W.World) -> W.World:
  match n:
    case 0n: w
    case 1n+p:
      fixture(p,(i + 1 : U32),W.write(i,w,sample((i < 8 : U32),
        F32.mod((edge((i / 2 % 4 : U32)) - 0.25 + U32.to_f32((i % 2 : U32)) * 0.5 : F32),1024.0),
        (100.0 + U32.to_f32((i / 2 : U32)) * 64.0 : F32))))

# Read the actual image tree without retaining or copying the whole frame.
def quadrant(n: Nat, +x: U32, +y: U32) -> U32:
  +bit = U32.shln(1,Nat.sub(n,1n))
  (U32.div(U32.and(x,bit),bit) + 2 * U32.div(U32.and(y,bit),bit) : U32)

def image_leaf(img: Image) -> Image & U32:
  match img:
    case Pix{+c}: (Pix{c},c)
    case Qua{a,b,c,d}: (Qua{a,b,c,d},0)

def rebuild0(b: Image, c: Image, d: Image, r: Image & U32) -> Image & U32:
  (a,color) = r
  (Qua{a,b,c,d},color)

def rebuild1(a: Image, c: Image, d: Image, r: Image & U32) -> Image & U32:
  (b,color) = r
  (Qua{a,b,c,d},color)

def rebuild2(a: Image, b: Image, d: Image, r: Image & U32) -> Image & U32:
  (c,color) = r
  (Qua{a,b,c,d},color)

def rebuild3(a: Image, b: Image, c: Image, r: Image & U32) -> Image & U32:
  (d,color) = r
  (Qua{a,b,c,d},color)

def image_at(+n: Nat, q: U32, +x: U32, +y: U32, img: Image) -> Image & U32:
  match n:
    case 0n: image_leaf(img)
    case 1n+p:
      match q img:
        case 0 Qua{a,b,c,d}:
          rebuild0(b,c,d,image_at(p,quadrant(p,x,y),x,y,a))
        case 1 Qua{a,b,c,d}:
          rebuild1(a,c,d,image_at(p,quadrant(p,x,y),x,y,b))
        case 2 Qua{a,b,c,d}:
          rebuild2(a,b,d,image_at(p,quadrant(p,x,y),x,y,c))
        case _ Qua{a,b,c,d}:
          rebuild3(a,b,c,image_at(p,quadrant(p,x,y),x,y,d))
        case _ Pix{+c}: (Pix{c},c)

def row_values(frame: U32, i: U32, x: F32, y: F32, vx: F32, vy: F32, w: W.World, image: Image, image_color: U32,
  r: Array<U32> & U32) -> IO(W.World & Array<U32> & Image):
  (pixels,color) = r
  do IO<W.World & Array<U32> & Image>:
    Unit <- IO.print(U32.show(frame) ++ "," ++ U32.show(i) ++ "," ++ F32.show(x) ++ "," ++ F32.show(y)
      ++ "," ++ F32.show(vx) ++ "," ++ F32.show(vy) ++ "," ++ U32.show(color) ++ "," ++ U32.show(image_color))
    return (w,pixels,image)

def row_image(frame: U32, i: U32, +x: F32, +y: F32, vx: F32, vy: F32, w: W.World, pixels: Array<U32>,
  r: Image & U32) -> IO(W.World & Array<U32> & Image):
  (image,image_color) = r
  row_values(frame,i,x,y,vx,vy,w,image,image_color,Array.get(U32,pixels,(F32.to_u32(x) + F32.to_u32(y) * 1024 : U32)))

def row(frame: U32, i: U32, pixels: Array<U32>, image: Image, r: W.World & W.Sample) -> IO(W.World & Array<U32> & Image):
  (w,W.Sample{+x,+y,vx,vy}) = r
  row_image(frame,i,x,y,vx,vy,w,pixels,image_at(10n,quadrant(10n,F32.to_u32(x),F32.to_u32(y)),F32.to_u32(x),F32.to_u32(y),image))

def output(n: Nat, +frame: U32, +i: U32, r: W.World & Array<U32> & Image) -> IO(W.World & Array<U32> & Image):
  match n:
    case 0n: IO.pure(W.World & Array<U32> & Image,r)
    case 1n+p:
      (w,pixels,image) = r
      do IO<W.World & Array<U32> & Image>:
        r : W.World & Array<U32> & Image <- row(frame,i,pixels,image,W.read(i,w))
        output(p,frame,(i + 1 : U32),r)

def reported(grid: G.Grid, next: W.World, metrics: P.Metrics,
  r: W.World & Array<U32> & Image) -> P.Frame:
  (w,pixels,image) = r
  P.Frame{Points.Scene{w,grid},next,pixels,image,metrics}

def report(frame: U32, f: P.Frame) -> IO(P.Frame):
  P.Frame{Points.Scene{w,grid},next,pixels,image,metrics} = f
  do IO<P.Frame>:
    r : W.World & Array<U32> & Image <- output(16n,frame,0,(w,pixels,image))
    return reported(grid,next,metrics,r)

def run(n: Nat, +frame: U32, f: P.Frame) -> IO(Unit):
  match n:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+p:
      do IO<Unit>:
        f : P.Frame <- P.step(True{},4n,0.0,0.0,0.0,f)
        f : P.Frame <- report(frame,f)
        run(p,(frame + 1 : U32),f)

def main() -> IO(Unit):
  run(120n,1,P.Frame{Points.Scene{fixture(16n,0,W.empty(4n,16)),G.empty(4n)},
    W.empty(4n,16),Array.new(U32,20n,0),Pix{0},P.Metrics{0,0,0,0,0,0,0,0n}})
