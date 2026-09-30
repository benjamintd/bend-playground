# Bend playground on the web

Seven interactive demos: TURN, Meadow, Cloth, Particle Life, Swarm,
Monochrome, and Voxels. The landing page lives in `web/index.html`; TURN has
its own full-screen game page, and the six experiments use `web/demo.html`.

Live gallery: https://bend-engine-demos.vercel.app/

TURN: https://bend-engine-demos.vercel.app/turn/

## Build and preview

From the repository root:

```
scripts/build-web
bun scripts/serve-web.js
```

Open http://localhost:4173/. Output is isolated in `build/web-site`; it contains
only public static assets and Vercel configuration. The build uses the pinned
Bend compiler's supported Bun plugin and emits separate JavaScript chunks for
the experiments. No engine or compiler patches are needed.

## GitHub deployment

The public source is at https://github.com/benjamintd/bend-playground.
The `bend-engine-demos` Vercel project is connected to this repository and
hosted by the **Benjamin Td** Pro team (`benjamin-td`). Pushes to `main` build
and deploy production; other branches get preview deployments.

The repository-root `package.json` pins Bun, and `vercel.json` runs the setup,
proofs, browser compilation, and static-link checks sequentially. The only
published output directory is `bend-swarm/build/web-site`.

For a manual deployment of already-built static files, use the linked build
directory and select the Pro team explicitly:

```
vercel --cwd build/web-site --scope benjamin-td --prod
```

## Browser boundary

`web/adapters/*.bend` call the existing simulation, geometry, camera, picking,
and spatial APIs. Their error boundary returns Bend `Result` values instead of
exiting a native process. `demos/turn/browser.bend` exports TURN's same controller,
fixed-step timing and scene. The public engine API is unchanged.

`web/renderer.js` presents the engine's already-projected triangles using WebGL 2.
This is a handwritten browser display adapter bundled with the compiled Bend;
the compiler does not generate the WebGL backend. Bend compiles to JavaScript
and runs on the main thread. There is no WebAssembly or Web Worker in this build.
It retains perspective/orthographic depth and lighting; the native CPU/Metal
pixel rasterizer is not run in the browser. Static analytic backdrops are sampled
from Bend once and uploaded with depth. Particle sprites use additive browser
presentation. Native antialiasing/depth-of-field toggles are not exposed on web.

The web profile uses 2,048 particles/boids. Cloth uses an 8x8 physical grid,
a derived 16x16 visual surface, and coarser spatial bins covering exactly the
same domain. Its constraint equations, contact candidates within the query
radius, picking, and fixed substeps are shared with native. The coarse bins avoid
scanning thousands of empty cells for each longer edge. The facade is compared
against the native solver at the same physical resolution. Meadow keeps all
4,096 blades; Voxels keeps its complete 32x16x32 world.

Keyboard, pointer and touch controls are local to the browser host. Inactive
pages pause and release held controls. TURN stores chapter progress locally;
blocked storage is harmless. There are no accounts, analytics, backend, or
external runtime services.

## Validation

- `scripts/test-web` checks proofs, all hint witnesses, budget/input behavior,
  the native hint controller, and native/web cloth agreement.
- `tests/web-build.js` checks all generated page links and local assets.
- `tests/web-bench.js` and `tests/web-cloth-bench.js` measure compiled Bend
  outside the browser; results are not browser frame-rate guarantees.
- Browser checks cover all seven pages, TURN hints/restart, presets and pause,
  camera projection, voxel carving, and desktop layout.

The September 29 deployment passed 30 public route/asset checks. TURN's live
hint marker and budget were also checked in the browser. Final web Cloth
displayed about 20–29 ms per frame in the in-app browser on this machine;
this is an observation, not a cross-device performance guarantee.

Run compilation and proof/replay jobs sequentially: overlapping Bend-to-JS
compilation and campaign verification can consume substantial memory. The
local static preview server is independent and does not compile on requests.

TURN Outline (the game's triangulated Rubik-derived lettering) is distributed
with its SIL Open Font License in `/licenses/turn-outline-ofl.txt`.
