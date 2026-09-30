# Bend playground

A graphics engine and seven interactive experiments written in Bend.

**[Play the demos](https://bend-engine-demos.vercel.app/)** ·
**[Play TURN](https://bend-engine-demos.vercel.app/turn/)**

- **TURN** — 26 puzzles about jumping, rotating the world, and changing perspective.
- **Meadow** — wind through 4,096 blades of grass.
- **Cloth** — a draggable sheet with gravity, wind, and contact constraints.
- **Particle Life** — six species and emergent patterns.
- **Swarm** — a flock that responds to your pointer.
- **Monochrome** — a kinetic sculpture with a movable camera.
- **Voxels** — an editable block landscape.

The engine, demos, laws, tests, and benchmarks live in [`bend-swarm/`](bend-swarm/).
Bend defines the simulations, game rules, cameras, and geometry. The browser
build compiles Bend to JavaScript and uses a small shared WebGL 2 display adapter.
Simulation runs on the main thread; this version does not use WebAssembly or
Web Workers. Native demos also support the engine's CPU and Metal renderers.

## Run the web gallery

Install Node.js 22 and Git, then run:

```sh
npm ci
npm run build
npm run preview
```

Open http://localhost:4173/. `npm ci` installs the pinned Bun version locally.
The build fetches the exact Bend revision in `bend-swarm/.bend-version`, checks TURN's
proofs, and builds the seven demos. Compilation and proof checks run sequentially.
Only `bend-swarm/build/web-site/` is served.

See the [web build notes](bend-swarm/web/README.md),
[native engine instructions](bend-swarm/README.md), and
[TURN rules and controls](bend-swarm/demos/turn/README.md).

## Deployment

Vercel builds this repository using the root `vercel.json`. Production tracks
`main`; other branches receive preview deployments. The existing
`bend-engine-demos` project is hosted by the **Benjamin Td** Pro team.

Toolchains, compiled output, local credentials, and Vercel's local project
metadata are excluded from Git. TURN's derived font retains its
[SIL Open Font License](bend-swarm/demos/turn/assets/OFL.txt).
