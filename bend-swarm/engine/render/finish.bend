import Base
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
def enabled(~level: Nat, effects: Bool, +gpu: Bool, settings: Post.Settings, b: Mesh.Drawing, old: Image) -> Mesh.Drawing & Image:
  match effects:
    case False{}: Mesh.render_level(~level,gpu,b,old)
    case True{}: post(~level,gpu,settings,old,Mesh.buffer_level(~level,gpu,b))
def covered(~level: Nat, aa: Bool, +gpu: Bool, settings: Post.Settings, b: Mesh.Drawing, old: Image) -> Mesh.Drawing & Image:
  match aa:
    case False{}: enabled(~level,True{},gpu,settings,b,old)
    case True{}:
      Post.Settings{_,dof,focus,aperture} = settings
      post(~level,gpu,Post.Settings{False{},dof,focus,aperture},old,Coverage.render(~level,gpu,b))
def effects(~level: Nat, on: Bool, aa: Bool, gpu: Bool, settings: Post.Settings, b: Mesh.Drawing, old: Image) -> Mesh.Drawing & Image:
  match on:
    case False{}: Mesh.render_level(~level,gpu,b,old)
    case True{}: covered(~level,aa,gpu,settings,b,old)
def draw_configured(~level: Nat, gpu: Bool, +settings: Post.Settings, b: Mesh.Drawing, old: Image) -> Mesh.Drawing & Image:
  Post.Settings{+aa,dof,_,_} = settings
  effects(~level,aa || dof,aa,gpu,settings,b,old)
def draw_level(~level: Nat, gpu: Bool, settings: Post.Settings, b: Mesh.Drawing, old: Image) -> Mesh.Drawing & Image:
  draw_configured(~level,gpu,settings,b,old)

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
