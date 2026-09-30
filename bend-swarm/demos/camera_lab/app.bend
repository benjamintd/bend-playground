import Base
import ./input.bend as Input
import ../monochrome/scene.bend as Sculpture
import ../voxels/landscape.bend as Land
import ../../engine/camera.bend as C
import ../../engine/render/project.bend as P
import ../../engine/render/batch.bend as B
import ../../engine/render/scene.bend as Render
import ../../engine/profile/frame.bend as Profile
import ../../engine/parallel/policy.bend as Policy
import ../../engine/platform/viewport.bend as Viewport
import ../../engine/platform/crisp.bend as Crisp
import ../../engine/core/time.bend as Time
import ../../engine/spatial/layout.bend as L

type World is Type:
  SculptureWorld{}
  VoxelWorld{landscape: Land.Landscape}
type FrameResult is Type:
  FrameResult{world: World, frame: Render.Frame, rebuilt: U32}
def create(voxels: Bool) -> World:
  match voxels:
    case False{}: SculptureWorld{}
    case True{}: VoxelWorld{Land.create()}
def title(voxels: Bool) -> String:
  Bool.pick(String,voxels,"BEND / VOXEL LANDSCAPE","BEND / BLACK & WHITE")
def help(+voxels: Bool) -> String:
  title(voxels) ++ "\nO perspective / orthographic | F orbit / fly | Q 1024 / 2048 | G CPU / Metal\n"
    ++ "W/S zoom or fly | A/D pan or strafe | E/C up/down | I/J/K/L look\nSPACE pause | R reset | ESC close\n"
    ++ Bool.pick(String,voxels,"LEFT CLICK carve | RIGHT CLICK add | MIDDLE DRAG look","DRAG to orbit / look")
def clean(world: World) -> World:
  match world:
    case SculptureWorld{}: SculptureWorld{}
    case VoxelWorld{s}: VoxelWorld{Land.clean(s)}
def geometry(world: World, view: C.View, time: F32, out: B.Batch) -> World & B.Batch & U32:
  match world:
    case SculptureWorld{}: (SculptureWorld{},P.triangles(Sculpture.triangles(time),view,out),0)
    case VoxelWorld{Land.Landscape{world,+cache,dirty,+rebuilt}}:
      (VoxelWorld{Land.Landscape{world,cache,dirty,rebuilt}},Land.draw(cache,view,out),rebuilt)
def result(world: World, rebuilt: U32, frame: Render.Frame) -> FrameResult:
  FrameResult{world,frame,rebuilt}
def projected(gpu: Bool, sim: U32, start: Nat, target: Render.Target, old: Image,
  r: World & B.Batch & U32) -> IO(FrameResult):
  (world,batch,rebuilt) = r
  do IO<FrameResult>:
    end : Nat <- Time.micros()
    frame : Render.Frame <- Render.draw(gpu,sim,Time.elapsed(start,end),batch,target,old)
    return result(world,rebuilt,frame)
def frame(+c: Input.Input, world: World, batch: B.Batch, target: Render.Target, old: Image) -> IO(FrameResult):
  Input.Input{_,_,_,+gpu,+quality,_,_,_,time,_} = c
  do IO<FrameResult>:
    target : Render.Target = Render.resize(quality,target)
    start : Nat <- Time.micros()
    world : World = clean(world)
    +middle : Nat <- Time.micros()
    projected(gpu,Time.elapsed(start,middle),middle,target,old,
      geometry(world,Input.view(c),time,B.clear(batch)))
def pick(world: World, +c: Input.Input, x: F32, y: F32, add: Bool) -> World:
  match world:
    case SculptureWorld{}: SculptureWorld{}
    case VoxelWorld{s}:
      Input.Input{_,_,_,_,quality,_,_,_,_,_} = c
      +width = U32.to_f32(Render.width(quality))
      VoxelWorld{Land.pick(s,C.screen_ray(Input.view(c),(x * width : F32),(y * width : F32)),add)}
def mouse_pick(+c: Input.Input, world: World, x: F32, y: F32, add: Bool) -> Input.Input & World:
  (c,pick(world,c,x,y,add))
def mouse(voxels: Bool, down: Bool, button: U32, +x: F32, +y: F32, c: Input.Input, world: World) -> Input.Input & World:
  match voxels down button:
    case False{} _ _: (Input.dragging(c,down,x,y),world)
    case True{} _ 2: (Input.dragging(c,down,x,y),world)
    case True{} True{} 0: mouse_pick(Input.pointer(c,x,y),world,x,y,False{})
    case True{} True{} 1: mouse_pick(Input.pointer(c,x,y),world,x,y,True{})
    case _ _ _: (Input.pointer(c,x,y),world)
def reset_input(old: Input.Input, fresh: Input.Input) -> Input.Input:
  Input.Input{_,_,_,g,q,_,_,_,_,_} = old
  Input.Input{rig,_,p,_,_,_,x,y,_,quit} = fresh
  Input.Input{rig,0,p,g,q,False{},x,y,0.0,quit}
