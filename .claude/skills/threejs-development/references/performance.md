# Performance Engineering

Measure first: `renderer.info` (render.calls, render.triangles,
memory.geometries/textures), browser GPU profilers, stats panel,
Spector.js for draw-call inspection. Optimise the measured
bottleneck — CPU (draw calls, JS per frame) vs GPU (overdraw,
shader cost, resolution) have different fixes.

## Draw calls (usually the CPU bottleneck)

- **InstancedMesh** for N copies of the same geometry+material
  (trees, bolts, particles): one draw call; per-instance matrix via
  `setMatrixAt` + `instanceMatrix.needsUpdate`; per-instance colour
  supported.
- **Merge static geometry** (`BufferGeometryUtils.mergeGeometries`)
  sharing one material; trade-off: loses per-object culling/raycast
  identity.
- Share materials: every unique material/program switch costs;
  texture atlases let merged/instanced meshes vary appearance.
- **LOD** (`THREE.LOD`) for distance-dependent detail; impostors
  (billboards) at extreme distance.
- Frustum culling is on by default — keep bounding volumes correct
  after geometry edits (`computeBoundingSphere`); set
  `frustumCulled = false` only for skinned/instanced edge cases that
  pop.

## Memory discipline

- `geometry.dispose()`, `material.dispose()`, `texture.dispose()`,
  `renderTarget.dispose()`, `renderer.dispose()` — scene removal
  does not free GPU memory. Recursive teardown:

```javascript
function disposeTree(root) {
  root.traverse((obj) => {
    obj.geometry?.dispose();
    const mats = Array.isArray(obj.material) ? obj.material : [obj.material];
    mats.forEach((m) => {
      if (!m) return;
      Object.values(m).forEach((v) => v?.isTexture && v.dispose());
      m.dispose();
    });
  });
}
```

- `renderer.dispose()` frees the renderer's own internals. It does
  **not** dispose the scene's geometries, materials or textures, nor
  `scene.environment`/`scene.background` textures, PMREM output or
  post-processing render targets. Dispose those explicitly (the
  traverse above, plus `scene.environment?.dispose()`,
  `composer.dispose()` / each pass's targets).
- SPA/HMR leak pattern: re-creating renderer/scene on remount without
  disposing the old — watch `renderer.info.memory` across
  navigations. In a Vite-style dev server, HMR also stacks event
  listeners on static `index.html` elements and `window`, module-scope
  state (bloom settings, composer targets) and animation loops. Record
  every side effect as a cleanup thunk and replay them on dispose:

```javascript
const cleanups = [];
const onEl = (el, type, fn, opts) => {
  el.addEventListener(type, fn, opts);
  cleanups.push(() => el.removeEventListener(type, fn, opts));
};
// ... onEl(window, 'resize', onResize); cleanups.push(() => disposeTree(scene));
cleanups.push(() => renderer.setAnimationLoop(null), () => renderer.dispose());
if (import.meta.hot) import.meta.hot.dispose(() => cleanups.splice(0).forEach((f) => f()));
```

  Keep mutable state inside factories (`createScene()` returns its
  state and its `dispose()`), not at module scope, so a reload starts
  clean.
- Reuse scratch objects in loops (`_v3.set(...)`), never allocate
  per frame; reuse geometries/materials across meshes.

## Frame loop

- One rAF/`setAnimationLoop` owner; delta-time all motion.
- **Render on demand** for static content: render only on
  controls/state change.
- Static objects: `matrixAutoUpdate = false`.
- Throttle expensive non-visual work (raycast hover checks every
  2–3 frames; physics fixed-step).
- Offload: physics/pathfinding/decode in Web Workers;
  `OffscreenCanvas` rendering where supported.

## GPU side

- Cap pixel ratio at 2; consider dynamic resolution scaling under
  load.
- Overdraw: large transparent quads (particles, foliage) are fill-
  rate killers — smaller geometry, alphaTest, fewer layers.
- Shadows: smallest viable map sizes (1024² default), tight frusta,
  static shadow baking; one shadow-casting light unless justified.
- Post-processing passes each cost a full-screen render — budget
  them, combine where possible (`shaders-webgpu.md`).
- **Transmission is a hidden extra pass.** In `WebGLRenderer` (checked
  at r186), the first visible material with `transmission > 0` makes
  the renderer re-draw all opaque objects into a mipmapped
  multisampled render target, once per camera per frame. Every
  `DoubleSide` transmissive object then adds a back-face draw (and
  flips `material.needsUpdate` twice). Glass-heavy scenes can double the draw
  calls. Measure `renderer.info.render.calls` with and without the
  glass, consider `transmissionResolutionScale` < 1, prefer
  `FrontSide` or plain `transparent` + `opacity` where refraction
  isn't visible, and test on a throttled or low-end GPU.
- Texture VRAM: KTX2 keeps textures compressed ON the GPU — biggest
  single mobile win (`assets-loaders.md`).

## Mobile checklist

DPR cap (consider 1.5), KTX2 textures, reduced shadow budget or none,
simpler materials (Lambert/Phong fallback path), triangle budget
roughly an order below desktop, test on real mid-range hardware,
`powerPreference: 'high-performance'` hint, handle context loss
(`webglcontextlost` → restore path).

## Budgets (starting points, tune per project)

≤100 draw calls mobile / ≤500 desktop; ≤300k tris mobile / ≤1–2M
desktop; texture memory ≤128 MB mobile; first interactive render
≤3 s on 4G. Enforce in CI via asset checks (`assets-loaders.md`).
