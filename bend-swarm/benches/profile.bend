import Base
import ../engine/platform/arguments.bend as Arguments
import ../engine/platform/player.bend as Player
import ../engine/parallel/policy.bend as Policy
import ../engine/profile/frame.bend as Profile
import ../engine/core/time.bend as Time
import ../engine/render/post.bend as Post
import ../demos/cloth/frame.bend as Cloth
import ../demos/cloth/physics.bend as Physics
import ../demos/meadow/main.bend as Meadow

type Scene is Type:
  Cloth{frame: Cloth.Frame}
  Meadow{state: Meadow.State, image: Image}
def cloth_result(r: Cloth.Frame & Profile.Sample) -> Scene & Profile.Sample:
  (f,p) = r
  (Cloth{f},p)
def meadow_result(r: Meadow.State & Image & Player.Metrics) -> Scene & Profile.Sample:
  (s,image,m) = r
  match m:
    case Player.Measured{_,_,_,p}: (Meadow{s,image},p)
    case Player.Metrics{_,_,_}: (Meadow{s,image},Profile.empty())
def meadow_step(policy: Policy.Policy, settings: Post.Settings, high: Bool, tick: U32, s: Meadow.State, image: Image) -> IO(Scene & Profile.Sample):
  Post.Settings{aa,dof,_,_} = settings
  do IO<Scene & Profile.Sample>:
    r : Meadow.State & Image & Player.Metrics <- Meadow.frame_policy(policy,
      Player.Input{False{},False{},False{},False{},False{},1,42,0.5,0.5,0.0,(U32.to_f32(tick) / 60.0 : F32),aa,dof,high},s,image)
    return meadow_result(r)
def step(policy: Policy.Policy, settings: Post.Settings, high: Bool, tick: U32, s: Scene) -> IO(Scene & Profile.Sample):
  match s:
    case Cloth{f}:
      do IO<Scene & Profile.Sample>:
        r : Cloth.Frame & Profile.Sample <- Cloth.step_policy(settings,policy,False{},2n,
          Physics.Controls{32,4294967295,0.0,0.0,0.0,(U32.to_f32(tick) / 60.0 : F32),1.5},f)
        return cloth_result(r)
    case Meadow{s,image}: meadow_step(policy,settings,high,tick,s,image)
def report(on: Bool, elapsed: U32, r: Scene & Profile.Sample) -> IO(Scene):
  (s,p) = r
  do IO<Scene>:
    Unit <- Bool.pick(IO(Unit),on,IO.print(Profile.csv(p) ++ "," ++ U32.show(elapsed)),IO.pure(Unit,Unit{}))
    return s
def frames(n: Nat, +warm: U32, +tick: U32, +policy: Policy.Policy, +settings: Post.Settings, +high: Bool, s: Scene) -> IO(Unit):
  match n:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+k:
      do IO<Unit>:
        start : Nat <- Time.micros()
        r : Scene & Profile.Sample <- step(policy,settings,high,tick,s)
        end : Nat <- Time.micros()
        s : Scene <- report((tick >= warm : U32),Time.elapsed(start,end),r)
        frames(k,warm,(tick + 1 : U32),policy,settings,high,s)
def create(scene: String, high: Bool) -> IO(Scene):
  match scene:
    case "cloth":
      do IO<Scene>:
        f : Cloth.Frame <- Cloth.create(Bool.pick(Nat,high,6n,5n))
        return Cloth{f}
    case "meadow":
      do IO<Scene>:
        s : Meadow.State <- Meadow.create(1,42)
        return Meadow{s,Pix{0}}
    case _: IO.die(Scene,64,"scene must be cloth or meadow")
def run(scene: String, policy: Policy.Policy, settings: Post.Settings, +high: Bool, +warm: U32, samples: U32) -> IO(Unit):
  do IO<Unit>:
    s : Scene <- create(scene,high)
    Unit <- IO.print(Profile.csv_header() ++ ",frame_us")
    frames(U32.to_nat((U32.min(warm,100000) + U32.min(samples,100000) : U32)),U32.min(warm,100000),0,policy,settings,high,s)
def mode(scene: String, mode: String, settings: Post.Settings, high: Bool, warm: U32, samples: U32) -> IO(Unit):
  match mode:
    case "cpu": run(scene,Policy.all(False{},0n),settings,high,warm,samples)
    case "hybrid": run(scene,Policy.hybrid(),settings,high,warm,samples)
    case "render": run(scene,Policy.cloth(True{}),settings,high,warm,samples)
    case "gpu": run(scene,Policy.all(True{},10n),settings,high,warm,samples)
    case _: IO.die(Unit,64,"policy must be cpu, hybrid, render or gpu")
def effects(scene: String, policy: String, effect: String, high: Bool, warm: U32, samples: U32) -> IO(Unit):
  match effect:
    case "raw": mode(scene,policy,Post.Settings{False{},False{},7.5,4.0},high,warm,samples)
    case "aa": mode(scene,policy,Post.Settings{True{},False{},7.5,4.0},high,warm,samples)
    case "dof": mode(scene,policy,Post.Settings{True{},True{},7.5,4.0},high,warm,samples)
    case _: IO.die(Unit,64,"effect must be raw, aa or dof")
def size(scene: String, policy: String, effect: String, size: String, warm: U32, samples: U32) -> IO(Unit):
  match size:
    case "standard": effects(scene,policy,effect,False{},warm,samples)
    case "high": effects(scene,policy,effect,True{},warm,samples)
    case _: IO.die(Unit,64,"size must be standard or high")
def counts(scene: String, policy: String, effect: String, resolution: String, warm: Maybe<&2,U32>, samples: Maybe<&2,U32>) -> IO(Unit):
  match warm samples:
    case Some{w} Some{s}: size(scene,policy,effect,resolution,w,s)
    case _ _: IO.die(Unit,64,"warmup and sample counts must be unsigned integers")
def args(xs: List<String>) -> IO(Unit):
  match xs:
    case scene <> policy <> effect <> resolution <> warm <> samples <> Nil{}:
      counts(scene,policy,effect,resolution,U32.read(warm),U32.read(samples))
    case _: IO.die(Unit,64,"usage: profile -- cloth|meadow cpu|hybrid|render|gpu raw|aa|dof standard|high WARMUP SAMPLES")
def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- Arguments.read()
    args(xs)