def event(e: Event, +voxels: Bool, +w: F32, +h: F32, c: Input.Input, world: World) -> Input.Input & World:
  match e:
    case Close{}: (Input.key(27,True{},c),world)
    case Key{114,True{}}: (reset_input(c,Input.initial(voxels)),create(voxels))
    case Key{code,down}: (Input.key(code,down,c),world)
    case Move{x,y}: (Input.pointer(c,(U32.to_f32(x) / w : F32),(U32.to_f32(y) / h : F32)),world)
    case Mouse{x,y,button,down}: mouse(voxels,down,button,(U32.to_f32(x) / w : F32),(U32.to_f32(y) / h : F32),c,world)
def events(es: List<Event>, +voxels: Bool, +w: F32, +h: F32, r: Input.Input & World) -> Input.Input & World:
  match es:
    case Nil{}: r
    case e <> rest:
      (c,world) = r
      events(rest,voxels,w,h,event(e,voxels,w,h,c,world))
def caption(voxels: Bool, c: Input.Input, count: U32, rebuilt: U32, sample: Profile.Sample) -> String:
  Input.Input{Input.Rig{_,_,flight,o},_,paused,_,q,_,_,_,_,_} = c
  Profile.Sample{Policy.Policy{_,_,_,gpu,_,_},sim,geo,bin,ras,_} = sample
  title(voxels) ++ Bool.pick(String,o," / ORTHO"," / PERSPECTIVE") ++ Bool.pick(String,flight," / FLY"," / ORBIT")
    ++ Bool.pick(String,paused," / PAUSED","") ++ Bool.pick(String,gpu," / METAL"," / CPU")
    ++ " / " ++ U32.show(Render.width(q)) ++ "px / " ++ U32.show(count) ++ " tris"
    ++ " / build " ++ Profile.ms((sim + geo + bin : U32)) ++ " draw " ++ Profile.ms(ras) ++ " ms"
    ++ " / " ++ U32.show(rebuilt) ++ " chunks / O F Q G R"
def paced(start: Nat) -> IO(Unit):
  do IO<Unit>:
    end : Nat <- Time.micros()
    IO.sleep(((16667 - U32.min(Time.elapsed(start,end),16667)) / 1000 : U32))
type Session is Type:
  Session{window: Window, world: World, controls: Input.Input, batch: B.Batch, target: Render.Target, image: Image, previous: Nat}
def session_events(window: Window, batch: B.Batch, target: Render.Target, image: Image, start: Nat, r: Input.Input & World) -> Session:
  (c,world) = r
  Session{window,world,c,batch,target,image,start}
def presented(voxels: Bool, c: Input.Input, batch: B.Batch, target: Render.Target, world: World, start: Nat, w: F32, h: F32,
  r: Window & Image & List<Event>) -> Session:
  (window,image,es) = r
  session_events(window,batch,target,image,start,events(es,voxels,w,h,(c,world)))
def show(+voxels: Bool, +c: Input.Input, +start: Nat, w: F32, h: F32, window: Window, r: FrameResult) -> IO(Session):
  Input.Input{_,_,_,_,q,_,_,_,_,_} = c
  FrameResult{world,Render.Frame{target,B.Batch{tris,+count,capacity},image,profile},rebuilt} = r
  do IO<Session>:
    window : Window <- Viewport.resolution(window,Render.width(q))
    window : Window <- Window.set_title(window,caption(voxels,c,count,rebuilt,profile))
    r : Window & Image & List<Event> <- Window.frame(window,image)
    Unit <- paced(start)
    return presented(voxels,c,B.Batch{tris,count,capacity},target,world,start,w,h,r)
def measured_window(voxels: Bool, +c: Input.Input, world: World, batch: B.Batch, target: Render.Target, image: Image, start: Nat,
  r: Window & U32 & U32) -> IO(Session):
  (window,w,h) = r
  do IO<Session>:
    result : FrameResult <- frame(c,world,batch,target,image)
    show(voxels,c,start,U32.to_f32(w),U32.to_f32(h),window,result)
def step(voxels: Bool, s: Session) -> IO(Session):
  Session{window,world,c,batch,target,image,previous} = s
  do IO<Session>:
    +start : Nat <- Time.micros()
    r : Window & U32 & U32 <- Viewport.dimensions(window)
    measured_window(voxels,Input.advance(c,F32.min(0.1,(U32.to_f32(Time.elapsed(previous,start)) / 1000000.0 : F32))),world,batch,target,image,start,r)
def loop(n: Nat, +voxels: Bool, s: Session) -> IO(Unit):
  match n:
    case 0n:
      Session{window,_,_,_,_,_,_} = s
      Window.close(window)
    case 1n+k:
      Session{window,world,+c,batch,target,image,previous} = s
      Input.Input{_,_,_,_,_,_,_,_,_,quit} = c
      match quit:
        case True{}: Window.close(window)
        case False{}:
          do IO<Unit>:
            next : Session <- step(voxels,Session{window,world,c,batch,target,image,previous})
            loop(k,voxels,next)
def run(+voxels: Bool) -> IO(Unit):
  do IO<Unit>:
    Unit <- IO.print(help(voxels))
    window : Window <- IO.try(Window,Window.open(title(voxels),640,640))
    window : Window <- Crisp.enable(window)
    now : Nat <- Time.micros()
    loop(4294967295n,voxels,Session{window,create(voxels),Input.initial(voxels),B.create(1024),Render.create(1,L.word(voxels,15527913,16777215)),Pix{16777215},now})
