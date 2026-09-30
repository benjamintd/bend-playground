import Base
import ../camera.bend as C
import ../spatial/layout.bend as L
import ../core/vec3.bend as V

# Bounded dense occupancy. One host owner; zero denotes empty space.
type World is Type:
  World{cells: Array<U32>, width: U32, height: U32, depth: U32}
type Hit is Data:
  Hit{cell: L.Point, normal: L.Point, distance: F32, material: U32}
# Reject invalid/overflowing allocations before constructing an array.
def create_valid(valid: Bool, +w: U32, +h: U32, +d: U32) -> Maybe<&1, World>:
  match valid:
    case False{}: None{}
    case True{}: Some{World{Array.new(U32,Nat.add(1n,U32.log2(U32.max(1,(w * h * d - 1 : U32)))),0),w,h,d}}
def create(+w: U32, +h: U32, +d: U32) -> Maybe<&1, World>:
  create_valid((w > 0 : U32) && (h > 0 : U32) && (d > 0 : U32) && (w <= 1024 : U32)
    && (h <= 1024 : U32) && (d <= 1024 : U32) && (w * h * d <= 16777216 : U32),w,h,d)
def inside(+p: L.Point, w: U32, h: U32, d: U32) -> Bool:
  L.Point{+x,+y,+z} = p
  (x >= 0.0 : F32) && (y >= 0.0 : F32) && (z >= 0.0 : F32)
    && (x < U32.to_f32(w) : F32) && (y < U32.to_f32(h) : F32) && (z < U32.to_f32(d) : F32)
def index(p: L.Point, +w: U32, h: U32) -> U32:
  L.Point{x,y,z} = p
  (F32.to_u32(x) + F32.to_u32(y) * w + F32.to_u32(z) * w * h : U32)
def read_result(w: U32, h: U32, d: U32, r: Array<U32> & U32) -> World & U32:
  (cells,v) = r
  (World{cells,w,h,d},v)
def read_valid(valid: Bool, p: L.Point, world: World) -> World & U32:
  match valid:
    case False{}: (world,0)
    case True{}:
      World{cells,+w,+h,d} = world
      read_result(w,h,d,Array.get(U32,cells,index(p,w,h)))
def read(world: World, +p: L.Point) -> World & U32:
  World{cells,+w,+h,+d} = world
  read_valid(inside(p,w,h,d),p,World{cells,w,h,d})
def write_valid(valid: Bool, p: L.Point, v: U32, world: World) -> World:
  match valid:
    case False{}: world
    case True{}:
      World{cells,+w,+h,d} = world
      World{Array.set(U32,cells,index(p,w,h),v),w,h,d}
def write(world: World, +p: L.Point, value: U32) -> World:
  World{cells,+w,+h,+d} = world
  write_valid(inside(p,w,h,d),p,value,World{cells,w,h,d})

def slab_parallel(inside: Bool) -> F32 & F32:
  match inside:
    case True{}: (F32.neg(1.0e30),1.0e30)
    case False{}: (1.0e30,F32.neg(1.0e30))
def slab_moving(moving: Bool, +origin: F32, +direction: F32, extent: F32) -> F32 & F32:
  match moving:
    case False{}: slab_parallel((origin >= 0.0 : F32) && (origin < extent : F32))
    case True{}:
      +a = (F32.neg(origin) / direction : F32)
      +b = ((extent - origin) / direction : F32)
      (F32.min(a,b),F32.max(a,b))
def slab(origin: F32, +direction: F32, extent: F32) -> F32 & F32:
  slab_moving(F32.is_ne(direction,0.0),origin,direction,extent)
def sign(+x: F32) -> F32:
  L.pick((x > 0.0 : F32),1.0,L.pick((x < 0.0 : F32),F32.neg(1.0),0.0))
def cell_axis(+p: F32, direction: F32) -> F32:
  +f = F32.floor(p)
  (f - L.pick((direction < 0.0 : F32) && F32.is_eq(p,f),1.0,0.0) : F32)
def crossing(moving: Bool, +cell: F32, origin: F32, +direction: F32) -> F32:
  match moving:
    case False{}: 1.0e30
    case True{}: ((cell + L.pick((direction > 0.0 : F32),1.0,0.0) - origin) / direction : F32)
def next_axis(cell: F32, origin: F32, +direction: F32) -> F32:
  crossing(F32.is_ne(direction,0.0),cell,origin,direction)
type Walk is Data:
  Walk{cell: L.Point, normal: L.Point, distance: F32}
