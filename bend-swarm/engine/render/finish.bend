import Base
import ../core/time.bend as Time
import ./mesh.bend as Mesh
import ./post.bend as Post
import ./downsample.bend as Downsample
import ./coverage.bend as Coverage

def finished(tris: Array<Mesh.Triangle>, offsets: Array<U32>, ids: Array<U32>, r: Post.State & Image) -> Mesh.Drawing & Image:
  (Post.State{fragments,pixels,_},image) = r
  (Mesh.Drawing{tris,offsets,ids,pixels,fragments},image)
def post(~level: Nat, gpu: Bool, settings: Post.Settings, old: Image, b: Mesh.Drawing) -> Mesh.Drawing & Image:
  Mesh.Drawing{tris,offsets,ids,pixels,fragments} = b
  finished(tris,offsets,ids,Post.render_level(~level,gpu,Post.State{fragments,pixels,settings},old))
def present(~level: Nat, gpu: Bool, old: Image, b: Mesh.Drawing) -> Mesh.Drawing & Image:
  Mesh.Drawing{tris,offsets,ids,pixels,fragments} = b
  finished(tris,offsets,ids,Post.present_level(~level,gpu,Post.State{fragments,pixels,Post.Settings{False{},False{},0.0,0.0}},old))
def buffer(~level: Nat, aa: Bool, gpu: Bool, b: Mesh.Drawing) -> Mesh.Drawing:
  match aa:
    case False{}: Mesh.buffer_level(~level,gpu,b)
    case True{}: Coverage.render(~level,gpu,b)
def finish_buffer(~level: Nat, dof: Bool, gpu: Bool, focus: F32, aperture: F32, old: Image, b: Mesh.Drawing) -> Mesh.Drawing & Image:
  match dof:
    case False{}: present(~level,gpu,old,b)
    case True{}: post(~level,gpu,Post.Settings{False{},True{},focus,aperture},old,b)
# Both entry points use the same effect stages. The profiled path adds IO
# boundaries between them so mixed CPU/Metal dispatch remains valid.
def draw_effects(~level: Nat, effects: Bool, aa: Bool, dof: Bool, +gpu: Bool,
  focus: F32, aperture: F32, b: Mesh.Drawing, old: Image) -> Mesh.Drawing & Image:
  match effects:
    case False{}: Mesh.render_level(~level,gpu,b,old)
    case True{}: finish_buffer(~level,dof,gpu,focus,aperture,old,buffer(~level,aa,gpu,b))
def draw_level(~level: Nat, gpu: Bool, settings: Post.Settings, b: Mesh.Drawing, old: Image) -> Mesh.Drawing & Image:
  Post.Settings{+aa,+dof,focus,aperture} = settings
  draw_effects(~level,aa || dof,aa,dof,gpu,focus,aperture,b,old)
def draw(~high: Bool, gpu: Bool, settings: Post.Settings, b: Mesh.Drawing, old: Image) -> Mesh.Drawing & Image:
  draw_level(~Bool.pick(Nat,high,1n,0n),gpu,settings,b,old)

def reduced(tris: Array<Mesh.Triangle>, offsets: Array<U32>, ids: Array<U32>, fragments: Array<Mesh.Fragment>, r: Array<U32> & Image) -> Mesh.Drawing & Image:
  (pixels,image) = r
  (Mesh.Drawing{tris,offsets,ids,pixels,fragments},image)
def resolve(~output_level: Nat, on: Bool, gpu: Bool, r: Mesh.Drawing & Image) -> Mesh.Drawing & Image:
  match on:
    case False{}: r
    case True{}:
      (Mesh.Drawing{tris,offsets,ids,pixels,fragments},image) = r
      reduced(tris,offsets,ids,fragments,Downsample.render(~output_level,gpu,pixels,image))

# The profiled path uses the same kernels as draw_level. IO boundaries are also
# required when a CPU fork tree is followed by a GPU stage in a mixed policy.
def measured_effects(~level: Nat, effects: Bool, aa: Bool, dof: Bool, raster: Bool, post_gpu: Bool,
  focus: F32, aperture: F32, b: Mesh.Drawing, old: Image) -> IO((Mesh.Drawing & Image) & U32 & U32):
  match effects:
    case False{}:
      do IO<(Mesh.Drawing & Image) & U32 & U32>:
        start : Nat <- Time.micros()
        result : Mesh.Drawing & Image = Mesh.render_level(~level,raster,b,old)
        end : Nat <- Time.micros()
        return (result,Time.elapsed(start,end),0)
    case True{}:
      do IO<(Mesh.Drawing & Image) & U32 & U32>:
        start : Nat <- Time.micros()
        b : Mesh.Drawing = buffer(~level,aa,raster,b)
        +middle : Nat <- Time.micros()
        result : Mesh.Drawing & Image = finish_buffer(~level,dof,post_gpu,focus,aperture,old,b)
        end : Nat <- Time.micros()
        return (result,Time.elapsed(start,middle),Time.elapsed(middle,end))
def measured(~level: Nat, raster: Bool, post_gpu: Bool, settings: Post.Settings, b: Mesh.Drawing, old: Image) -> IO((Mesh.Drawing & Image) & U32 & U32):
  Post.Settings{+aa,+dof,focus,aperture} = settings
  measured_effects(~level,aa || dof,aa,dof,raster,post_gpu,focus,aperture,b,old)
