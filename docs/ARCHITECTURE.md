# Architecture

> Status: merged v0.9 baseline `cb76c23`; v0.10 local multiplayer implemented on its feature branch, awaiting human acceptance/merge. See [README](../README.md).

## Runtime overview

Crash Lab is a Godot 4 / GDScript, scene-oriented, 3D vehicle-combat prototype. `project.godot` launches `scenes/duel.tscn` by default. `scenes/main.tscn` remains the continuous training playground.

- **Duel:** `scenes/duel.tscn` instantiates the arena, player and AI rival, chase camera, combat HUDs, match controller, scene-local sound observer, and three repair pickups.
- **Training:** `scenes/main.tscn` instantiates the driving/range arena, player car, stationary turret, target dummy, camera, HUDs, sound observer, and a repair pickup.
- **Local duel:** `scenes/local_duel.tscn` contains one arena, P1/P2 inherited player chassis, one router, match, pickups, impact observer and sound observer. `local_duel.gd` builds two camera/HUD views of the root World3D and one global result panel; it does not instance gameplay actors inside the views.
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
| Local input | `scripts/multiplayer/local_input_router.gd`, `local_vehicle_input.gd` | Raw device-aware event routing, stable pad slots, neutral join/edge handling; supply the existing DriverInput contract |
| Local presentation | `scripts/multiplayer/local_duel.gd`, `local_player_hud.gd` | Shared-world horizontal SubViewports, explicit per-player HUD references, midpoint listener and one shared result |
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

For two instrumented vehicles, **either reporter** forwards normalized contact data to the lower-ID owner's `observe_contact(data)`. `mirrored(data)` swaps participants/contact positions and negates world normal and relative velocity. The owner maintains one episode per collider: last contact time, highest accepted severity and last dispatch time. Stronger categories can upgrade, weaker/same categories cannot repeat. `event_interval` delays upgrades within a pair; it no longer drops distinct colliders. The bounded pending queue coalesces reports for the same collider to the strongest category. This handles missing contact data on either chassis without duplicate pair presentation. No global/static registry survives restart.

When a canonical major event dispatches, each enabled participant receives a bounded `pending_reactions` entry. Each chassis consumes its own reaction during its next `sample(state)`, before reading contacts; lifecycle is rechecked. This keeps all impulse application in the owning force callback and suppresses mirrored duplicates, including during escalation. Extra reactions remain disabled by default. `last_impact`, `event_count`, structured debug output and chassis force telemetry support inspection.

Health destruction/respawn and chassis recovery/finish call `reset_tracking()`. Components in the scene's `vehicle_impacts` group also `forget_vehicle(actor)` to cancel that actor's episode, event and reaction on the canonical counterpart. Dispatch rechecks both participants and collider validity. `ImpactFeedback` owns the burst budget and presentation-only `spark_origin(data)` projection above placeholder bodywork. `crash_sparks.gd` owns bounded moving/fading camera-facing triangle streaks and a center mesh. `CombatAudio` independently maps severity to cached cues in existing voice pools. `ChaseCamera` owns crash offsets and speed-dependent FOV; original follow/obstruction logic stays intact. Results clear shake and remove all `combat_effects`; restart rebuilds scene-local observers.

The shared chassis now separates power cutoff from `steering_speed_reference`, preserving the previous steering fade despite higher power. `drive_force_requested`, `drive_force_applied` and `effective_linear_damping` are read-only measurements inside integration, not new forces. The rival still supplies ordinary throttle/brake commands against its existing desired speed; no higher AI speed or stronger enemy weapon is introduced.

Observers bind scene-authored vehicles at startup. Dynamically spawning additional vehicle actors is outside this two-vehicle milestone and would need explicit observer registration.

## Interfaces to preserve

- The shared vehicle controller expects `DriverInput` to expose `throttle`, `brake`, `steering`, `handbrake`, `fire_requested`, `reset_requested`, and `stop_commands()`.
- Damage recipients expose `take_damage(amount)`; the vehicle's receiver also exposes `restore_health(amount)`. Restoration returns the amount actually applied.
- Scene observers connect to signals rather than changing physics, AI, or damage directly.
- Vehicle damage zones are separate from rigid-body collisions: layer 1 = world, layer 2 = vehicle bodies, layer 3 = projectile hurtbox areas (bit masks 1, 2, 4 respectively). Projectiles query all three; suspension rays currently query the world only.
- Reusable scenes should not assume a single human player. Keep per-vehicle control and match-level lifecycle separate for future local multiplayer.

