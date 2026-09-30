import Base
import ../demos/camera_lab/app.bend as App
import ../demos/camera_lab/input.bend as Input
import ../demos/voxels/landscape.bend as Land
import ../engine/camera_controls.bend as Controls
import ../engine/render/project.bend as P
import ../engine/render/batch.bend as B
import ../engine/render/scene.bend as Render
import ../engine/profile/frame.bend as Profile
import ../engine/platform/arguments.bend as Arguments
import ../engine/spatial/layout.bend as L
import ./image_dump.bend as Dump

def scripted(ortho: Bool, quality: U32, +tick: U32, c: Input.Input) -> Input.Input:
  Input.Input{Input.Rig{Controls.Orbit{target,yaw,pitch,distance},fly,flight,_},_,_,_,_,_,_,_,_,_} = c
  Input.Input{Input.Rig{Controls.Orbit{target,(yaw + U32.to_f32(tick) * 0.004 : F32),pitch,distance},fly,flight,ortho},0,False{},True{},quality,False{},0.5,0.5,(U32.to_f32(tick) / 60.0 : F32),False{}}
def controls(voxels: Bool, ortho: Bool, quality: U32, tick: U32) -> Input.Input:
  scripted(ortho,quality,tick,Input.initial(voxels))
def snapshot_result(r: App.FrameResult) -> IO(Unit):
  App.FrameResult{_,Render.Frame{Render.Target{_,pixels,_,level,_},_,_,_},_} = r
  Dump.image(Render.width(level),pixels)
def snapshot(+voxels: Bool, ortho: Bool, +quality: U32, tick: U32) -> IO(Unit):
  do IO<Unit>:
    r : App.FrameResult <- App.frame(controls(voxels,ortho,quality,tick),App.create(voxels),B.create(1024),Render.create(quality,L.word(voxels,15527913,16777215)),Pix{16777215})
    snapshot_result(r)
def edit(on: Bool, world: App.World) -> App.World:
  match on:
    case False{}: world
    case True{}:
      match world:
        case App.SculptureWorld{}: App.SculptureWorld{}
        case App.VoxelWorld{s}: App.VoxelWorld{Land.blast(125n,L.Point{8.0,5.0,16.0},s)}
def frames(n: Nat, +voxels: Bool, +ortho: Bool, +quality: U32, +warm: U32, +tick: U32, r: App.FrameResult) -> IO(Unit):
  match n:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+k:
      App.FrameResult{world,Render.Frame{target,B.Batch{tris,+count,capacity},image,profile},rebuilt} = r
      do IO<Unit>:
        Unit <- Bool.pick(IO(Unit),(tick >= warm : U32),IO.print(U32.show(tick) ++ "," ++ U32.show(count) ++ "," ++ U32.show(rebuilt) ++ "," ++ Profile.csv(profile)),IO.pure(Unit,Unit{}))
        next : App.FrameResult <- App.frame(controls(voxels,ortho,quality,(tick + 1 : U32)),edit(U32.is_eq(tick,warm),world),B.Batch{tris,count,capacity},target,image)
        frames(k,voxels,ortho,quality,warm,(tick + 1 : U32),next)
def bench(+voxels: Bool, +ortho: Bool, +quality: U32, +warm: U32, samples: U32) -> IO(Unit):
  do IO<Unit>:
    Unit <- IO.print("frame,triangles,rebuilt," ++ Profile.csv_header())
    first : App.FrameResult <- App.frame(controls(voxels,ortho,quality,0),App.create(voxels),B.create(1024),Render.create(quality,L.word(voxels,15527913,16777215)),Pix{16777215})
    frames(U32.to_nat((warm + samples : U32)),voxels,ortho,quality,warm,0,first)
def run(mode: String, +voxels: Bool, +ortho: Bool, +quality: U32, warm: Maybe<&2,U32>, count: Maybe<&2,U32>) -> IO(Unit):
  match mode warm count:
    case "snapshot" _ Some{tick}: snapshot(voxels,ortho,quality,tick)
    case "bench" Some{w} Some{n}: bench(voxels,ortho,quality,U32.min(w,10000),U32.min(n,10000))
    case _ _ _: IO.die(Unit,64,"invalid mode or unsigned frame counts")
def size_args(mode: String, voxels: Bool, ortho: Bool, size: String, warm: String, count: String) -> IO(Unit):
  match size:
    case "512": run(mode,voxels,ortho,0,U32.read(warm),U32.read(count))
    case "1024": run(mode,voxels,ortho,1,U32.read(warm),U32.read(count))
    case "2048": run(mode,voxels,ortho,2,U32.read(warm),U32.read(count))
    case _: IO.die(Unit,64,"resolution must be 512, 1024 or 2048")
def projection_args(mode: String, voxels: Bool, projection: String, size: String, warm: String, count: String) -> IO(Unit):
  match projection:
    case "perspective": size_args(mode,voxels,False{},size,warm,count)
    case "ortho": size_args(mode,voxels,True{},size,warm,count)
    case _: IO.die(Unit,64,"projection must be perspective or ortho")
def scene_args(mode: String, scene: String, projection: String, size: String, warm: String, count: String) -> IO(Unit):
  match scene:
    case "mono": projection_args(mode,False{},projection,size,warm,count)
    case "voxel": projection_args(mode,True{},projection,size,warm,count)
    case _: IO.die(Unit,64,"scene must be mono or voxel")
def args(xs: List<String>) -> IO(Unit):
  match xs:
    case mode <> scene <> projection <> size <> warm <> count <> Nil{}:
      scene_args(mode,scene,projection,size,warm,count)
    case _: IO.die(Unit,64,"usage: camera -- snapshot|bench mono|voxel perspective|ortho 512|1024|2048 WARMUP FRAMES_OR_TICK")
def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- Arguments.read()
    args(xs)
