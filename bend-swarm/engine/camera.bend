import Base
import ./spatial/layout.bend as L
import ./core/vec3.bend as V

# Supported interface and units: docs/CAMERA_API.md. Other helpers are internal.
# Positive view Z, world +Y up, top-left pixel origin.
# Prepared views are host geometry data; they never enter raster/pixel loops.
type Lens is Data:
  Perspective{fov: F32, near: F32, far: F32}
  Orthographic{span: F32, near: F32, far: F32}
type Camera is Data:
  Camera{lens: Lens, eye: L.Point, target: L.Point, up: L.Point, zoom: F32, offset_x: F32, offset_y: F32}
type Viewport is Data:
  Viewport{x: F32, y: F32, width: F32, height: F32, pixels_x: F32, pixels_y: F32}
type View is Data:
  View{eye: L.Point, right: L.Point, up: L.Point, forward: L.Point,
    scale: F32, cx: F32, cy: F32, width: F32, height: F32, near: F32, far: F32, orthographic: Bool}
type Projection is Data:
  Projection{x: F32, y: F32, depth: F32, visible: Bool}
type Ray is Data:
  Ray{origin: L.Point, direction: L.Point, minimum: F32, maximum: F32}

def perspective(fov: F32, near: F32, far: F32) -> Camera:
  Camera{Perspective{fov,near,far},L.Point{0.0,0.0,5.0},V.zero(),L.Point{0.0,1.0,0.0},1.0,0.0,0.0}
def orthographic(span: F32, near: F32, far: F32) -> Camera:
  Camera{Orthographic{span,near,far},L.Point{0.0,0.0,5.0},V.zero(),L.Point{0.0,1.0,0.0},1.0,0.0,0.0}
def look_at(c: Camera, eye: L.Point, target: L.Point, up: L.Point) -> Camera:
  Camera{lens,_,_,_,zoom,ox,oy} = c
  Camera{lens,eye,target,up,zoom,ox,oy}
def zoom(c: Camera, zoom: F32) -> Camera:
  Camera{lens,eye,target,up,_,ox,oy} = c
  Camera{lens,eye,target,up,zoom,ox,oy}
def offset(c: Camera, x: F32, y: F32) -> Camera:
  Camera{lens,eye,target,up,zoom,_,_} = c
  Camera{lens,eye,target,up,zoom,x,y}
def viewport(width: F32, height: F32, pixels_x: F32, pixels_y: F32) -> Viewport:
  Viewport{0.0,0.0,width,height,pixels_x,pixels_y}
def finite(+x: F32) -> Bool:
  (F32.abs(x) < 1.0e30 : F32)
def finite_point(p: L.Point) -> Bool:
  L.Point{x,y,z} = p
  finite(x) && finite(y) && finite(z)
def valid_viewport(v: Viewport) -> Bool:
  Viewport{+x,+y,+w,+h,+px,+py} = v
  finite(x) && finite(y) && finite(w) && finite(h) && finite(px) && finite(py)
    && (w > 0.0 : F32) && (h > 0.0 : F32) && (px > 0.0 : F32) && (py > 0.0 : F32)
    && finite((x + w : F32)) && finite((y + h : F32))
def pointer_valid(valid: Bool, v: Viewport, x: F32, y: F32) -> Maybe<&2, L.Point>:
  match valid:
    case False{}: None{}
    case True{}:
      Viewport{ox,oy,w,h,px,py} = v
      Some{L.Point{((x - ox) / w * px : F32),((y - oy) / h * py : F32),0.0}}
def pointer(+v: Viewport, +x: F32, +y: F32) -> Maybe<&2, L.Point>:
  Viewport{+ox,+oy,+w,+h,_,_} = v
  pointer_valid(valid_viewport(v) && finite(x) && finite(y) && (x >= ox : F32) && (y >= oy : F32)
    && (x < ox + w : F32) && (y < oy + h : F32),v,x,y)
