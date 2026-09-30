import Base
import ../engine/parallel/policy.bend as Policy
import ../engine/render/mesh.bend as M
import ../engine/render/finish.bend as Finish
import ../engine/render/post.bend as Post
import ../engine/core/time.bend as Time
import ./quality-native.bend as Fixture
import ./image-check.bend as ImageCheck

def fixture(~level: Nat, r: Array<M.Triangle> & M.Index) -> M.Drawing:
  (tris,M.Index{_,offsets,_,ids,_}) = r
  M.Drawing{tris,offsets,ids,Array.new(U32,Nat.add(18n,Nat.add(level,level)),0),
    Array.new(M.Fragment,Nat.add(19n,Nat.add(level,level)),M.Fragment{1000.0,0})}
def create(~level: Nat, bin: Bool) -> M.Drawing:
  fixture(~level,M.build_level(~level,bin,4,
    Fixture.quad(2,50.25,128.0,50.75,480.0,16711680,Fixture.quad(0,128.25,100.5,400.75,400.5,16777215,
      Array.new(M.Triangle,2n,M.blank()))),M.empty()))
type Compare is Type:
  Compare{expected: Array<U32>, actual: Array<U32>, differences: U32, max_channel: U32}
def delta(+a: U32, +b: U32) -> U32:
  (U32.max(a,b) - U32.min(a,b) : U32)
def compared(ref: Array<U32>, +color: U32, errors: U32, worst: U32, r: Array<U32> & U32) -> Compare:
  (got,+other) = r
  Compare{ref,got,(errors + Bool.to_u32(U32.is_ne(color,other)) : U32),U32.max(worst,
    U32.max(delta(U32.and(color,255),U32.and(other,255)),U32.max(delta(U32.and(U32.shrn(color,8n),255),U32.and(U32.shrn(other,8n),255)),
      delta(U32.shrn(color,16n),U32.shrn(other,16n)))))}
def at(i: U32, got: Array<U32>, errors: U32, worst: U32, r: Array<U32> & U32) -> Compare:
  (ref,color) = r
  compared(ref,color,errors,worst,Array.get(U32,got,i))
def compare(n: Nat, +i: U32, r: Compare) -> Compare:
  match n:
    case 0n: r
    case 1n+k:
      Compare{ref,got,e,w} = r
      compare(k,(i + 1 : U32),at(i,got,e,w,Array.get(U32,ref,i)))
def report(label: String, tree_count: U32, tree_errors: U32, r: Compare) -> IO(Unit):
  Compare{_,_,e,w} = r
  IO.print(label ++ "," ++ U32.show(tree_count) ++ "," ++ U32.show(tree_errors) ++ "," ++ U32.show(e) ++ "," ++ U32.show(w))
def checked(label: String, count: Nat, reference: Array<U32>, r: ImageCheck.Check) -> IO(Unit):
  ImageCheck.Check{pixels,n,e} = r
  report(label,n,e,compare(count,0,Compare{reference,pixels,0,0}))
def check(~level: Nat, label: String, expected: M.Drawing & Image, measured: (M.Drawing & Image) & U32 & U32) -> IO(Unit):
  (M.Drawing{_,_,_,reference,_},_) = expected
  ((M.Drawing{_,_,_,pixels,_},image),_,_) = measured
  +width = U32.shln(512,level)
  checked(label,U32.to_nat((width * width : U32)),reference,ImageCheck.image(image,width,width,0,0,ImageCheck.Check{pixels,0,0}))
def again(~level: Nat, raster: Bool, post_gpu: Bool, settings: Post.Settings, r: (M.Drawing & Image) & U32 & U32) -> IO((M.Drawing & Image) & U32 & U32):
  ((drawing,image),_,_) = r
  Finish.measured(~level,raster,post_gpu,settings,drawing,image)
def resolved(~level: Nat, +mode: U32, +effect: U32, +settings: Post.Settings, p: Policy.Policy) -> IO(Unit):
  Policy.Policy{_,_,+bin,+raster,+post_gpu,_} = p
  do IO<Unit>:
    original : M.Drawing = create(~level,bin)
    boundary : Nat <- Time.micros()
    expected : M.Drawing & Image = Finish.draw_level(~level,raster,settings,original,Pix{0})
    boundary : Nat <- Time.micros()
    drawing : M.Drawing = create(~level,bin)
    measured : (M.Drawing & Image) & U32 & U32 <- Finish.measured(~level,raster,post_gpu,settings,drawing,Pix{0})
    measured : (M.Drawing & Image) & U32 & U32 <- again(~level,raster,post_gpu,settings,measured)
    check(~level,U32.show(U32.from_nat(level)) ++ "," ++ U32.show(mode) ++ "," ++ U32.show(effect),expected,measured)
def one(~level: Nat, +mode: U32, +effect: U32) -> IO(Unit):
  do IO<Unit>:
    p : Policy.Policy <- Policy.resolve(Policy.Policy{False{},False{},U32.is_ne(U32.and(mode,4),0),U32.is_ne(U32.and(mode,1),0),U32.is_ne(U32.and(mode,2),0),0n})
    resolved(~level,mode,effect,Post.Settings{U32.is_ne(U32.and(effect,1),0),U32.is_ne(U32.and(effect,2),0),10.0,4.0},p)
def cases(~level: Nat, n: Nat, +i: U32) -> IO(Unit):
  match n:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+k:
      do IO<Unit>:
        Unit <- one(~level,(i / 4 : U32),(i % 4 : U32))
        cases(~level,k,(i + 1 : U32))
def main() -> IO(Unit):
  do IO<Unit>:
    enabled : U32 <- Policy.available()
    Unit <- IO.print("available," ++ U32.show(enabled))
    Unit <- cases(~0n,32n,0)
    Unit <- one(~1n,1,3)
    one(~2n,6,3)
