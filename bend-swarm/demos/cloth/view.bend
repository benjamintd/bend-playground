import Base
import ./world.bend as W
import ../../engine/render/mesh.bend as M
import ../../engine/spatial/layout.bend as L
import ../../engine/parallel/regions.bend as Region

# Fixed perspective camera looking at (0, 0.45, 0) from 7.5 metres away.
# Orthonormal basis is constant so no camera record is shared in pixel loops.
def project(p: L.Point) -> M.Vertex:
  L.Point{+x,+py,+z} = p
  +y = (py - 0.45 : F32)
  +depth = (7.5 - x * 0.5305368 - y * 0.40776045 - z * 0.74314344 : F32)
  +scale = (480.0 / F32.max(depth,0.1) : F32)
  M.Vertex{(256.0 + (x * 0.8138785 - z * 0.5810352) * scale : F32),
    (245.0 - (y * 0.9130889 - x * 0.23692316 - z * 0.33186746) * scale : F32),depth}

def ray(+x: F32, +y: F32) -> L.Point:
  +u = ((x - 256.0) / 480.0 : F32)
  +v = ((245.0 - y) / 480.0 : F32)
  L.Point{(F32.neg(0.5305368) + u * 0.8138785 - v * 0.23692316 : F32),
    (F32.neg(0.40776045) + v * 0.9130889 : F32),
    (F32.neg(0.74314344) - u * 0.5810352 - v * 0.33186746 : F32)}

def along(+depth: F32, direction: L.Point) -> L.Point:
  L.Point{x,y,z} = direction
  L.Point{(3.979026 + x * depth : F32),(3.5082035 + y * depth : F32),(5.5735755 + z * depth : F32)}

def target(x: F32, y: F32, depth: F32) -> L.Point:
  along(depth,ray(x,y))

def rgb(+light: F32, r: F32, g: F32, b: F32) -> U32:
  (F32.to_u32(F32.min(255.0,(r * light : F32))) * 65536
    + F32.to_u32(F32.min(255.0,(g * light : F32))) * 256
    + F32.to_u32(F32.min(255.0,(b * light : F32))) : U32)

def cloth_color(light: F32, alternate: Bool) -> U32:
  match alternate:
    case False{}: rgb(light,51.0,201.0,184.0)
    case True{}: rgb(light,221.0,225.0,200.0)

def material(side: U32, +id: U32, a: L.Point, b: L.Point, c: L.Point) -> U32:
  L.Point{+ax,+ay,+az} = a
  L.Point{bx,by,bz} = b
  L.Point{cx,cy,cz} = c
  +ux = (bx - ax : F32)
  +uy = (by - ay : F32)
  +uz = (bz - az : F32)
  +vx = (cx - ax : F32)
  +vy = (cy - ay : F32)
  +vz = (cz - az : F32)
  +nx = (uy * vz - uz * vy : F32)
  +ny = (uz * vx - ux * vz : F32)
  +nz = (ux * vy - uy * vx : F32)
  +norm = F32.max(F32.sqrt((nx * nx + ny * ny + nz * nz : F32)),0.000001)
  +stride = (side - 1 : U32)
  +quad = U32.shr(id)
  cloth_color((0.3 + 0.7 * F32.abs((nx * F32.neg(0.35) + ny * 0.8 + nz * 0.48 : F32)) / norm : F32),
    U32.is_eq(U32.and((U32.shrn((quad % stride : U32),2n) + U32.shrn((quad / stride : U32),2n) : U32),1),0))

type Projection is Type:
  Projection{positions: W.Positions, triangles: Array<M.Triangle>, side: U32}

def triangle_c(+id: U32, +side: U32, +a: L.Point, +b: L.Point, tris: Array<M.Triangle>, r: W.Positions & L.Point) -> Projection:
  (p,+c) = r
  Projection{p,Array.set(M.Triangle,tris,id,M.Triangle{project(a),project(b),project(c),material(side,id,a,b,c)}),side}

def triangle_b(id: U32, side: U32, c: U32, a: L.Point, tris: Array<M.Triangle>, r: W.Positions & L.Point) -> Projection:
  (p,b) = r
  triangle_c(id,side,a,b,tris,W.read(c,p))

def triangle_a(id: U32, side: U32, b: U32, c: U32, tris: Array<M.Triangle>, r: W.Positions & L.Point) -> Projection:
  (p,a) = r
  triangle_b(id,side,c,a,tris,W.read(b,p))

def triangle(+id: U32, p: Projection) -> Projection:
  Projection{positions,tris,+side} = p
  +quad = U32.shr(id)
  +stride = (side - 1 : U32)
  +base = (quad % stride + quad / stride * side : U32)
  +second = U32.is_eq(U32.and(id,1),1)
  triangle_a(id,side,(base + 1 : U32),L.word(second,(base + side + 1 : U32),(base + side : U32)),tris,
    W.read(L.word(second,(base + side : U32),base),positions))

