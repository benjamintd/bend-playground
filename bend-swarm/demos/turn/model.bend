import Base

# Cell-space planning model and shared coordinates. Live motion: physics.bend.
type Point is Data:
  Point{x: U32, y: U32, z: U32}
type Plane is Data:
  XY{}
  YZ{}
  ZX{}
type Direction is Data:
  East{}
  North{}
  West{}
  South{}
type Action is Data:
  Walk{direction: Direction}
  Jump{direction: Direction}
  Rotate{}
  Wait{}
type State is Data:
  State{position: Point, plane: Plane}

def cycle(p: Plane) -> Plane:
  match p:
    case XY{}: YZ{}
    case YZ{}: ZX{}
    case ZX{}: XY{}
def local(p: Plane, q: Point) -> Point:
  match p:
    case XY{}: q
    case YZ{}:
      Point{x,y,z} = q
      Point{y,z,x}
    case ZX{}:
      Point{x,y,z} = q
      Point{z,x,y}
def world(p: Plane, q: Point) -> Point:
  match p:
    case XY{}: q
    case YZ{}:
      Point{x,y,z} = q
      Point{z,x,y}
    case ZX{}:
      Point{x,y,z} = q
      Point{y,z,x}
def shifted(d: Direction, n: U32, q: Point) -> Point:
  match d:
    case East{}:
      Point{x,y,z} = q
      Point{(x + n : U32),y,z}
    case North{}:
      Point{x,y,z} = q
      Point{x,(y + n : U32),z}
    case West{}:
      Point{x,y,z} = q
      Point{(x - n : U32),y,z}
    case South{}:
      Point{x,y,z} = q
      Point{x,(y - n : U32),z}
def candidate(+p: Plane, q: Point, d: Direction, n: U32) -> Point:
  world(p,shifted(d,n,local(p,q)))
def inside(q: Point) -> Bool:
  Point{x,y,z} = q
  (x < 10 : U32) && (y < 10 : U32) && (z < 10 : U32)
def equal(a: Point, b: Point) -> Bool:
  Point{x,y,z} = a
  Point{u,v,w} = b
  U32.is_eq(x,u) && U32.is_eq(y,v) && U32.is_eq(z,w)
def origin() -> State: State{Point{0,0,0},XY{}}
def position(s: State) -> Point:
  State{q,_} = s
  q
def exit_cell(q: Point) -> Bool:
  Point{x,y,_} = q
  U32.is_eq(x,9) && U32.is_eq(y,9)
def won(s: State) -> Bool:
  State{q,p} = s
  exit_cell(local(p,q))
def accept(ok: Bool, old: Point, next: Point) -> Point:
  match ok:
    case False{}: old
    case True{}: next
def depth(q: Point) -> U32:
  Point{_,_,z} = q
  z
