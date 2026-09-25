import Base
import ../../engine/core/math.bend as Math
import ../../engine/core/vec3.bend as V
import ../../engine/spatial/layout.bend as L
import ../../engine/fields/wind.bend as Wind
import ../../engine/geometry/curve.bend as Curve
import ../../engine/render/camera.bend as Camera
import ../../engine/render/mesh.bend as M
import ../../engine/render/color.bend as Color
import ../../engine/parallel/regions.bend as Region

def camera_size(high: Bool) -> Camera.Camera:
  +scale = L.pick(high,2.0,1.0)
  Camera.look_at(L.Point{5.9,5.2,7.9},L.Point{0.0,0.2,0.0},(850.0 * scale : F32),(512.0 * scale : F32),(455.0 * scale : F32))
def camera() -> Camera.Camera:
  camera_size(False{})
def root(+i: U32) -> L.Point:
  +radius = (4.2 * F32.sqrt(((U32.to_f32(i) + 0.5) / 4096.0 : F32)) : F32)
  # Integer phase keeps the golden-angle distribution within one turn before
  # conversion to F32, avoiding backend-dependent rounding of large angles.
  +phase = U32.to_f32(((i * 400520) % 1048576 : U32))
  +angle = (phase * 0.0000059921125 + Math.random(i,12) * 0.1 : F32)
  L.Point{(F32.cos(angle) * radius : F32),0.0,(F32.sin(angle) * radius : F32)}
def clearance(p: L.Point) -> F32:
  L.Point{x,_,z} = p
  F32.min(1.0,F32.max(0.0,((F32.abs((x - F32.sin((z * 0.7 : F32)) * 0.72 : F32)) - 0.22) * 4.0 : F32)))
def height(+i: U32) -> F32:
  (0.025 + (0.34 + Math.random(i,39) * 0.28) * clearance(root(i)) : F32)
def flower(+i: U32) -> Bool:
  U32.is_eq((Math.hash(i) % 27 : U32),0) && (clearance(root(i)) > 0.8 : F32)
type Blade is Data:
  Blade{x: F32, z: F32, vx: F32, vz: F32}
type Controls is Data:
  Controls{time: F32, strength: F32, mx: F32, mz: F32, power: F32}
def integrated(+x: F32, +z: F32, +vx: F32, +vz: F32) -> Blade:
  +nx = (x + vx * 0.016666667 : F32)
  +nz = (z + vz * 0.016666667 : F32)
  +scale = F32.min(1.0,(0.9 / F32.sqrt((nx * nx + nz * nz + 0.000001 : F32)) : F32))
  Blade{(nx * scale : F32),(nz * scale : F32),(vx * scale : F32),(vz * scale : F32)}
def forced(p: L.Point, wind: L.Point, c: Controls, b: Blade) -> Blade:
  L.Point{+x,_,+z} = p
  L.Point{wx,_,wz} = wind
  Controls{_,+strength,mx,mz,power} = c
  Blade{+bx,+bz,+vx,+vz} = b
  +dx = (x - mx : F32)
  +dz = (z - mz : F32)
  +push = (power * 4.0 / (1.0 + 2.5 * (dx * dx + dz * dz)) : F32)
  integrated(bx,bz,(vx + ((wx * strength + dx * push - bx) * 35.0 - vx * 7.5) * 0.016666667 : F32),
    (vz + ((wz * strength + dz * push - bz) * 35.0 - vz * 7.5) * 0.016666667 : F32))
def advanced_at(+i: U32, +c: Controls, +p: L.Point, r: Array<Blade> & Blade) -> Array<Blade>:
  Controls{time,_,_,_,_} = c
  L.Point{x,_,z} = p
  (a,b) = r
  Array.set(Blade,a,i,forced(p,Wind.sample(x,z,time),c,b))
def advanced(+i: U32, c: Controls, r: Array<Blade> & Blade) -> Array<Blade>:
  advanced_at(i,c,root(i),r)
type Simulation is Type:
  Simulation{blades: Array<Blade>, controls: Controls}
def step_loop(n: Nat, +i: U32, s: Simulation) -> Simulation:
  match n:
    case 0n: s
    case 1n+k:
      Simulation{blades,+c} = s
      step_loop(k,(i + 1 : U32),Simulation{advanced(i,c,Array.get(Blade,blades,i)),c})
