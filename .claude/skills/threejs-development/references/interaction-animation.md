# Interaction, Controls and Animation

## Raycasting

```javascript
const raycaster = new THREE.Raycaster();
const pointer = new THREE.Vector2();

function onPointerDown(event) {
  const rect = renderer.domElement.getBoundingClientRect();
  pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
  pointer.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;
  raycaster.setFromCamera(pointer, camera);
  const hits = raycaster.intersectObjects(interactables, false);
  if (hits.length) select(hits[0].object);
}
```

Rules: raycast a curated `interactables` array, not the whole scene
graph (`recursive: false` where possible); for big/complex meshes use
**three-mesh-bvh** (orders of magnitude faster); `InstancedMesh` hits
return `instanceId`; skinned meshes need up-to-date matrices and are
expensive — proxy hitboxes (invisible simple meshes) are the pro
move for characters/complex models. Throttle hover raycasts; touch
needs bigger proxies than mouse.

**Thin or stacked geometry picks the neighbour.** Raycasting thin
slabs (stacked layers, shelves, cables) often hits the adjacent item.
Give each pickable item an invisible, deliberately fat hit proxy and
raycast only the proxies. `Raycaster` does not check `visible` (it
tests `layers` only, verified at r186), so a proxy with
`visible = false` still picks and costs no draw call. A
`colorWrite: false, depthWrite: false` proxy also works but is still
drawn. Map proxy → item via `userData`.

**Click vs drag with OrbitControls.** `OrbitControls` dispatches
`'start'` on pointer-down (and on every wheel tick) before any
movement, so "the user grabbed the camera" can't be read from
`'start'` alone. Every click looks like a camera grab. Classify
yourself:

```javascript
let down = null;
canvas.addEventListener('pointerdown', (e) => { down = { x: e.clientX, y: e.clientY }; });
canvas.addEventListener('pointerup', (e) => {
  if (!down) return;
  const moved = Math.hypot(e.clientX - down.x, e.clientY - down.y);
  down = null;
  if (moved <= 6) pick(e);            // a click: raycast
  else markManualCameraIntent();      // a drag: the user moved the camera
});
for (const t of ['pointercancel', 'pointerleave']) canvas.addEventListener(t, () => { down = null; });
canvas.addEventListener('wheel', markManualCameraIntent, { passive: true });
```

Use the same distinction before cancelling auto-rotate or a guided
camera tour, so a click doesn't count as "the user took over".

## Controls (three/addons)

| Control | Use |
|---------|-----|
| `OrbitControls` | Default inspect/orbit; `enableDamping` (+ mandatory `update()` per frame), set `minDistance/maxDistance/maxPolarAngle` to keep users out of degenerate views |
| `MapControls` | Pan-dominant (GIS/plans) |
| `TrackballControls` | Free tumbling, no up-vector lock |
| `FlyControls` / `PointerLockControls` | Fly-through / FPS |
| `TransformControls` | Editor gizmos (translate/rotate/scale) — excludes itself from raycasts but mind event conflicts with orbit (disable orbit while dragging) |
| `DragControls` | Simple plane dragging |

Smooth camera moves: tween `camera.position` and a controls
`target` together (gsap or manual damping); never teleport mid-
interaction. drei `<Bounds>`/`fitToBox` patterns auto-frame objects.

## Animation system (clips)

```javascript
const mixer = new THREE.AnimationMixer(gltf.scene);
const action = mixer.clipAction(
  THREE.AnimationClip.findByName(gltf.animations, 'Walk'));
action.play();
// frame loop:
mixer.update(delta);
```

- Crossfade: `next.reset().fadeIn(0.3).play(); prev.fadeOut(0.3);`
- One-shots: `action.setLoop(THREE.LoopOnce); action.clampWhenFinished
  = true;` listen for the mixer `finished` event.
- Mixer per animated root; `mixer.update(delta)` every frame; stop
  unused actions (they cost even at weight 0 in big scenes).
- Morph targets ride the same clip system; bone-heavy scenes: cap
  skinned mesh counts, share `AnimationClip`s across instances.

## Procedural motion

Delta-time everything (`pos += speed * delta`); damp toward targets
(`THREE.MathUtils.damp`) instead of lerping by fixed factors for
frame-rate independence; gsap/tween.js fine for UI-ish moves —
drive them from the single render loop, not parallel rAFs.

**Paused clocks and seeking break `dt`-scaled smoothing.** When a
timeline is paused or scrubbed, `dt` can be 0 (or negative on a seek
backwards), and smoothing with `k ∝ dt` then freezes stale state on
screen. Drive *simulation* from the timeline, but give *smoothing* a
nominal dt (for example `1/60`) whenever the real one is ≤ 0. Also,
`t % cycle` accumulates float error at cycle boundaries, so a seek to
"the start of step N" can land in step N−1. Seek to a time a small
epsilon *inside* the target window, and derive the step index from the
seek target rather than from the modulo.

## Interaction accessibility (web context)

A 3D canvas is still a web UI: provide keyboard alternatives for
essential interactions (select/next/previous focus model parts),
expose state in DOM (visually-hidden live region announcing
selection), respect `prefers-reduced-motion` (disable auto-rotate/
camera fly-ins), and never make the canvas the only path to critical
content — `accessibility-development` owns the acceptance bar.

## R3F equivalents

Pointer events on meshes replace manual raycasting
(`r3f-patterns.md`); drei `<TransformControls>`, `<DragControls>`,
`useAnimations(gltf)` wrap the above with correct lifecycle.
