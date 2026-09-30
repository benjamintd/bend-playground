import Base
import ../../engine/camera.bend as C
import ../../engine/camera_controls.bend as Controls
import ../../engine/spatial/layout.bend as L
import ../../engine/core/vec3.bend as V
import ../../engine/render/scene.bend as Render

type Rig is Data:
  Rig{orbit: Controls.Orbit, fly: Controls.Fly, flight: Bool, orthographic: Bool}
type Input is Data:
  Input{rig: Rig, keys: U32, paused: Bool, gpu: Bool, quality: U32, dragging: Bool, mx: F32, my: F32, time: F32, quit: Bool}
def initial(+voxels: Bool) -> Input:
  +target = {L.Point{L.pick(voxels,16.0,0.0),L.pick(voxels,3.5,1.6),L.pick(voxels,16.0,0.0)} : L.Point}
  Input{Rig{Controls.Orbit{target,0.75,0.48,L.pick(voxels,44.0,12.0)},Controls.Fly{L.Point{40.0,22.0,40.0},F32.neg(2.39),F32.neg(0.5)},False{},False{}},0,False{},True{},1,False{},0.5,0.5,0.0,False{}}
def lens(o: Bool, distance: F32) -> C.Camera:
  match o:
    case False{}: C.perspective(52.0,0.08,250.0)
    case True{}: C.orthographic((distance * 0.975465 : F32),0.08,250.0)
def camera_mode(flight: Bool, orbit: Controls.Orbit, fly: Controls.Fly, c: C.Camera) -> C.Camera:
  match flight:
    case False{}: Controls.orbit_camera(c,orbit)
    case True{}: Controls.fly_camera(c,fly)
def camera(r: Rig) -> C.Camera:
  Rig{+orbit,fly,flight,o} = r
  Controls.Orbit{_,_,_,distance} = orbit
  camera_mode(flight,orbit,fly,lens(o,distance))
def viewport(quality: U32, w: F32, h: F32) -> C.Viewport:
  +pixels = U32.to_f32(Render.width(quality))
  C.viewport(w,h,pixels,pixels)
# The app owns valid bounded lens/pose inputs. Public callers use C.prepare and
# handle None; no per-vertex camera validation or boxed camera on the GPU.
def view(+c: Input) -> C.View:
  Input{rig,_,_,_,quality,_,_,_,_,_} = c
  C.prepare_unchecked(camera(rig),viewport(quality,1.0,1.0))
def flag(code: U32) -> U32:
  match code:
    case 119: 1
    case 115: 2
    case 97: 4
    case 100: 8
    case 101: 16
    case 99: 32
    case 106: 64
    case 108: 128
    case 105: 256
    case 107: 512
    case 32: 1024
    case 113: 2048
    case 103: 4096
    case 111: 8192
    case 102: 16384
    case 27: 32768
    case _: 0
def axis(+keys: U32, positive: U32, negative: U32) -> F32:
  (L.pick(U32.is_ne(U32.and(keys,positive),0),1.0,0.0) - L.pick(U32.is_ne(U32.and(keys,negative),0),1.0,0.0) : F32)
def move_mode(+flight: Bool, o: Bool, orbit: Controls.Orbit, fly: Controls.Fly, +keys: U32, +dx: F32, +dy: F32, +dt: F32) -> Rig:
  match flight:
    case False{}: Rig{Controls.orbit_step(orbit,Controls.Motion{(dx + axis(keys,128,64) : F32),(dy + axis(keys,256,512) : F32),
      (axis(keys,2,1) * 0.9 : F32),(axis(keys,8,4) * 0.35 : F32),(axis(keys,16,32) * 0.35 : F32)},dt),fly,flight,o}
    case True{}: Rig{orbit,Controls.fly_step(fly,F32.neg((dx + axis(keys,128,64) : F32)),F32.neg((dy + axis(keys,256,512) : F32)),
      (axis(keys,1,2) * 10.0 : F32),(axis(keys,8,4) * 10.0 : F32),(axis(keys,16,32) * 10.0 : F32),dt),flight,o}
