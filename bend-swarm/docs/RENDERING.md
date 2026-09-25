# Shared Bend rendering

All camera, geometry, rasterization and postprocessing math is Bend. CPU and
Metal execute the same definitions with different root execution plans. The
native window effect only presents the resulting Image.

## Mesh pipeline

`Camera.look_at` defines an orthonormal view. `Camera.project` and `Camera.ray`
use matching perspective coordinates. Triangles carry projected vertices,
camera depth, vertex light and color. `Mesh.build_quality` bins their bounds;
tile workers resolve perspective-correct depth and interpolated light. The
current fixed cameras keep demo geometry in view; near-plane-crossing
triangles are rejected rather than clipped.

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
positions (a 2×2 pattern). Each sample resolves depth independently; their
packed colors are averaged for output. Empty screen bins keep the cached
background without four scene queries. The resolved depth is the nearest of
the four samples, used by the optional focus pass. Static backdrop color/depth
are sampled at the pixel center and reused; the four-sample coverage applies
to triangle geometry. This is neither temporal AA nor linear-light filtering.

`engine/render/coverage.bend` provides this shared pass, selected by
`Finish.draw` when `Settings.aa` is true. It writes the usual resolved fragment
region and then builds the output Image at the chosen resolution. No larger
intermediate Image or four-times-larger framebuffer is needed for AA.
`Post.edge_color` remains a separately usable lightweight spatial filter; the
demo's A key now selects geometry coverage instead of that earlier filter.

The mesh's `*_level` entry points support levels **0, 1 and 2**, meaning 512²,
1024² and 2048². Other levels are outside this API's contract. Existing Boolean
512/1024 wrappers remain compatible. Meadow and Particle Life use Q for
1024²/2048², preserving physical state; only size-dependent render buffers are
reallocated. On macOS the small host `Viewport.resolution` effect changes the
presentation surface dimensions, using Bend's existing Window presentation.
This effect contains no pixel-generation or simulation code. High-resolution
window switching has only been implemented and validated on macOS.

`engine/render/downsample.bend` also offers an exact four-to-one Image resolve
for explicit supersampling/export. It consumes owned source Image subtrees and
writes disjoint output pixel regions. The demo uses direct coverage because
the initial 2048-to-1024 intermediate-Image route was too costly.

**Depth of field** computes a bounded blur radius from camera depth, focus
distance and aperture. A nine-tap gather rejects samples across significant
depth discontinuities. Its maximum radius is three pixels. The focus gather consumes the already resolved geometry color. This is a
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
