# Architecture

> Status: v0.9 implementation on `feature/impact-lab`, awaiting human acceptance and merge. Base: merged v0.8.1 (`9c0a242`). For detailed scene tuning, see [README](../README.md).

## Runtime overview

Crash Lab is a Godot 4 / GDScript, scene-oriented, 3D vehicle-combat prototype. `project.godot` launches `scenes/duel.tscn` by default. `scenes/main.tscn` remains the continuous training playground.

- **Duel:** `scenes/duel.tscn` instantiates the arena, player and AI rival, chase camera, combat HUDs, match controller, scene-local sound observer, and three repair pickups.
- **Training:** `scenes/main.tscn` instantiates the driving/range arena, player car, stationary turret, target dummy, camera, HUDs, sound observer, and a repair pickup.
- **Arenas:** `scenes/test_arena.tscn` provides lighting/environment; `scripts/arena.gd` creates training geometry. The duel overrides arena construction through `scripts/duel_arena.gd`.

## Main systems and ownership

| System | Key paths | Responsibility |
| --- | --- | --- |
| Vehicle chassis | `scripts/vehicles/vehicle_controller.gd`, `scenes/vehicles/muscle_car.tscn` | Rigid-body movement, four raycast suspension contacts, grip, steering, spawn recovery |
| Input providers | `scripts/vehicles/player_vehicle_input.gd`, `scripts/enemies/rival_driver.gd` | Translate player or AI decisions into shared throttle/brake/steering/fire/reset commands |
| Player loadout | `scenes/vehicles/player_car.tscn`, `scripts/weapons/player_loadout.gd` | Player-only two-weapon selection, cooldown ownership, firing guard |
| Weapons | `scripts/weapons/vehicle_weapon.gd`, `scripts/weapons/projectile.gd` | Firing cadence, swept projectile ray, hit delivery; weapon tuning in scene resources |
| Health | `scripts/combat/vehicle_health.gd`, `scripts/combat/vehicle_hurtbox.gd` | Damage, healing, destruction, protected respawn, projectile hit area |
| Repair pickups | `scripts/pickups/repair_pickup.gd`, `scenes/pickups/repair_pickup.tscn` | Non-solid pickup eligibility, contested overlap selection, respawn timer |
| Duel lifecycle | `scripts/match/duel_match.gd` | Elimination accounting, completed-physics-tick scoring, win/draw/lose, match restart |
| Audio and HUD | `scripts/audio/`, `scripts/debug/` | Scene-local signal observers, procedural cues, status and result presentation |
| Camera | `scripts/camera/chase_camera.gd` | Smoothed rear-follow camera with basic static-world obstruction ray |
| Collision telemetry | `scripts/vehicles/vehicle_impact.gd`, shared chassis `ImpactDetector` | Read rigid-body contact snapshots, coalesce contacts, classify speed, own episode history and optional bounded impulses |
| Crash presentation | `scripts/effects/impact_feedback.gd`, `crash_sparks.gd` | Scene-local signal observer, bounded mesh bursts and involved-player camera dispatch; audio observes independently |

## Data flow

1. A player or AI **input provider** sets command fields on a vehicle's `DriverInput` child.
2. The shared **vehicle controller** reads those fields in physics integration and applies forces to its own `RigidBody3D`.
3. **Weapons** read the same provider's fire intent. Their projectile rays call eligible collision targets' `take_damage()` handlers.
4. **DamageReceiver** updates health and emits signals. **MatchController**, audio, and HUDs observe appropriate events without owning vehicle motion.
5. **RepairPickup** checks actual nearby physical bodies for a living damaged `DamageReceiver`, calls `restore_health()`, and emits `collected`.
6. A finished duel calls each participant's `finish_combat()` gate, disables further gameplay events, and permits explicit scene restart.

## Impact ownership and interface

The chassis calls its child `ImpactDetector.sample(state)` inside `_integrate_forces`, after the recovery gate and before suspension forces. The component reads supported contact APIs, never keyboard/controller actions. `impact_detected(Dictionary)` carries `vehicle`, `collider`, world `position`, world `normal`, world `relative_velocity`, `closing_speed` (m/s), `severity` (0 none, 1 minor, 2 moderate, 3 major), `type` (`vehicle` or `arena`) and physics `tick`. One strongest contact per collider is considered each tick. Episode history retains IDs/timestamps, not physics-state objects. Pending dispatch is bounded to eight events and occurs in the component's physics process outside force integration.

For two instrumented vehicles the lower instance ID emits the shared presentation event. Both components track their own contact episodes and, only if enabled, apply their own bounded impulse during force integration. This avoids double sound/bursts and permits the camera observer to identify either involved vehicle. No global/static pair registry survives scene restart. `last_impact`, `event_count`, and opt-in structured console output support inspection.

Health destruction/respawn and chassis recovery/finish call `reset_tracking()`. Dispatch rechecks combat/death state for both participants and collider validity. `ImpactFeedback` connects detectors already present in its scene, forwards to cameras with `add_impact(data)`, and owns the burst budget. `CombatAudio` independently maps severity to three cached procedural cues in its existing bounded voice pools. `ChaseCamera` owns only decaying `h_offset`/`v_offset`; it clears on destruction/respawn, recovery grace and match finish. Existing follow position, rotation smoothing, and obstruction logic remain unchanged. Match completion also removes bursts through the existing `combat_effects` group.

Observers bind scene-authored vehicles at startup. Dynamically spawning additional vehicle actors is outside this two-vehicle milestone and would need explicit observer registration.

## Interfaces to preserve

- The shared vehicle controller expects `DriverInput` to expose `throttle`, `brake`, `steering`, `handbrake`, `fire_requested`, `reset_requested`, and `stop_commands()`.
- Damage recipients expose `take_damage(amount)`; the vehicle's receiver also exposes `restore_health(amount)`. Restoration returns the amount actually applied.
- Scene observers connect to signals rather than changing physics, AI, or damage directly.
- Vehicle damage zones are separate from rigid-body collisions: layer 1 = world, layer 2 = vehicle bodies, layer 3 = projectile hurtbox areas (bit masks 1, 2, 4 respectively). Projectiles query all three; suspension rays currently query the world only.
- Reusable scenes should not assume a single human player. Keep per-vehicle control and match-level lifecycle separate for future local multiplayer.

## Known structural limits

There is no local/online human multiplayer, environmental destruction, collision health damage, damage attribution for multi-party eliminations, or paid CI components. The public-only [Godot headless workflow](../.github/workflows/godot-headless.yml) includes impact tests; successful checks still require GitHub verification. Visual wheels and primitive chassis geometry are intentional prototypes. See [GAME_DESIGN](GAME_DESIGN.md), [PHYSICS](PHYSICS.md), and [TESTING](TESTING.md).

## Documentation maintenance

When adding or changing a system, update its ownership and contracts here, update related specialized documentation, and add a [CHANGELOG](../CHANGELOG.md) entry in the same PR.
