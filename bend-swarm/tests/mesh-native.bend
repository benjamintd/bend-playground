import Base
import ./mesh.bend as T
import ../engine/render/mesh.bend as M

def read(sum: U32, nonbackground: U32, r: Array<U32> & U32) -> Array<U32> & U32 & U32:
  (pixels,+color) = r
  (pixels,(sum + color : U32),(nonbackground + Bool.to_u32(Bool.not(U32.is_eq(color,66051))) : U32))

def checksum(n: Nat, +i: U32, r: Array<U32> & U32 & U32) -> Array<U32> & U32 & U32:
  match n:
    case 0n: r
    case 1n+k:
      (pixels,sum,count) = r
      checksum(k,(i + 1 : U32),read(sum,count,Array.get(U32,pixels,i)))

def report(r: Array<U32> & U32 & U32) -> IO(Unit):
  (_,sum,count) = r
  IO.print(U32.show(sum) ++ "," ++ U32.show(count))

def result(n: Nat, r: M.Drawing & Image) -> IO(Unit):
  (M.Drawing{_,_,_,pixels,_},_) = r
  report(checksum(n,0,(pixels,0,0)))

def main() -> IO(Unit):
  do IO<Unit>:
    Unit <- result(262144n,T.render(True{},4,T.fixture()))
    result(1048576n,T.render_high(True{},4,T.fixture_high()))
