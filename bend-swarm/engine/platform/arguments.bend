import Base

# Bend 2.0.32 includes argv[0]. Demo parsers receive only user arguments.
# The verified 2.0.27 pin returns user arguments only. Bend 2.0.32 includes
# the executable first; a future pin upgrade must drop it here. The native
# argument regression catches this difference before running benchmarks.
def read() -> IO(List<String>):
  IO.args()
