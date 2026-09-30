import Base
import ./camera.bend as C
import ./core/vec3.bend as V
import ./spatial/layout.bend as L

# Pure controls, independent of native key codes and simulation pause state.
# Angles and angular velocities are radians; dt is seconds.
type Orbit is Data:
  Orbit{target: L.Point, yaw: F32, pitch: F32, distance: F32}
type Motion is Data:
  Motion{yaw: F32, pitch: F32, dolly: F32, pan_x: F32, pan_y: F32}
type Fly is Data:
  Fly{eye: L.Point, yaw: F32, pitch: F32}
def direction(+yaw: F32, +pitch: F32) -> L.Point:
  L.Point{(F32.sin(yaw) * F32.cos(pitch) : F32),F32.sin(pitch),(F32.cos(yaw) * F32.cos(pitch) : F32)}
def orbit_camera(c: C.Camera, orbit: Orbit) -> C.Camera:
  Orbit{+target,yaw,pitch,distance} = orbit
  C.look_at(c,V.add(target,V.mul(direction(yaw,pitch),distance)),target,L.Point{0.0,1.0,0.0})
def orbit_step(o: Orbit, m: Motion, +dt: F32) -> Orbit:
  Orbit{target,+yaw,pitch,+distance} = o
  Motion{dy,dp,dolly,px,py} = m
  +right = {L.Point{F32.cos(yaw),0.0,F32.neg(F32.sin(yaw))} : L.Point}
  Orbit{V.add(target,V.add(V.mul(right,(px * dt * distance : F32)),L.Point{0.0,(py * dt * distance : F32),0.0})),
    (yaw + dy * dt : F32),F32.clamp((pitch + dp * dt : F32),F32.neg(1.55),1.55),
    F32.clamp((distance * F32.exp((dolly * dt : F32)) : F32),0.2,250.0)}
def fly_camera(c: C.Camera, f: Fly) -> C.Camera:
  Fly{+eye,yaw,pitch} = f
  C.look_at(c,eye,V.add(eye,direction(yaw,pitch)),L.Point{0.0,1.0,0.0})
def fly_step(f: Fly, look_x: F32, look_y: F32, forward: F32, strafe: F32, rise: F32, +dt: F32) -> Fly:
  Fly{eye,yaw,pitch} = f
  +y = (yaw + look_x * dt : F32)
  +p = F32.clamp((pitch + look_y * dt : F32),F32.neg(1.55),1.55)
  Fly{V.add(eye,V.mul(V.add(V.mul(direction(y,p),forward),
    V.add(V.mul(L.Point{F32.neg(F32.cos(y)),0.0,F32.sin(y)},strafe),L.Point{0.0,rise,0.0})),dt)),y,p}