def project_loop(n: Nat, +i: U32, p: Projection) -> Projection:
  match n:
    case 0n: p
    case 1n+k: project_loop(k,(i + 1 : U32),triangle(i,p))

def project_leaf(start: U32, n: U32, p: Projection) -> Projection:
  project_loop(U32.to_nat(n),start,p)

def project_join(a: Projection, b: Projection) -> Projection:
  Projection{ap,at,side} = a
  Projection{bp,bt,_} = b
  Projection{W.join(ap,bp),Array.join(M.Triangle,at,bt),side}

def triangles(+n: U32, p: Projection) -> Projection:
  Region.run(~Projection,~project_leaf,~project_join,U32.log2(U32.max(n,1)),0,n,p)

def triangles_run(gpu: Bool, n: U32, p: Projection) -> Projection:
  match gpu:
    case True{}: triangles!(n,p)
    case False{}: triangles(n,p)

# Analytic sphere and floor establish the depth behind the rasterized cloth.
def ground_point(+depth: F32, old: M.Fragment, p: L.Point) -> M.Fragment:
  L.Point{+x,_,+z} = p
  +grid = (F32.abs((L.wrap((x + 0.5 : F32),1.0) - 0.5 : F32)) < 0.012 : F32)
    || (F32.abs((L.wrap((z + 0.5 : F32),1.0) - 0.5 : F32)) < 0.012 : F32)
  +shadow = (0.64 + 0.36 * F32.min(1.0,((x * x + z * z) / 3.5 : F32)) : F32)
  M.choose((depth > 0.0 : F32) && (F32.abs(x) < 8.0 : F32) && (F32.abs(z) < 8.0 : F32),depth,
    rgb((shadow * L.pick(grid,1.2,1.0) : F32),37.0,46.0,57.0),old)

def ground_hit(valid: Bool, +depth: F32, d: L.Point, old: M.Fragment) -> M.Fragment:
  match valid:
    case False{}: old
    case True{}: ground_point(depth,old,along(depth,d))

def ground(+d: L.Point, old: M.Fragment) -> M.Fragment:
  L.Point{_,+y,_} = d
  ground_hit((y < F32.neg(0.001) : F32),(F32.neg(5.1082035) / F32.min(y,F32.neg(0.001)) : F32),d,old)

def sphere_material(light: F32, pin: Bool) -> U32:
  match pin:
    case True{}: rgb(light,255.0,190.0,73.0)
    case False{}: rgb(light,183.0,112.0,77.0)

def sphere_color(center: L.Point, hit: L.Point, radius: F32, pin: Bool) -> U32:
  L.Point{cx,cy,cz} = center
  L.Point{x,y,z} = hit
  +light = (0.3 + 0.7 * F32.max(0.0,(((x - cx) * F32.neg(0.35) + (y - cy) * 0.8 + (z - cz) * 0.48) / radius : F32)) : F32)
  sphere_material(light,pin)

def sphere_hit(valid: Bool, +depth: F32, d: L.Point, center: L.Point, radius: F32, pin: Bool, old: M.Fragment) -> M.Fragment:
  match valid:
    case False{}: old
    case True{}: M.choose((depth > 0.0 : F32),depth,sphere_color(center,along(depth,d),radius,pin),old)

def sphere(+d: L.Point, +center: L.Point, +radius: F32, pin: Bool, old: M.Fragment) -> M.Fragment:
  L.Point{+dx,+dy,+dz} = d
  L.Point{cx,cy,cz} = center
  +x = (3.979026 - cx : F32)
  +y = (3.5082035 - cy : F32)
  +z = (5.5735755 - cz : F32)
  +a = (dx * dx + dy * dy + dz * dz : F32)
  +b = (x * dx + y * dy + z * dz : F32)
  +disc = (b * b - a * (x * x + y * y + z * z - radius * radius) : F32)
  sphere_hit((disc >= 0.0 : F32),((F32.neg(b) - F32.sqrt(F32.max(disc,0.0))) / a : F32),d,center,radius,pin,old)

def background(x: U32, y: U32) -> M.Fragment:
  +py = y
  +d = ray((U32.to_f32(x) + 0.5 : F32),(U32.to_f32(py) + 0.5 : F32))
  sphere(d,L.Point{1.8,1.55,1.8},0.05,True{},
    sphere(d,L.Point{F32.neg(1.8),1.55,F32.neg(1.8)},0.05,True{},
      sphere(d,L.Point{0.0,F32.neg(0.25),0.0},1.20,False{},
        ground(d,M.Fragment{1000.0,rgb((0.85 + U32.to_f32(py) / 1800.0 : F32),19.0,26.0,36.0)}))))
