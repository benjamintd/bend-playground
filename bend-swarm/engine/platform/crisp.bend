import Base
# Presentation metadata only: preserve binary pixels during compositor scaling.
def enable(window: Window) -> IO(Window):
  import "./crisp.c"
  import "./crisp.js"
