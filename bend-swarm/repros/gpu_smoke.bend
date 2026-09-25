import Base

def sum(+d: Nat, +i: U32) -> U32:
  match d:
    case 0n:
      i
    case 1n+p:
      a b = sum(p, i) sum(p, (i + U32.shln(1, p) : U32))
      (a + b : U32)

def main() -> IO(Unit):
  IO.print(U32.show(sum!(14n, 0)))
