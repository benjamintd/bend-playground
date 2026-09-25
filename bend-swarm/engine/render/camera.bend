import Base
import ../spatial/layout.bend as L
import ../core/vec3.bend as V
import ./mesh.bend as M

# Template-specialized camera: no shared boxed camera in vertex/pixel loops.
type Camera is Data:
  Camera{eye: L.Point, right: L.Point, up: L.Point, forward: L.Point, focal: F32, cx: F32, cy: F32}
def basis(+eye: L.Point, +forward: L.Point, +right: L.Point, focal: F32, cx: F32, cy: F32) -> Camera:
  Camera{eye,right,V.cross(right,forward),forward,focal,cx,cy}
def look_at(+eye: L.Point, target: L.Point, focal: F32, cx: F32, cy: F32) -> Camera:
  +forward = V.unit(V.sub(target,eye))
  basis(eye,forward,V.unit(V.cross(forward,L.Point{0.0,1.0,0.0})),focal,cx,cy)
def project_value(camera: Camera, point: L.Point, light: F32) -> M.Vertex:
  Camera{eye,right,up,forward,focal,cx,cy} = camera
  +p = V.sub(point,eye)
  +depth = V.dot(p,forward)
  +s = (focal / F32.max(depth,0.001) : F32)
  M.Vertex{(cx + V.dot(p,right) * s : F32),(cy - V.dot(p,up) * s : F32),depth,light}
def ray_value(camera: Camera, x: F32, y: F32) -> L.Point:
  Camera{_,right,up,forward,+focal,cx,cy} = camera
  V.add(forward,V.add(V.mul(right,((x - cx) / focal : F32)),V.mul(up,((cy - y) / focal : F32))))
def along_value(camera: Camera, direction: L.Point, depth: F32) -> L.Point:
  Camera{eye,_,_,_,_,_,_} = camera
  V.add(eye,V.mul(direction,depth))

def project(~camera: Camera, point: L.Point, light: F32) -> M.Vertex:
  project_value(camera,point,light)
def ray(~camera: Camera, x: F32, y: F32) -> L.Point:
  ray_value(camera,x,y)
def along(~camera: Camera, direction: L.Point, depth: F32) -> L.Point:
  along_value(camera,direction,depth)
