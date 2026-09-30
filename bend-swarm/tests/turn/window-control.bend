import Base
# Test-only OS window actions and process CPU accounting. No game computation.
def action(window: Window, mode: U32) -> IO(Window):
  import "./window-control.c"
  import "./window-control.js"
def cpu_micros() -> IO(Nat):
  import "./process-time.c"
  import "./process-time.js"
