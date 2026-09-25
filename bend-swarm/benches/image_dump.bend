import Base

def pixel(text: String, r: Array<U32> & U32) -> Array<U32> & String:
  (p,+color) = r
  (p,text ++ U32.show(U32.shrn(color,16n)) ++ " " ++ U32.show(U32.and(U32.shrn(color,8n),255)) ++ " " ++ U32.show(U32.and(color,255)) ++ " ")
def row(n: Nat, +i: U32, r: Array<U32> & String) -> Array<U32> & String:
  match n:
    case 0n: r
    case 1n+k:
      (p,text) = r
      row(k,(i + 1 : U32),pixel(text,Array.get(U32,p,i)))
def printed(r: Array<U32> & String) -> IO(Array<U32>):
  (p,text) = r
  do IO<Array<U32>>:
    Unit <- IO.print(text)
    return p
def rows(+width: U32, n: Nat, +y: U32, pixels: Array<U32>) -> IO(Unit):
  match n:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+k:
      do IO<Unit>:
        pixels : Array<U32> <- printed(row(U32.to_nat(width),(y * width : U32),(pixels,"")))
        rows(width,k,(y + 1 : U32),pixels)
def image(+width: U32, pixels: Array<U32>) -> IO(Unit):
  do IO<Unit>:
    Unit <- IO.print("P3\n" ++ U32.show(width) ++ " " ++ U32.show(width) ++ "\n255")
    rows(width,U32.to_nat(width),0,pixels)
