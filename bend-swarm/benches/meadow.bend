import Base
import ../demos/meadow/main.bend as App
import ../engine/platform/player.bend as Player
import ../engine/core/time.bend as Time

def report(on: Bool, elapsed: U32, r: App.State & Image & Player.Metrics) -> IO(App.State & Image):
  (s,image,Player.Metrics{sim,draw,_}) = r
  do IO<App.State & Image>:
    Unit <- Bool.pick(IO(Unit),on,IO.print(U32.show(sim) ++ "," ++ U32.show(draw) ++ "," ++ U32.show(elapsed)),IO.pure(Unit,Unit{}))
    return (s,image)
def frames_quality(+gpu: Bool, +high: Bool, +aa: Bool, +dof: Bool, n: Nat, +tick: U32, +warm: U32, r: App.State & Image) -> IO(App.State & Image):
  match n:
    case 0n: IO.pure(App.State & Image,r)
    case 1n+k:
      (s,image) = r
      do IO<App.State & Image>:
        start : Nat <- Time.micros()
        result : App.State & Image & Player.Metrics <- App.frame(Player.Input{gpu,False{},False{},False{},False{},1,42,0.5,0.5,0.0,(U32.to_f32(tick) / 60.0 : F32),aa,dof,high},s,image)
        end : Nat <- Time.micros()
        r : App.State & Image <- report((tick >= warm : U32),Time.elapsed(start,end),result)
        frames_quality(gpu,high,aa,dof,k,(tick + 1 : U32),warm,r)
def bench_quality(gpu: Bool, aa: Bool, dof: Bool, high: Bool) -> IO(Unit):
  do IO<Unit>:
    s : App.State <- App.create(1,42)
    Unit <- IO.print("simulation_us,render_us,frame_us")
    r : App.State & Image <- frames_quality(gpu,high,aa,dof,720n,0,120,(s,Pix{0}))
    return Unit{}
def frames(gpu: Bool, aa: Bool, dof: Bool, n: Nat, tick: U32, warm: U32, r: App.State & Image) -> IO(App.State & Image):
  frames_quality(gpu,False{},aa,dof,n,tick,warm,r)
def bench(gpu: Bool, aa: Bool, dof: Bool) -> IO(Unit):
  bench_quality(gpu,aa,dof,False{})
def args(xs: List<String>) -> IO(Unit):
  match xs:
    case "cpu" <> "raw" <> "high" <> Nil{}: bench_quality(False{},False{},False{},True{})
    case "cpu" <> "aa" <> "high" <> Nil{}: bench_quality(False{},True{},False{},True{})
    case "cpu" <> "dof" <> "high" <> Nil{}: bench_quality(False{},True{},True{},True{})
    case "gpu" <> "raw" <> "high" <> Nil{}: bench_quality(True{},False{},False{},True{})
    case "gpu" <> "aa" <> "high" <> Nil{}: bench_quality(True{},True{},False{},True{})
    case "gpu" <> "dof" <> "high" <> Nil{}: bench_quality(True{},True{},True{},True{})
    case "gpu" <> "raw" <> Nil{}: bench(True{},False{},False{})
    case "gpu" <> "aa" <> Nil{}: bench(True{},True{},False{})
    case "gpu" <> "dof" <> Nil{}: bench(True{},True{},True{})
    case "cpu" <> "raw" <> Nil{}: bench(False{},False{},False{})
    case "cpu" <> "dof" <> Nil{}: bench(False{},True{},True{})
    case _: bench(False{},True{},False{})
def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- IO.args()
    args(xs)