def move_rig(r: Rig, +keys: U32, +dx: F32, +dy: F32, +dt: F32) -> Rig:
  Rig{orbit,fly,flight,o} = r
  move_mode(flight,o,orbit,fly,keys,dx,dy,dt)
def advance(c: Input, +dt: F32) -> Input:
  Input{rig,+keys,+paused,gpu,q,drag,x,y,time,quit} = c
  Input{move_rig(rig,keys,0.0,0.0,dt),keys,paused,gpu,q,drag,x,y,(time + L.pick(paused,0.0,dt) : F32),quit}
def rotate(on: Bool, rig: Rig, dx: F32, dy: F32) -> Rig:
  match on:
    case False{}: rig
    case True{}: move_rig(rig,0,(dx * 4.0 : F32),(dy * 4.0 : F32),1.0)
def pointer(c: Input, +x: F32, +y: F32) -> Input:
  Input{rig,keys,p,g,q,+drag,oldx,oldy,t,quit} = c
  Input{rotate(drag,rig,(oldx - x : F32),(y - oldy : F32)),keys,p,g,q,drag,x,y,t,quit}
def dragging(c: Input, down: Bool, x: F32, y: F32) -> Input:
  Input{rig,k,p,g,q,_,_,_,t,quit} = c
  Input{rig,k,p,g,q,down,x,y,t,quit}
def projection(c: Input) -> Input:
  Input{Rig{orbit,fly,flight,o},k,p,g,q,d,x,y,t,quit} = c
  Input{Rig{orbit,fly,flight,Bool.not(o)},k,p,g,q,d,x,y,t,quit}
def switched_direction(flight: Bool, orthographic: Bool, +distance: F32, +eye: L.Point, +forward: L.Point) -> Rig:
  L.Point{+x,+y,+z} = forward
  Rig{Controls.Orbit{V.add(eye,V.mul(forward,distance)),F32.atan2(F32.neg(x),F32.neg(z)),F32.asin(F32.neg(y)),distance},
    Controls.Fly{eye,F32.atan2(x,z),F32.asin(y)},Bool.not(flight),orthographic}
def switched(flight: Bool, orthographic: Bool, distance: F32, c: C.Camera) -> Rig:
  C.Camera{_,+eye,+target,_,_,_,_} = c
  switched_direction(flight,orthographic,distance,eye,V.unit(V.sub(target,eye)))
def switch_rig(+r: Rig) -> Rig:
  Rig{Controls.Orbit{_,_,_,distance},_,flight,o} = r
  switched(flight,o,distance,camera(r))
def key_toggle(code: U32, c: Input) -> Input:
  match code:
    case 111: projection(c)
    case 102:
      Input{rig,k,p,g,q,d,x,y,t,quit} = c
      Input{switch_rig(rig),k,p,g,q,d,x,y,t,quit}
    case 32:
      Input{rig,k,p,g,q,d,x,y,t,quit} = c
      Input{rig,k,Bool.not(p),g,q,d,x,y,t,quit}
    case 103:
      Input{rig,k,p,g,q,d,x,y,t,quit} = c
      Input{rig,k,p,Bool.not(g),q,d,x,y,t,quit}
    case 113:
      Input{rig,k,p,g,+q,d,x,y,t,quit} = c
      Input{rig,k,p,g,L.word(U32.is_eq(q,1),2,1),d,x,y,t,quit}
    case 27:
      Input{rig,k,p,g,q,d,x,y,t,_} = c
      Input{rig,k,p,g,q,d,x,y,t,True{}}
    case _: c
def key_pressed(down: Bool, code: U32, c: Input) -> Input:
  match down:
    case False{}: c
    case True{}: key_toggle(code,c)
def key(+code: U32, +down: Bool, c: Input) -> Input:
  Input{rig,+keys,p,g,q,d,x,y,t,quit} = c
  +mask = flag(code)
  key_pressed(down && U32.is_eq(U32.and(keys,mask),0),code,Input{rig,L.word(down,U32.or(keys,mask),U32.and(keys,U32.xor(mask,4294967295))),p,g,q,d,x,y,t,quit})
