import Base
import ./splats.bend as T
import ./showcase-native.bend as Probe
import ./image-check.bend as Check
import ../engine/render/splats.bend as R
import ../engine/spatial.bend as Spatial

def checked(r: Check.Check) -> IO(Unit):
  Check.Check{_,count,errors} = r
  IO.print("image," ++ U32.show(count) ++ "," ++ U32.show(errors))
def sums(image: Image, r: Array<U32> & U32 & U32 & U32 & U32) -> IO(Unit):
  (p,r,g,b,n) = r
  do IO<Unit>:
    Unit <- IO.print("splats," ++ U32.show(r) ++ "," ++ U32.show(g) ++ "," ++ U32.show(b) ++ "," ++ U32.show(n))
    checked(Check.image(image,2048,2048,0,0,Check.Check{p,0,0}))
def result(r: Array<R.Splat> & Spatial.Index(R.space()) & Array<U32> & Image) -> IO(Unit):
  (_,_,p,image) = r
  sums(image,Probe.splat_sum(4194304n,0,(p,0,0,0,0)))
def main() -> IO(Unit):
  do IO<Unit>:
    r : Array<R.Splat> & Spatial.Index(R.space()) & Array<U32> & Image <- Spatial.require(~Array<R.Splat> & Spatial.Index(R.space()) & Array<U32> & Image,T.render_high(True{}))
    result(r)
