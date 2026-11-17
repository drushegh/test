# Physics (2D and 3D)

**Engine note (June 2026): Godot 4.6 made Jolt the default 3D
physics engine** (previously an extension; the old Godot Physics
remains selectable). 2D continues on Godot's own physics. Expect
behavioural differences migrating pre-4.6 3D projects — retest
character controllers and stacked rigid bodies after upgrading.

## Body taxonomy (2D shown; 3D mirrors)

| Body | Simulated by | Use |
|------|--------------|-----|
| `StaticBody2D/3D` | Nothing (immovable) | Level geometry; `AnimatableBody` variant for movers (platforms) that push others |
| `CharacterBody2D/3D` | Your script | Player/NPC controllers — `move_and_slide()` with full state queries (`is_on_floor()` etc.) |
| `RigidBody2D/3D` | Physics engine | Simulated props/projectiles — apply forces/impulses, do NOT set position per frame |
| `Area2D/3D` | N/A (detection) | Triggers, pickups, damage zones, buoyancy/gravity overrides — `body_entered`/`area_entered` signals |

## Character controller core

```gdscript
extends CharacterBody3D

@export var speed := 5.0
@export var jump_velocity := 4.5

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity += get_gravity() * delta
    var input := Input.get_vector("left", "right", "forward", "back")
    var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
    velocity.x = direction.x * speed
    velocity.z = direction.z * speed
    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = jump_velocity
    move_and_slide()
```

`move_and_slide()` consumes `velocity`, handles slopes/steps per
floor properties (`floor_max_angle`, snap). After it: `is_on_floor/
wall/ceiling()`, `get_slide_collision_count()` for contact handling.

## RigidBody rules

- Influence via `apply_central_force/impulse`, `linear_velocity` —
  never teleport via `position` (breaks the solver); for exceptional
  teleports use `PhysicsServer`-safe patterns or
  `_integrate_forces(state)`.
- `_integrate_forces` for custom per-step control (read/write the
  physics state directly).
- `freeze` + freeze modes for pickup/carry mechanics; CCD for fast
  bullets, or raycast-based projectiles instead.
- Sleeping bodies wake on contact/impulse; don't fight the sleep
  system with per-frame nudges.

## Collision layers and masks

**Layer** = what I am; **mask** = what I see. Name layers in Project
Settings (Player, Enemy, EnemyHitbox, Pickup, World, …) and design
the interaction matrix up front. Typical: player body masks World +
Enemy; player hurtbox (Area) masks EnemyHitbox; pickups mask Player
only. Misconfigured masks are the #1 "collision doesn't work" cause —
check both sides see each other.

`Area.body_entered` fires only when the body's `collision_layer`
intersects the area's `collision_mask`. A body you never configured
sits on **layer 1** by default, so zones that mask a "Player" layer 2
never see it. The boot is clean and nothing happens. Assign every
body's layer explicitly from the table, and verify the trigger fires at
runtime (a print in the handler), not by reading the `.tscn`.

## Mutating physics from physics callbacks

Inside `body_entered`/`area_entered` (and other signals emitted while
the server is flushing queries), changing monitoring, shapes or the
tree throws **"Can't change this state while flushing queries. Use
call_deferred() or set_deferred() …"**. It can repeat hundreds of
times per session and never crash, so grep play logs for it.

```gdscript
func _on_body_entered(body: Node3D) -> void:
	set_deferred("monitoring", false)          # not: monitoring = false
	var fx: Node3D = burst_scene.instantiate()
	fx.position = global_position              # set BEFORE the deferred add
	get_parent().add_child.call_deferred(fx)
```

## Navigation-driven kinematic NPCs

A `CharacterBody3D` following a `NavigationAgent3D` must:

- flatten the chase direction to XZ
  (`var dir := agent.get_next_path_position() - global_position;
  dir.y = 0.0`), because the navmesh surface sits slightly above the
  floor and a 3D direction makes the NPC climb and hover;
- own `velocity.y` itself (gravity + `is_on_floor()`), driving only
  `velocity.x/z` from the path.

Procedural navmesh without a visual mesh: fill a
`NavigationMeshSourceGeometryData3D` with
`set_vertices(PackedFloat32Array)` (flat x,y,z,x,y,z…) and
`set_indices(PackedInt32Array)` (or `append_arrays` / `add_faces`),
then `NavigationServer3D.bake_from_source_geometry_data[_async]`.
Recast keeps only faces whose normal is within `agent_max_slope` of
up, so wind floor triangles for a +Y normal. **If the bake comes back
empty, flip the winding first.** `add_mesh()` takes a `Mesh`, and one
project found it re-triggered the runtime mesh-parse performance
warning it was meant to avoid (verify). Prefer raw arrays for
procedural sources.

## Queries and raycasts

- `RayCast2D/3D` nodes for persistent rays (ground checks, line of
  sight) — `is_colliding()`/`get_collider()`; remember
  `force_raycast_update()` after moving in the same frame.
- Direct space queries for ad-hoc casts:
  `get_world_3d().direct_space_state.intersect_ray(
  PhysicsRayQueryParameters3D.create(from, to))` — physics-frame
  context only.
- `ShapeCast` for thick rays; Area monitoring for volumetric
  queries.

## Movers and platforms

`AnimatableBody` + `AnimationPlayer`/tween for moving platforms
(pushes characters correctly); set `sync_to_physics` on; character
`platform_floor_layers` config for ride/carry behaviour.

## Performance and stability

Physics tick fixed (default 60 Hz; project setting); interpolate
visuals for high-refresh smoothness (physics interpolation setting).
Simple collision shapes (capsule for characters; boxes/spheres over
trimesh; trimesh = static-only). Don't scale collision shapes via
node scale — size the shape resource. For crowds: avoid hundreds of
active RigidBodies; use CharacterBodies with simple steering or
server-side (PhysicsServer) custom handling.
