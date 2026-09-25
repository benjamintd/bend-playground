import Base
# Host window metadata only; simulation and rendering stay in Bend.
def dimensions(window: Window) -> IO(Window & U32 & U32):
  import "./viewport.c"
  import "./viewport.js"

# Presentation target size only. Pixel generation remains entirely in Bend.
def resolution(window: Window, size: U32) -> IO(Window):
  import "./resolution.c"
  import "./resolution.js"