def valid_lens(l: Lens) -> Bool:
  match l:
    case Perspective{+f,+n,+z}:
      (f > 0.1 : F32) && (f < 179.0 : F32) && (n >= 0.0001 : F32) && (z > n : F32) && (z <= 100000.0 : F32)
    case Orthographic{+s,+n,+z}:
      (s > 0.0001 : F32) && finite(s) && (n >= 0.0001 : F32) && (z > n : F32) && (z <= 100000.0 : F32)
def lens_values(l: Lens, +height: F32, +zoom: F32) -> F32 & F32 & F32 & Bool:
  match l:
    case Perspective{f,n,z}: ((height * zoom / (2.0 * F32.tan((f * 0.00872664626 : F32))) : F32),n,z,False{})
    case Orthographic{s,n,z}: ((height * zoom / s : F32),n,z,True{})
def right_or(valid: Bool, +forward: L.Point, r: L.Point) -> L.Point:
  match valid:
    case True{}: V.unit(r)
    case False{}:
      L.Point{_,+y,_} = forward
      V.unit(V.cross(forward,L.Point{L.pick((F32.abs(y) > 0.9 : F32),1.0,0.0),L.pick((F32.abs(y) > 0.9 : F32),0.0,1.0),0.0}))
def safe_right(+forward: L.Point, up: L.Point) -> L.Point:
  +r = V.cross(forward,up)
  right_or((V.length(r) > 0.00001 : F32),forward,r)
def prepared_values(eye: L.Point, +right: L.Point, +forward: L.Point, +w: F32, +h: F32, ox: F32, oy: F32, values: F32 & F32 & F32 & Bool) -> View:
  (s,n,z,o) = values
  View{eye,right,V.cross(right,forward),forward,s,(w * (0.5 + ox) : F32),(h * (0.5 + oy) : F32),w,h,n,z,o}
# Explicit fast path for trusted inputs satisfying prepare's complete contract.
def prepare_unchecked(c: Camera, v: Viewport) -> View:
  Camera{lens,+eye,target,up,zoom,ox,oy} = c
  Viewport{_,_,_,_,+w,+h} = v
  +forward = V.unit(V.sub(target,eye))
  +right = safe_right(forward,up)
  prepared_values(eye,right,forward,w,h,ox,oy,lens_values(lens,h,zoom))
def view_result(valid: Bool, view: View) -> Maybe<&2, View>:
  match valid:
    case False{}: None{}
    case True{}: Some{view}
def checked_view(+view: View) -> Maybe<&2, View>:
  View{_,_,_,_,+s,+cx,+cy,+w,+h,_,_,_} = view
  +x = F32.max(F32.abs(cx),F32.abs((w - cx : F32)))
  +y = F32.max(F32.abs(cy),F32.abs((h - cy : F32)))
  view_result((s > 0.0 : F32) && (s * s > 0.0 : F32) && finite(s) && finite(cx) && finite(cy)
    && finite(V.length(L.Point{s,x,y})) && finite(V.length(L.Point{(x / s : F32),(y / s : F32),1.0})),view)
# Validate both inputs and derived scales/extents: finite inputs alone can
# overflow or underflow F32 projection, clipping and inverse projection math.
def prepare_valid(valid: Bool, c: Camera, v: Viewport) -> Maybe<&2, View>:
  match valid:
    case False{}: None{}
    case True{}: checked_view(prepare_unchecked(c,v))
def prepare(+c: Camera, +v: Viewport) -> Maybe<&2, View>:
  Camera{lens,+eye,+target,+up,+zoom,+ox,+oy} = c
  prepare_valid(valid_lens(lens) && finite_point(eye) && finite_point(target) && finite_point(up)
    && (V.length(V.sub(target,eye)) > 0.00001 : F32) && finite(V.length(V.sub(target,eye)))
    && (V.length(up) > 0.00001 : F32) && finite(V.length(up))
    && (zoom > 0.0001 : F32) && (zoom < 10000.0 : F32) && finite(ox) && finite(oy)
    && valid_viewport(v),c,v)
