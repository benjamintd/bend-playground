# Shared Bend rendering

All camera, geometry, rasterization and postprocessing math is Bend. CPU and
Metal execute the same definitions with different root execution plans. The
native window effect only presents the resulting Image.

## Mesh pipeline

The shared [camera interface](CAMERA_API.md) prepares perspective or orthographic
views. `Project.triangle` transforms and clips world triangles against all six
view planes, then appends to `Batch`. `Scene` owns framebuffer allocation,
resolution dispatch and runtime CPU fallback. `Mesh.render_camera_level` uses
the projection metadata to select the matching depth/light equations.

The older `engine/render/camera.bend` adapter remains in Cloth and Meadow;
Turn has a game-specific projection with reciprocal synthetic depth. Those
callers use the legacy mesh equations. Their fixed camera setup is separate
from the clipped camera pipeline. Both paths share binning and raster code
with the interpolation mode statically selected outside pixel work.

`Batch.create/clear/push` manages reusable triangle storage, including growth.
It is independent of either camera convention. Low-level `Mesh.build_level`
bins projected bounds and `Mesh.Drawing` exposes the arrays needed for custom
coverage or postprocessing; Turn uses this path for selective text coverage.

The regular rasterizer walks candidates once per **2×2 pixel block**, loading
each ID and triangle once for all four pixels. It keeps four independent
background/depth/color accumulators and uses the same sample equations and
depth tie rule as the scalar query. Output pixels and retained fragments stay
in their original locations; no new buffers or GPU launches are needed.
The scalar query remains available as a regression reference. Four-sample AA
uses its separate coverage path and is not accelerated by this change.

Allocate `Array<Fragment>` for **twice the framebuffer area**: depth 19 at 512²,
depth 21 at 1024², depth 23 at 2048². `Mesh.backdrop` fills the first half with static color/depth.
Rasterization leaves it immutable and overwrites the second half with resolved
current-frame fragments. Refill the backdrop after camera or background changes.
Each pixel has exactly one writer. This two-half contract also applies when
effects are disabled; it is checked by the full-image raster oracle.

`Finish.draw(~high, gpu, Post.Settings{aa,dof,focus,aperture}, drawing, oldImage)`
selects the normal mesh path or rasterization followed by one finish pass. The
finish pass builds the returned Image while reclaiming the old one, avoiding
an intermediate Image allocation. The scene source remains immutable while
workers write exclusive pixel ranges.

## Anti-aliasing, resolution and focus

**Geometry anti-aliasing** evaluates each mesh pixel at four subpixel
positions (a rotated grid at offsets `(-1,-3), (3,-1), (-3,1), (1,3)`
in eighths of a pixel). Four distinct positions on each axis reduce the large
coverage steps of the earlier axis-aligned grid. Each sample resolves depth independently; their
packed colors are averaged for output. Empty screen bins keep the cached
background without four scene queries. The resolved depth is the nearest of
the four samples, used by the optional focus pass. Static backdrop color/depth
are sampled at the pixel center and reused; the four-sample coverage applies
to triangle geometry. This is neither temporal AA nor linear-light filtering.

`engine/render/coverage.bend` provides this shared pass, selected by
`Finish.draw` when `Settings.aa` is true. It writes the usual resolved fragment
region and then builds the output Image at the chosen resolution. With only
AA enabled, Image assembly skips the redundant fragment read and pixel rewrite;
its tree is shared with the depth-filter pass through a static specialization.
The two GPU passes remain separate. No larger
intermediate Image or four-times-larger framebuffer is needed for AA.
`Post.edge_color` remains a separately usable lightweight spatial filter; the
demo's A key now selects geometry coverage instead of that earlier filter.

The mesh's `*_level` entry points support levels **0, 1 and 2**, meaning 512²,
1024² and 2048². Other levels are outside this API's contract. Existing Boolean
512/1024 wrappers remain compatible. Meadow and Particle Life use Q for
1024²/2048², preserving physical state; only size-dependent render buffers are
reallocated. Cloth similarly switches 512²/1024² while retaining deformation,
previous positions, pause and a live grab. On macOS the small host `Viewport.resolution` effect changes the
presentation surface dimensions, using Bend's existing Window presentation.
This effect contains no pixel-generation or simulation code. High-resolution
window switching has only been implemented and validated on macOS.