def step_leaf(i: U32, n: U32, s: Simulation) -> Simulation:
  step_loop(U32.to_nat(n),i,s)
def sim_join(a: Simulation, b: Simulation) -> Simulation:
  Simulation{a,c} = a
  Simulation{b,_} = b
  Simulation{Array.join(Blade,a,b),c}
def step(depth: Nat, s: Simulation) -> Simulation:
  Region.run(~Simulation,~step_leaf,~sim_join,depth,0,4096,s)
def simulated(s: Simulation) -> Array<Blade>:
  Simulation{b,_} = s
  b
def simulate_run(gpu: Bool, c: Controls, blades: Array<Blade>) -> Array<Blade>:
  match gpu:
    case True{}: simulated(step!(12n,Simulation{blades,c}))
    case False{}: simulated(step(6n,Simulation{blades,c}))
def simulate(gpu: Bool, paused: Bool, c: Controls, blades: Array<Blade>) -> Array<Blade>:
  match paused:
    case True{}: blades
    case False{}: simulate_run(gpu,c,blades)

def soil(inside: Bool, +x: F32, +z: F32, +r: F32) -> U32:
  match inside:
    case False{}:
      +shade = (0.66 + 0.34 * F32.min(1.0,F32.max(0.0,((r - 4.2) / 2.7 : F32))) : F32)
      M.shaded(2305845,shade)
    case True{}:
      +grass = clearance(L.Point{x,0.0,z})
      +shade = (0.9 + 0.06 * F32.sin((x * 2.1 + z * 1.7 : F32)) + 0.04 * F32.cos((z * 3.7 - x * 1.3 : F32)) : F32)
      M.shaded(L.word((grass > 0.5 : F32),3297819,11313771),shade)
def ground_color(p: L.Point) -> U32:
  L.Point{+x,_,+z} = p
  +r = F32.sqrt((x * x + z * z : F32))
  soil((r < 4.32 : F32),x,z,r)
def ground_hit(~high: Bool,valid: Bool, +direction: L.Point, +depth: F32) -> M.Fragment:
  match valid:
    case False{}: M.Fragment{1000.0,2305845}
    case True{}: M.Fragment{depth,ground_color(Camera.along(~camera_size(high),direction,depth))}
def background_ray(~high: Bool,+ray: L.Point) -> M.Fragment:
  L.Point{_,+dy,_} = ray
  ground_hit(~high,(dy < F32.neg(0.001) : F32),ray,(F32.neg(5.2) / F32.min(dy,F32.neg(0.001)) : F32))
def background_size(~high: Bool,x: U32, y: U32) -> M.Fragment:
  background_ray(~high,Camera.ray(~camera_size(high),(U32.to_f32(x) + 0.5 : F32),(U32.to_f32(y) + 0.5 : F32)))
def mouse_hit(valid: Bool, +direction: L.Point, depth: F32) -> L.Point:
  match valid:
    case False{}: L.Point{100.0,0.0,100.0}
    case True{}: Camera.along(~camera(),direction,depth)
def mouse_ray(+ray: L.Point) -> L.Point:
  L.Point{_,+dy,_} = ray
  mouse_hit((dy < F32.neg(0.001) : F32),ray,(F32.neg(5.2) / F32.min(dy,F32.neg(0.001)) : F32))
def mouse(x: F32, y: F32) -> L.Point:
  mouse_ray(Camera.ray(~camera(),(x * 1024.0 : F32),(y * 1024.0 : F32)))
def controls(time: F32, +preset: U32, power: F32, p: L.Point) -> Controls:
  L.Point{x,_,z} = p
  Controls{time,L.pick(U32.is_eq(preset,0),0.18,L.pick(U32.is_eq(preset,1),0.55,1.0)),x,z,power}

def position(+i: U32, b: Blade, +t: F32) -> L.Point:
  Blade{+x,+z,_,_} = b
  +h = height(i)
  +r = root(i)
  +bend = F32.sqrt((x * x + z * z : F32))
  Curve.quadratic(r,V.add(r,L.Point{(x * h * 0.12 : F32),(h * 0.62 : F32),(z * h * 0.12 : F32)}),
    V.add(r,L.Point{(x * h : F32),(h * (1.0 - 0.27 * bend) : F32),(z * h : F32)}),t)