def view_point(view: View, p: L.Point) -> L.Point:
  View{eye,right,up,forward,_,_,_,_,_,_,_,_} = view
  +d = V.sub(p,eye)
  L.Point{V.dot(d,right),V.dot(d,up),V.dot(d,forward)}
def world_point(view: View, p: L.Point) -> L.Point:
  View{eye,right,up,forward,_,_,_,_,_,_,_,_} = view
  L.Point{x,y,z} = p
  V.add(eye,V.add(V.mul(right,x),V.add(V.mul(up,y),V.mul(forward,z))))
def project_view(view: View, p: L.Point) -> Projection:
  View{_,_,_,_,+s,cx,cy,w,h,n,f,o} = view
  L.Point{x,y,+z} = p
  +scale = L.pick(o,s,(s / F32.max(z,0.0000001) : F32))
  +sx = (cx + x * scale : F32)
  +sy = (cy - y * scale : F32)
  Projection{sx,sy,z,(z >= n : F32) && (z <= f : F32) && (sx >= 0.0 : F32) && (sy >= 0.0 : F32)
    && (sx <= w : F32) && (sy <= h : F32)}
def project(+view: View, p: L.Point) -> Projection:
  project_view(view,view_point(view,p))
def unproject_at_depth(+view: View, x: F32, y: F32, +depth: F32) -> L.Point:
  View{_,_,_,_,+s,cx,cy,_,_,_,_,o} = view
  +d = L.pick(o,1.0,depth)
  world_point(view,L.Point{((x - cx) * d / s : F32),((cy - y) * d / s : F32),depth})
def screen_ray(+view: View, +x: F32, +y: F32) -> Ray:
  View{+eye,right,up,+forward,+scale,cx,cy,_,_,n,f,o} = view
  match o:
    case True{}: Ray{unproject_at_depth(view,x,y,0.0),forward,n,f}
    case False{}:
      +direction = V.unit(V.add(forward,V.add(V.mul(right,((x - cx) / scale : F32)),V.mul(up,((cy - y) / scale : F32)))))
      +cosine = V.dot(direction,forward)
      Ray{eye,direction,(n / cosine : F32),(f / cosine : F32)}
def ray_at(ray: Ray, distance: F32) -> L.Point:
  Ray{o,d,_,_} = ray
  V.add(o,V.mul(d,distance))

# Signed distances in view coordinates, deliberately unnormalized. Shared by
# clipping and conservative sphere rejection (radius scaled by plane length).
def plane(view: View, i: U32) -> L.Point & F32:
  View{_,_,_,_,+s,+cx,+cy,+w,+h,n,f,+o} = view
  match i:
    case 0: (L.Point{0.0,0.0,1.0},F32.neg(n))
    case 1: (L.Point{0.0,0.0,F32.neg(1.0)},f)
    case 2: (L.Point{s,0.0,L.pick(o,0.0,cx)},L.pick(o,cx,0.0))
    case 3: (L.Point{F32.neg(s),0.0,L.pick(o,0.0,(w - cx : F32))},L.pick(o,(w - cx : F32),0.0))
    case 4: (L.Point{0.0,F32.neg(s),L.pick(o,0.0,cy)},L.pick(o,cy,0.0))
    case _: (L.Point{0.0,s,L.pick(o,0.0,(h - cy : F32))},L.pick(o,(h - cy : F32),0.0))
def sphere_plane(center: L.Point, radius: F32, p: L.Point & F32) -> Bool:
  (+normal,offset) = p
  (V.dot(normal,center) + offset >= F32.neg((radius * V.length(normal) : F32)) : F32)
def sphere_planes(+n: Nat, +view: View, +center: L.Point, +radius: F32) -> Bool:
  match n:
    case 0n: True{}
    case 1n+k:
      sphere_plane(center,radius,plane(view,U32.from_nat(k))) && sphere_planes(k,view,center,radius)
def intersects_bounds(+view: View, +minimum: L.Point, +maximum: L.Point) -> Bool:
  sphere_planes(6n,view,view_point(view,V.mul(V.add(minimum,maximum),0.5)),(V.length(V.sub(maximum,minimum)) * 0.5 : F32))
