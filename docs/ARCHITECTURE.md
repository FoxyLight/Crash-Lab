# Architecture

> Status: tracks the implemented v0.8 prototype on `main`. Update this document in the same PR as architecture changes. For detailed scene tuning, see [README](../README.md).

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

## Data flow

1. A player or AI **input provider** sets command fields on a vehicle's `DriverInput` child.
2. The shared **vehicle controller** reads those fields in physics integration and applies forces to its own `RigidBody3D`.
3. **Weapons** read the same provider's fire intent. Their projectile rays call eligible collision targets' `take_damage()` handlers.
4. **DamageReceiver** updates health and emits signals. **MatchController**, audio, and HUDs observe appropriate events without owning vehicle motion.
5. **RepairPickup** checks actual nearby physical bodies for a living damaged `DamageReceiver`, calls `restore_health()`, and emits `collected`.
6. A finished duel calls each participant's `finish_combat()` gate, disables further gameplay events, and permits explicit scene restart.

## Interfaces to preserve

- The shared vehicle controller expects `DriverInput` to expose `throttle`, `brake`, `steering`, `handbrake`, `fire_requested`, `reset_requested`, and `stop_commands()`.
- Damage recipients expose `take_damage(amount)`; the vehicle's receiver also exposes `restore_health(amount)`. Restoration returns the amount actually applied.
- Scene observers connect to signals rather than changing physics, AI, or damage directly.
- Vehicle damage zones are separate from rigid-body collisions: layer 1 = world, layer 2 = vehicle bodies, layer 3 = projectile hurtbox areas (bit masks 1, 2, 4 respectively). Projectiles query all three; suspension rays currently query the world only.
- Reusable scenes should not assume a single human player. Keep per-vehicle control and match-level lifecycle separate for future local multiplayer.

## Known structural limits

There is no local/online human multiplayer, environmental destruction system, impact-severity mechanic, damage attribution for multi-party eliminations, or paid CI components. The proposed public-only [Godot headless CI workflow](../.github/workflows/godot-headless.yml) runs existing tests; successful checks still require GitHub verification. Riderless visual wheels and primitive chassis geometry are intentional prototypes. See [GAME_DESIGN](GAME_DESIGN.md), [PHYSICS](PHYSICS.md), and [TESTING](TESTING.md).

## Documentation maintenance

When adding or changing a system, update its ownership and contracts here, update related specialized documentation, and add a [CHANGELOG](../CHANGELOG.md) entry in the same PR.
