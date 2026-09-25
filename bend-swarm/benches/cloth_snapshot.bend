import Base
import ./cloth.bend as B
import ../demos/cloth/frame.bend as F

def pixel(text: String, r: Array<U32> & U32) -> Array<U32> & String:
  (pixels,+color) = r
  (pixels,text ++ U32.show(U32.shrn(color,16n)) ++ " " ++ U32.show(U32.and(U32.shrn(color,8n),255))
    ++ " " ++ U32.show(U32.and(color,255)) ++ " ")

def row(n: Nat, +i: U32, r: Array<U32> & String) -> Array<U32> & String:
  match n:
    case 0n: r
    case 1n+k:
      (pixels,text) = r
      row(k,(i + 1 : U32),pixel(text,Array.get(U32,pixels,i)))

def line(r: Array<U32> & String) -> IO(Array<U32>):
  (pixels,text) = r
  do IO<Array<U32>>:
    Unit <- IO.print(text)
    return pixels

def rows(n: Nat, +y: U32, pixels: Array<U32>) -> IO(Unit):
  match n:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+k:
      do IO<Unit>:
        pixels : Array<U32> <- line(row(512n,(y * 512 : U32),(pixels,"")))
        rows(k,(y + 1 : U32),pixels)

def result(f: F.Frame) -> IO(Unit):
  F.Frame{_,_,_,pixels,_,_,_,_} = f
  do IO<Unit>:
    Unit <- IO.print("P3\n512 512\n255")
    rows(512n,0,pixels)

def main() -> IO(Unit):
  do IO<Unit>:
    f : F.Frame <- F.create(5n)
    f : F.Frame <- B.frames_depth(0n,180n,0,False{},f)
    result(f)
