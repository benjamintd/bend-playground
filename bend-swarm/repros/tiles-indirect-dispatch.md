# Generic tile dispatch experiment, Bend 2.0.27

Environment: project pin 95317d952c8fe5be18ef49f916b2a57250cfb0aa,
Apple M2 Pro, macOS 15.7.4. No Bend/compiler changes.

A shared tile tree passed the complete JavaScript suite and all 34 native CPU
policy cases. Its first version also shared a `run(gpu, ...)` wrapper containing
both the ordinary and banged tree call. Native Metal policy validation stalled
for over two minutes; a live stack sample showed `cube_run` waiting in
`-[MTLCommandBuffer waitUntilCompleted]`, with CPU workers idle.

After stopping only that test, the saved pre-tile-refactor executable passed
all 34 Metal policy cases. A bounded rerun of the candidate printed cases
`0,0,0` through `0,1,0`, then failed at the next AA case with:

```
bend: a function the device does not hold
```

The working version puts `Tiles.tree!` directly in each renderer's GPU branch,
with an ordinary `Tiles.tree` in its CPU branch. The tree and ownership code
remain shared. This removes the additional dispatch wrapper and follows the
existing region traversal convention. A single-case native reproduction then
passed; full validation is recorded in the engine simplification report.

The compiler preserves bang markers through template specialization and emits
device segments reachable from bang targets. The error means an unexpected
device function ID; neither it nor the stack sample identifies the offending
ID or proves whether reachability, continuation structure or corrupted state
caused it. This is an observed workaround, not a diagnosed compiler fix.

`tiles-indirect-dispatch.patch` restores only the rejected wrapper/call-site
shape relative to the accepted direct-dispatch version. To investigate in an
isolated checkout, apply that patch, then build `tests/policy-native.bend` and
run it with `--gpu on --threads 10` under a timeout. Keep the production engine
on direct renderer entry points. The saved failing binary/source are locally
available in `build/engine-tiles-indirect/`; they are not repository artifacts.
