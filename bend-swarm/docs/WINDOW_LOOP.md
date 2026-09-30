# Event-driven native windows

The engine separates collecting input from presenting an image. Applications
can keep their last frame on screen while waiting for input, and stop simulation
and rendering when their window is inactive. TURN is the first caller.

## Engine contract

`engine/platform/events.bend` exposes
`poll(window, timeout_ms) -> IO(Window & Activity & List<Event>)`.
It returns the same owned window, its current activity and ordered Bend events.
It never renders an image, acquires a drawable or dispatches Metal. It also
works before the first `Window.frame`. The timeout is a maximum, clamped to
1,000 ms; input or a lifecycle notification can wake the call sooner. Unrelated
OS events can wake it too, so always re-evaluate the state after polling.

`Activity` contains:

- `focused`: the application is active and this window is its key window.
- `visible`: the window is shown, is not minimized and has visible content
  according to AppKit's occlusion state.
- `interrupted`: focus or visibility was lost since the preceding poll,
  including a loss followed by a regain between two polls. Consuming the result
  clears this flag. Clear held input and discard elapsed simulation time on an
  interruption, even if the window has already become active again.

The macOS adapter observes application and window notifications and wakes a
blocked poll when activity changes. Its event decoding uses the pinned Bend
2.0.27 Window adapter's five-word queue; recheck that ABI when updating Bend.
[Apple's occlusion state](https://developer.apple.com/documentation/appkit/nswindow/occlusionstate-swift.property)
describes whether any part of a window is visible. Partial coverage still counts
as visible. Applications choose whether an unfocused but visible window animates.

Native polling currently supports macOS. Other native backends fail explicitly;
the existing `Window.frame` API remains available there. JavaScript follows
Base's headless Window convention and has no interactive window or waiting.
Scroll, pinch, bindings and gesture interpretation are outside this interface.

`engine/platform/cadence.bend` exposes two pure functions:

```text
due(active, dirty, interval_us, age_us) -> Bool
wait_ms(active, dirty, interval_us, age_us) -> U32
```

`age_us` is elapsed time since the last rendered frame. An interval of zero
means a static scene: render only when dirty. Active dirty scenes draw immediately;
inactive scenes never draw. For animation, draw when the interval has elapsed.
Waits round up to milliseconds to avoid spinning for the last fraction of a
millisecond, and are bounded to one second. Input can interrupt that wait.

The caller retains the renderer and image between draws, uses `wait_ms` when
polling, advances appropriate application state, and calls its renderer and
`Window.frame` only when `due` is true. Consume events returned by both `poll`
and `Window.frame`; presentation may itself receive new input. Close events
must still be honored when inactive. Mark input changes and reactivation dirty.
Update the frame timestamp only when a frame is drawn.

These are small scheduling and platform primitives. Games own their simulation
state, bindings, definition of activity and animation rates; the engine does not
need callbacks into a game's renderer or physics.

## TURN policy

TURN pauses whenever it loses focus or visibility. It preserves position,
velocity, puzzle progress and animation state, while clearing held keys, buffered
jumps and the physics accumulator. Resuming does not catch up background time.
Static chapter menus redraw on input or reactivation. Decorative animation runs
at up to 30 Hz at rest; movement, rotation, settling and completion use up to
60 Hz. Physics retains the existing fixed 120 Hz step.

Waiting retains the last image and skips geometry, rasterization and presentation.
There is no game simulation in an inactive window. The event loop can still wake
for OS events and its one-second timeout; this is not a promise of zero process
CPU consumption. Existing demos must opt into these primitives; they are not
silently paused by changes to a shared renderer.

## Verification

`scripts/test` covers cadence decisions and arithmetic boundaries.
`tests/turn/schedule.js` covers game policy, ordered input, pause, held-key reset
and resume without catch-up. `scripts/test-window` opens a disposable native
window to verify polling without presentation, ordered key delivery, timed
wakeup, focus interruption, resumption and closing. It requires a macOS desktop.

For the native CPU comparison, build the fixture and run it with other builds
and tests stopped:

```sh
scripts/bend tests/turn/idle-bench.bend -o build/turn-idle-bench
python3 scripts/bench-turn-idle.py
```

This compares the old unconditional loop and the current loop in the same
executable, with identical rendering and physics. Both exclude startup and the
first frame. A second inert window holds focus for the visible-unfocused case;
separate cases hide the app and minimize its window. Foreground runs require the
test window to retain focus. Results in `results/turn-idle-performance.json`
measure whole-process CPU time, including worker threads, as a proxy for energy;
they are not power or battery measurements.