`engine/render/downsample.bend` also offers an exact four-to-one Image resolve
for explicit supersampling/export. It consumes owned source Image subtrees and
writes disjoint output pixel regions. The demo uses direct coverage because
the initial 2048-to-1024 intermediate-Image route was too costly.

**Depth of field** computes a bounded blur radius from camera depth, focus
distance and aperture. Radius is measured at a reference width of 1024 pixels,
then scaled by the actual target width: maximum 1.5 / 3 / 6 pixels at
512 / 1024 / 2048. This preserves screen-space strength across resolution
changes. A Gaussian-weighted 3×3 kernel uses bilinear sampling at fractional
offsets instead of rounding its size. Its diagonal extent equals the blur
radius. Each of the four bilinear corners is depth-tested before accumulating
its weight, preventing rejected foreground colors from leaking through the
interpolation. The implementation gathers the equivalent 25 weighted texels
directly, skipping zero weights, instead of reading 36 bilinear corners.
Weights are normalized after rejection; borders clamp safely.
The in-focus plane stays unchanged and small defocus develops continuously.
The focus gather consumes the already resolved geometry color. This is a
subtle depth-aware defocus effect, not a physical lens or cinematic bokeh.
There is no foreground dilation, motion history or HDR highlight recovery.

Both operate on packed display-space RGB, so neither claims linear-light
filtering. Depth of field is optional. Cloth starts with both effects disabled;
press **A** for anti-aliasing and **D** for focus. Meadow exposes the same keys.
Performance measurements include the selected finish pass; see [PERF.md](PERF.md).

The implementation is independent. Background references for future work:
[NVIDIA's FXAA paper](https://developer.download.nvidia.com/assets/gamedev/files/sdk/11/FXAA_WhitePaper.pdf),
[AMD's depth-of-field technique](https://gpuopen.com/manuals/fidelityfx_sdk/techniques/depth-of-field/),
and [Practical Post-Process Depth of Field](https://developer.nvidia.com/gpugems/gpugems3/part-iv-image-effects/chapter-28-practical-post-process-depth-field).

## Periodic particle sprites

`Splats.draw` takes a source-owning spatial snapshot, a specialized sprite
reader/merge callback, settings, reusable pixels and the old Image. Its spatial
layout is a periodic 1024² world with 8-unit cells. Every tile visits nine
neighbor cells, including wrapped cells. Radius is clamped to 0.5–7 world units so
the neighborhood fully covers the sprite footprint. `draw_level` accepts scale 0 or 1: 1024² or 2048² output, with matching sprite
radii and 8² or 16² pixel tiles. The world, spatial index and interactions do not
change with resolution. Larger world-space sprites need a
different layout/query contract.

Sprites have analytic circle-edge coverage, a radial glow and saturating
integer channel addition. Addition is order-independent, so scatter order
cannot change the framebuffer. Glow is part of each sprite, not a bloom pass.
Particle Life's **A** toggles analytic coverage. It is a 2D scene with no focus
blur. Independent full-image and native CPU/Metal tests cover tile and torus
seams, coverage and compositing.

## September 28 quality validation

The independent moving-edge area test covers 256 subpixel phases on each axis;
its squared error falls by 75% with the rotated four-sample grid. This measures
horizontal/vertical coverage accuracy, not a universal image-quality score.
Four samples still allow subpixel shimmer in moving foliage; there is no motion
history or temporal reconstruction.

The native CPU and Metal checks cover a quarter-covered thin line, repeated
image replacement, 2048 output, and 1021 depth-filter probes against a separate
scalar oracle. Another 480 filter probes cover fractional radii, border clamps,
depth discontinuities and continuity around the old rounding thresholds. Cloth
quality round trips are checked for preserved deformation and velocity.

`benches/quality_snapshot.bend` exports an identical seeded Meadow state with
`raw`, `aa` (default), `dof`, `high`, or `dof high`. It warms simulation only and
writes short PPM lines, allowing practical 1024/2048 comparisons. Convert using
`scripts/ppm-to-png.py`. This export is for visual comparison, not timing.

An interactive frozen-scene comparison is saved in
[`results/quality-comparison.html`](../results/quality-comparison.html), beside
the original 1024/2048 PNG exports.
