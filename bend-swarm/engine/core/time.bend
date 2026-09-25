import Base

# Host timing only; simulation and rasterization have no foreign computation.
def micros() -> IO(Nat):
  import "./time.c"
  import "./time.js"

def elapsed(start: Nat, end: Nat) -> U32:
  U32.from_nat(Nat.sub(end, start))