def advance(ray: C.Ray, walk: Walk) -> Walk:
  C.Ray{L.Point{ox,oy,oz},L.Point{+dx,+dy,+dz},_,_} = ray
  Walk{L.Point{+x,+y,+z},_,_} = walk
  +tx = next_axis(x,ox,dx)
  +ty = next_axis(y,oy,dy)
  +tz = next_axis(z,oz,dz)
  +t = F32.min(tx,F32.min(ty,tz))
  +sx = F32.is_eq(tx,t)
  +sy = F32.is_eq(ty,t)
  +sz = F32.is_eq(tz,t)
  Walk{L.Point{(x + L.pick(sx,sign(dx),0.0) : F32),(y + L.pick(sy,sign(dy),0.0) : F32),(z + L.pick(sz,sign(dz),0.0) : F32)},
    L.Point{L.pick(sx,F32.neg(sign(dx)),0.0),L.pick(Bool.not(sx) && sy,F32.neg(sign(dy)),0.0),L.pick(Bool.not(sx) && Bool.not(sy) && sz,F32.neg(sign(dz)),0.0)},t}
type Trace is Type:
  TraceDone{world: World, hit: Maybe<&2, Hit>}
  March{world: World, state: Walk}
def checked(valid: Bool, occupied: Bool, +ray: C.Ray, state: Walk, world: World, hit: Hit) -> Trace:
  match valid occupied:
    case False{} _: TraceDone{world,None{}}
    case True{} True{}: TraceDone{world,Some{hit}}
    case True{} False{}: March{world,advance(ray,state)}
def traced_state(+ray: C.Ray, +state: Walk, world: World, +value: U32, w: U32, h: U32, d: U32) -> Trace:
  C.Ray{_,_,_,maximum} = ray
  Walk{+cell,normal,+distance} = state
  checked(inside(cell,w,h,d) && (distance <= maximum : F32),U32.is_ne(value,0),ray,state,world,Hit{cell,normal,distance,value})
def traced(+ray: C.Ray, +state: Walk, r: World & U32) -> Trace:
  (World{cells,+w,+h,+d},+value) = r
  traced_state(ray,state,World{cells,w,h,d},value,w,h,d)
def trace(ray: C.Ray, +state: Walk, world: World) -> Trace:
  Walk{cell,_,_} = state
  traced(ray,state,read(world,cell))
# Fuel width+height+depth+3 bounds the number of crossed cells.
def walk(n: Nat, +ray: C.Ray, trace_state: Trace) -> World & Maybe<&2, Hit>:
  match n trace_state:
    case _ TraceDone{world,hit}: (world,hit)
    case 0n March{world,_}: (world,None{})
    case 1n+k March{world,state}: walk(k,ray,trace(ray,state,world))
def entered_at(+ray: C.Ray, world: World, distance: F32, normal: L.Point, p: L.Point) -> World & Maybe<&2, Hit>:
  C.Ray{_,L.Point{dx,dy,dz},_,_} = ray
  World{cells,+w,+h,+d} = world
  L.Point{x,y,z} = p
  walk(U32.to_nat((w + h + d + 3 : U32)),ray,March{World{cells,w,h,d},Walk{L.Point{cell_axis(F32.clamp(x,0.0,U32.to_f32(w)),dx),cell_axis(F32.clamp(y,0.0,U32.to_f32(h)),dy),cell_axis(F32.clamp(z,0.0,U32.to_f32(d)),dz)},normal,distance}})
def entered(valid: Bool, +ray: C.Ray, world: World, +distance: F32, normal: L.Point) -> World & Maybe<&2, Hit>:
  match valid:
    case False{}: (world,None{})
    case True{}: entered_at(ray,world,distance,normal,C.ray_at(ray,distance))
def interval(+ray: C.Ray, world: World, xs: F32 & F32, ys: F32 & F32, zs: F32 & F32) -> World & Maybe<&2, Hit>:
  C.Ray{_,L.Point{dx,dy,dz},+minimum,maximum} = ray
  (+xa,xb) = xs
  (+ya,yb) = ys
  (+za,zb) = zs
  +entry = F32.max(xa,F32.max(ya,za))
  +start = F32.max(minimum,entry)
  +end = F32.min(maximum,F32.min(xb,F32.min(yb,zb)))
  +nx = F32.is_eq(entry,xa) && (entry >= minimum : F32)
  +ny = F32.is_eq(entry,ya) && Bool.not(nx) && (entry >= minimum : F32)
  entered((start <= end : F32),ray,world,start,L.Point{L.pick(nx,F32.neg(sign(dx)),0.0),L.pick(ny,F32.neg(sign(dy)),0.0),L.pick(Bool.not(nx) && Bool.not(ny) && (entry >= minimum : F32),F32.neg(sign(dz)),0.0)})
def raycast(world: World, +ray: C.Ray) -> World & Maybe<&2, Hit>:
  World{cells,+w,+h,+d} = world
  C.Ray{L.Point{ox,oy,oz},L.Point{dx,dy,dz},_,_} = ray
  interval(ray,World{cells,w,h,d},slab(ox,dx,U32.to_f32(w)),slab(oy,dy,U32.to_f32(h)),slab(oz,dz,U32.to_f32(d)))
