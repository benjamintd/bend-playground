import Base
import ../engine/platform/arguments.bend as Arguments

def rows(xs: List<String>) -> IO(Unit):
  match xs:
    case Nil{}: IO.pure(Unit,Unit{})
    case x <> rest:
      do IO<Unit>:
        Unit <- IO.print(x)
        rows(rest)
def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- Arguments.read()
    rows(xs)
