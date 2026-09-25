import Base
import ../demos/meadow/scene.bend as Meadow
import ../demos/life/simulation.bend as Life
import ./life.bend as LifeTest
import ./splats.bend as SplatTest
import ../engine/spatial.bend as Spatial
import ../engine/render/splats.bend as Splats
import ../engine/render/post.bend as Post
import ../engine/render/mesh.bend as M

def blade_row(i: U32, r: Array<Meadow.Blade> & Meadow.Blade) -> IO(Array<Meadow.Blade>):
  (a,Meadow.Blade{x,z,vx,vz}) = r
  do IO<Array<Meadow.Blade>>:
    Unit <- IO.print("grass," ++ U32.show(i) ++ "," ++ F32.show(x) ++ "," ++ F32.show(z) ++ "," ++ F32.show(vx) ++ "," ++ F32.show(vz))
    return a
def grass_rows(n: Nat, +i: U32, a: Array<Meadow.Blade>) -> IO(Unit):
  match n:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+k:
      do IO<Unit>:
        a : Array<Meadow.Blade> <- blade_row(i,Array.get(Meadow.Blade,a,i))
        grass_rows(k,(i + 1 : U32),a)
def grass_frames(n: Nat, +i: U32, a: Array<Meadow.Blade>) -> Array<Meadow.Blade>:
  match n:
    case 0n: a
    case 1n+k: grass_frames(k,(i + 1 : U32),Meadow.simulate(True{},False{},Meadow.Controls{(U32.to_f32(i) / 60.0 : F32),0.55,0.0,0.0,1.0},a))
def particle_row(preset: U32, i: U32, r: Array<Life.Particle> & Life.Particle) -> IO(Array<Life.Particle>):
  (a,Life.Particle{x,y,vx,vy}) = r
  do IO<Array<Life.Particle>>:
    Unit <- IO.print("life," ++ U32.show(preset) ++ "," ++ U32.show(i) ++ "," ++ F32.show(x) ++ "," ++ F32.show(y) ++ "," ++ F32.show(vx) ++ "," ++ F32.show(vy))
    return a
def life_rows(+preset: U32, n: Nat, +i: U32, a: Array<Life.Particle>) -> IO(Unit):
  match n:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+k:
      do IO<Unit>:
        a : Array<Life.Particle> <- particle_row(preset,i,Array.get(Life.Particle,a,i))
        life_rows(preset,k,(i + 1 : U32),a)
def life_result(preset: U32, r: Array<Life.Particle> & Array<Life.Particle> & Spatial.Index(Life.space()) & Spatial.Statistics) -> IO(Unit):
  (_,a,_,_) = r
  life_rows(preset,32n,0,a)
def life(+preset: U32) -> IO(Unit):
  do IO<Unit>:
    step : Spatial.Step(Life.space(),Array<Life.Particle>,Array<Life.Particle>) <- Spatial.require(~Spatial.Step(Life.space(),Array<Life.Particle>,Array<Life.Particle>),
      LifeTest.run(True{},Life.Controls{preset,42,0.0,0.0,1.0},LifeTest.fixture()))
    life_result(preset,Spatial.release(~Life.space(),~Array<Life.Particle>,~Array<Life.Particle>,step))
def fragment(+i: U32) -> M.Fragment:
  +x = (i % 512 : U32)
  +y = (i / 512 : U32)
  M.Fragment{Bool.pick(F32,(x < 256 : U32),10.0,20.0),Bool.pick(U32,U32.is_eq(U32.and((x / 8 + y / 8 : U32),1),0),16777215,2109504)}
def fill(n: Nat, +i: U32, a: Array<M.Fragment>) -> Array<M.Fragment>:
  match n:
    case 0n: a
    case 1n+k: fill(k,(i + 1 : U32),Array.set(M.Fragment,a,(262144 + i : U32),fragment(i)))
def post_pixel(i: U32, r: Array<U32> & U32) -> IO(Array<U32>):
  (a,c) = r
  do IO<Array<U32>>:
    Unit <- IO.print("post," ++ U32.show(i) ++ "," ++ U32.show(c))
    return a
def post_rows(n: Nat, +i: U32, a: Array<U32>) -> IO(Unit):
  match n:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+k:
      do IO<Unit>:
        a : Array<U32> <- post_pixel(i,Array.get(U32,a,i))
        post_rows(k,(i + 257 : U32),a)
def post_result(r: Post.State & Image) -> IO(Unit):
  (Post.State{_,p,_},_) = r
  post_rows(1021n,0,p)
def splat_read(r: U32, g: U32, b: U32, n: U32, value: Array<U32> & U32) -> Array<U32> & U32 & U32 & U32 & U32:
  (a,+c) = value
  (a,(r + U32.shrn(c,16n) : U32),(g + U32.and(U32.shrn(c,8n),255) : U32),(b + U32.and(c,255) : U32),
    (n + Bool.to_u32(U32.is_ne(c,263692)) : U32))
def splat_sum(n: Nat, +i: U32, r: Array<U32> & U32 & U32 & U32 & U32) -> Array<U32> & U32 & U32 & U32 & U32:
  match n:
    case 0n: r
    case 1n+k:
      (a,r,g,b,count) = r
      splat_sum(k,(i + 1 : U32),splat_read(r,g,b,count,Array.get(U32,a,i)))
def splat_print(r: Array<U32> & U32 & U32 & U32 & U32) -> IO(Unit):
  (_,r,g,b,n) = r
  IO.print("splats," ++ U32.show(r) ++ "," ++ U32.show(g) ++ "," ++ U32.show(b) ++ "," ++ U32.show(n))
def splat_result(r: Array<Splats.Splat> & Spatial.Index(Splats.space()) & Array<U32> & Image) -> IO(Unit):
  (_,_,p,_) = r
  splat_print(splat_sum(1048576n,0,(p,0,0,0,0)))
def main() -> IO(Unit):
  do IO<Unit>:
    Unit <- grass_rows(4096n,0,grass_frames(240n,0,Array.new(Meadow.Blade,12n,Meadow.Blade{0.0,0.0,0.0,0.0})))
    Unit <- life(0)
    Unit <- life(1)
    Unit <- life(2)
    Unit <- post_result(Post.render(~False{},True{},Post.State{fill(262144n,0,Array.new(M.Fragment,19n,M.Fragment{1000.0,0})),Array.new(U32,18n,0),Post.Settings{True{},True{},10.0,4.0}},Pix{0}))
    r : Array<Splats.Splat> & Spatial.Index(Splats.space()) & Array<U32> & Image <- Spatial.require(~Array<Splats.Splat> & Spatial.Index(Splats.space()) & Array<U32> & Image,SplatTest.render(True{}))
    splat_result(r)
