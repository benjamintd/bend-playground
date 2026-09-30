import Base
import ../../demos/camera_lab/input.bend as I
import ../../demos/monochrome/scene.bend as Sculpture
import ../../demos/voxels/landscape.bend as Land
import ../../engine/render/project.bend as Project
import ../../engine/render/batch.bend as B
import ../../engine/camera.bend as C

type World is Type:
  SculptureWorld{}
  VoxelWorld{landscape: Land.Landscape}
type State is Type:
  State{world: World, controls: I.Input, batch: B.Batch}
def world(voxels: Bool) -> World:
  match voxels:
    case False{}: SculptureWorld{}
    case True{}: VoxelWorld{Land.create()}
def create(+voxels: Bool) -> State:
  State{world(voxels),I.initial(voxels),B.create(32768)}
def key(code: U32, down: Bool, s: State) -> State:
  State{w,c,b} = s
  State{w,I.key(code,down,c),b}
def pointer(x: F32, y: F32, s: State) -> State:
  State{w,c,b} = s
  State{w,I.pointer(c,x,y),b}
def dragging(down: Bool, x: F32, y: F32, s: State) -> State:
  State{w,c,b} = s
  State{w,I.dragging(c,down,x,y),b}
def picked(w: World, +c: I.Input, x: F32, y: F32, add: Bool) -> World:
  match w:
    case SculptureWorld{}: SculptureWorld{}
    case VoxelWorld{land}: VoxelWorld{Land.pick(land,C.screen_ray(I.view(c),(x * 1024.0 : F32),(y * 1024.0 : F32)),add)}
def pick(x: F32, y: F32, add: Bool, s: State) -> State:
  State{w,+c,b} = s
  State{picked(w,c,x,y,add),c,b}
def drawn(+c: I.Input, b: B.Batch, land: Land.Landscape) -> State:
  Land.Landscape{world,+cache,dirty,rebuilt} = land
  State{VoxelWorld{Land.Landscape{world,cache,dirty,rebuilt}},c,Land.draw(cache,I.view(c),b)}
def draw(w: World, +c: I.Input, b: B.Batch) -> State:
  match w:
    case SculptureWorld{}:
      I.Input{_,_,_,_,_,_,_,_,time,_} = c
      State{SculptureWorld{},c,Project.triangles(Sculpture.triangles(time),I.view(c),b)}
    case VoxelWorld{land}: drawn(c,b,Land.clean(land))
def frame(dt: F32, s: State) -> State:
  State{w,c,b} = s
  draw(w,I.advance(c,dt),B.clear(b))
