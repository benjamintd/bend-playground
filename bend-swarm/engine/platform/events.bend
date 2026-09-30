import Base

# Supported interface: poll. Event collection never submits a frame.
# timeout_ms is a maximum wait; input wakes it early. The macOS adapter also
# reports focus, visibility and any interruption since the previous poll. JS uses Bend's headless window convention.
type Activity is Data:
  Activity{focused: Bool, visible: Bool, interrupted: Bool}
def native(window: Window, timeout_ms: U32) -> IO(Window & U32 & List<Event>):
  import "./events.c"
  import "./events.js"
def decoded(r: Window & U32 & List<Event>) -> Window & Activity & List<Event>:
  (window,+bits,events) = r
  (window,Activity{U32.is_ne(U32.and(bits,1),0),U32.is_ne(U32.and(bits,2),0),U32.is_ne(U32.and(bits,4),0)},events)
def poll(window: Window, timeout_ms: U32) -> IO(Window & Activity & List<Event>):
  do IO<Window & Activity & List<Event>>:
    r : Window & U32 & List<Event> <- native(window,U32.min(timeout_ms,1000))
    return decoded(r)