def width(+i: U32, +t: F32) -> L.Point:
  +angle = (Math.random(i,384) * 6.2831853 : F32)
  +w = ((0.016 + Math.random(i,493) * 0.013) * (1.0 - t * 0.96) : F32)
  L.Point{(F32.cos(angle) * w : F32),0.0,(F32.sin(angle) * w : F32)}
def vertex(~high: Bool,+i: U32, b: Blade, +t: F32, side: F32) -> M.Vertex:
  Camera.project(~camera_size(high),V.add(position(i,b,t),V.mul(width(i,t),side)),(0.35 + t * 0.65 : F32))
def material(+i: U32) -> U32:
  +r = Math.random(i,810)
  L.word((r < 0.35 : F32),8298056,L.word((r < 0.7 : F32),10858572,6263872))
def quad(+id: U32, +a: M.Vertex, b: M.Vertex, +c: M.Vertex, d: M.Vertex, +color: U32, tris: Array<M.Triangle>) -> Array<M.Triangle>:
  Array.set(M.Triangle,Array.set(M.Triangle,tris,id,M.Triangle{a,b,c,color}),(id + 1 : U32),M.Triangle{a,c,d,color})
def segment(~high: Bool,+i: U32, +b: Blade, +part: U32, tris: Array<M.Triangle>) -> Array<M.Triangle>:
  +lo = (U32.to_f32(part) / 3.0 : F32)
  +hi = ((U32.to_f32(part) + 1.0) / 3.0 : F32)
  quad((i * 8 + part * 2 : U32),vertex(~high,i,b,lo,F32.neg(1.0)),vertex(~high,i,b,lo,1.0),vertex(~high,i,b,hi,1.0),vertex(~high,i,b,hi,F32.neg(1.0)),material(i),tris)
def petal(~high: Bool,+p: L.Point, dx: F32, dy: F32) -> M.Vertex:
  Camera.project(~camera_size(high),V.add(p,L.Point{dx,dy,0.0}),1.0)
def blossom(~high: Bool,on: Bool, +i: U32, b: Blade, tris: Array<M.Triangle>) -> Array<M.Triangle>:
  match on:
    case False{}: Array.set(M.Triangle,Array.set(M.Triangle,tris,(i * 8 + 6 : U32),M.blank()),(i * 8 + 7 : U32),M.blank())
    case True{}:
      +p = position(i,b,1.0)
      +color = L.word(U32.is_eq((i % 3 : U32),0),16769143,L.word(U32.is_eq((i % 3 : U32),1),14924773,16053470))
      quad((i * 8 + 6 : U32),petal(~high,p,F32.neg(0.055),0.0),petal(~high,p,0.0,0.05),petal(~high,p,0.055,0.0),petal(~high,p,0.0,F32.neg(0.05)),color,tris)
type Geometry is Type:
  Geometry{blades: Array<Blade>, triangles: Array<M.Triangle>}
def blade(~high: Bool,+i: U32, tris: Array<M.Triangle>, r: Array<Blade> & Blade) -> Geometry:
  (blades,+b) = r
  Geometry{blades,blossom(~high,flower(i),i,b,segment(~high,i,b,2,segment(~high,i,b,1,segment(~high,i,b,0,tris))))}
def geometry_loop(~high: Bool,n: Nat, +i: U32, g: Geometry) -> Geometry:
  match n:
    case 0n: g
    case 1n+k:
      Geometry{blades,tris} = g
      geometry_loop(~high,k,(i + 1 : U32),blade(~high,i,tris,Array.get(Blade,blades,i)))
def geometry_leaf(~high: Bool,i: U32, n: U32, g: Geometry) -> Geometry:
  geometry_loop(~high,U32.to_nat(n),i,g)
def geometry_join(a: Geometry, b: Geometry) -> Geometry:
  Geometry{ab,at} = a
  Geometry{bb,bt} = b
  Geometry{Array.join(Blade,ab,bb),Array.join(M.Triangle,at,bt)}
def geometry(~high: Bool,depth: Nat, g: Geometry) -> Geometry:
  Region.run(~Geometry,~geometry_leaf(~high),~geometry_join,depth,0,4096,g)
def project_size(~high: Bool,gpu: Bool, g: Geometry) -> Geometry:
  match gpu:
    case True{}: geometry!(~high,12n,g)
    case False{}: geometry(~high,6n,g)

def project(gpu: Bool, g: Geometry) -> Geometry:
  project_size(~False{},gpu,g)
def background(x: U32, y: U32) -> M.Fragment:
  background_size(~False{},x,y)
