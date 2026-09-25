import Base
# Host window metadata only; simulation and rendering stay in Bend.
def dimensions(window: Window) -> IO(Window & U32 & U32):
  import "./viewport.c"
  import "./viewport.js"