## Local multiplayer ownership and lifecycle

`local_input_router.gd` receives raw root `_input` events exactly once. It maps physical keys/mouse only to P1 in keyboard mode and JoypadMotion/JoypadButton by explicit noncontiguous device IDs. It never uses global action strengths. Hotplug calls `assign_devices(Input.get_connected_joypads())`, preserving still-connected slots and filling only empty ones. Assignment seeds actual device state, clears old edges and requires neutral before input joins. Key echoes/duplicate button presses cannot generate additional cycles or restarts. F2 selects a session-static setup; device slots/mute survive ordinary scene restart. Focus loss clears cached commands. This event/state layer has synthetic test seams for device inventories/events, not a claim of emulated hardware validation.

`local_vehicle_input.gd` extends the original provider interface, runs before loadout/health processing and reads only its router slot. Existing player input and AI scripts remain unchanged. `local_player_car.tscn` inherits the full player loadout, substitutes this provider, hides the old root HUD, adds a nameplate and configures alternate spawn points. The local scene supplies explicit router references for each instance. New compact HUDs receive vehicle/match/router references rather than looking up Player/Rival names.

Projectile ownership uses `damage_source: WeakRef`. Weapons attach their shooter; swept hits prefer `take_damage_from(amount, source)` on colliders/receivers, falling back to `take_damage(amount)` for legacy targets. Health records only the accepted lethal source and exposes `get_death_source()`, clearing it on confirmed respawn. No shared/global last-attacker registry. Local matches enable `require_damage_source`; credit is awarded only when the lethal source is the other participant. Self/unknown kills still respawn but give no points. The AI duel preserves legacy unattributed one-argument fixture behavior by default; attributed self/third-party kills never award the opponent. Completed-tick grouping, same-tick draws and per-life deduplication remain in the shared match controller.

Health requests `prepare_respawn(allow_alternates)` after its countdown. The chassis chooses a clear primary or supported clear alternative and records a `respawn_target`; integration rechecks the destination, moves safely, clears momentum and increments `reset_generation`. Health restores controls/health/protection only after that generation is observed. Waiting candidates are revalidated every step; no space reservation or unsafe timeout teleport. Empty alternate lists preserve AI/training behavior. Match finish clears pending reset targets alongside other gameplay gates.

Two SubViewportContainers sit in a root VBox and each shares the root `World3D`. They contain only a chase camera and CanvasLayer HUD; viewport input/audio listeners are disabled. The root has one AudioListener3D at the player midpoint and one CombatAudio observer (`shared_mix = true`). Both players receive the same shot/respawn rules; one result cue plays. The router owns shared restart/mute edges; match/audio consume them once. Crossed spark quads enable both cameras to see one simulated effect; original single-player geometry stays unchanged. Existing impact feedback finds both cameras and routes only involved-player shake. Results freeze both actors and clear shared projectiles/effects; reload rebuilds all scene-local references/signals.

Validated against the local engine and official [viewport guide](https://docs.godotengine.org/en/stable/tutorials/rendering/viewports.html), [per-device Input API](https://docs.godotengine.org/en/stable/classes/class_input.html) and [AudioListener3D](https://docs.godotengine.org/en/stable/classes/class_audiolistener3d.html). In particular, global action strengths do not identify an individual pad; device IDs are routed explicitly.

Post-playtest local framing is configured on the LocalDuel root: 6.5 m back, 2.4 m up, 0.55 m focus, 110° horizontal FOV plus 5° speed widening. The shared chase defaults stay unchanged for AI/training; new optional focus/FOV-cap fields permit local overrides. Local nameplates use visual layers 19/20 (bits 18/19), each camera excluding only its own label while retaining the opponent's. This affects render culling only, not physical collision layers or health data.

## Known structural limits

No online networking, arbitrary multi-party/assist attribution, environment destruction, collision health damage or paid CI components. Local mode is two players with one horizontal layout and a shared speaker mix. Dynamic extra actors would need observer registration. The public-only workflow includes multiplayer checks; actual hosted results still require verification. See [GAME_DESIGN](GAME_DESIGN.md), [PHYSICS](PHYSICS.md), and [TESTING](TESTING.md).

## Documentation maintenance

When adding or changing a system, update its ownership and contracts here, update related specialized documentation, and add a [CHANGELOG](../CHANGELOG.md) entry in the same PR.
