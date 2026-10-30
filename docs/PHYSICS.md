# Driving and physics

> Merged v0.9 baseline `cb76c23`, retained for v0.10 local multiplayer. Gameplay feel must be validated in interactive playtests; passing headless tests alone does not establish that driving is fun.

## Physics baseline

- Godot 4, `GodotPhysics3D`, **120 physics ticks/sec** (see `project.godot`).
- Shared `RigidBody3D` vehicle controller: `scripts/vehicles/vehicle_controller.gd`.
- Approximate **1,400 kg** default chassis mass, lowered custom center of mass, simple box collider, continuous collision detection.
- Four suspension-contact raycasts sample the static world. Compression/damping produce spring force, and contact points apply longitudinal drive/braking and lateral traction.
- Front tire-force directions steer the chassis. Steering angle reduces with speed. Rear traction falls with the handbrake.
- Forces are limited by estimated suspension load. The car is not repositioned every frame; **manual/fall recovery** is an intentional exception applied during physics integration.

## Current default tuning

Values live in exported properties in `vehicle_controller.gd`; scene overrides, if introduced, take precedence.

| Parameter | Default | Meaning |
| --- | ---: | --- |
| `vehicle_mass` | 1400 | Rigid-body mass (kg) |
| `engine_force` | 22000 | Shared drive-force setting (N), increased after sluggish-acceleration feedback |
| `brake_force` | 24000 | Braking-force setting (N) |
| `maximum_speed` | 55 m/s | Forward power cutoff, **not** measured top speed or a hard clamp |
| `reverse_speed` | 13 m/s | Reverse power cutoff |
| `steering_angle` | 0.52 rad | Low-speed steer angle |
| `high_speed_steering_angle` | 0.20 rad | High-speed steer angle |
| `steering_speed_reference` | 42 m/s | Original steering fade reference, now independent of power cutoff |
| `steering_response` | 6.0 | Speed of steer-state response |
| `lateral_traction` | 8.0 | Lateral velocity-correction strength |
| `handbrake_grip` | 0.22 | Rear-grip multiplier while handbraking |
| `tire_force_limit` | 10000 | Contact force bound |
| `suspension_length` | 0.65 m | Raycast suspension travel setting |
| `spring_stiffness` | 36000 | Spring stiffness |
| `spring_damping` | 4200 | Spring damping |
| `wheel_radius` | 0.32 m | Ray contact geometry |

Also adjustable: linear/angular damping and recovery thresholds. Use one consistent physics unit system: meters, seconds, kilograms, and newtons.

## Collision behavior (implemented)

Vehicle bodies collide with the world and each other. Momentum, mass, and contact geometry influence motion through the physics engine. Vehicle-versus-vehicle impacts **do not currently deal health damage**. Visible roofs exceed the shallow physical chassis; a separate projectile hurtbox covers the upper body. Tires are visual meshes without rolling collision or wheel-spin animation.

v0.9 adds impact classification/presentation and the explicitly requested powertrain refinement. Mass, brakes, reverse cutoff, grip, damping, suspension, center of mass and original steering-by-speed curve are preserved. No ramming damage is implemented. Optional extra impulses default off. High-speed physical tests did not reproduce tunneling at 55 m/s into another chassis or a 0.15 m wall, so collider dimensions, contact limits and CCD settings were retained. The visual roof remains outside the shallow physical chassis; that geometric limitation is not a telemetry failure.

## Impact calculation and contact reporting

The shared rigid body sets `contact_monitor = true` and `max_contacts_reported = 16`. Inside `_integrate_forces`, `ImpactDetector` reads `PhysicsDirectBodyState3D` contact position, normal, collider object and both contact-point velocities. For this validated **GodotPhysics3D** backend, these are world-space snapshots captured before the collision solver changes velocities. Angular contact-point velocity is already included by the engine; it must not be added twice. In particular, `get_contact_local_position()` is documented in global coordinates despite its name. Normal is the receiving body's outward separating direction in world space in the validated backend.

Let `v_rel = contact_local_velocity - contact_collider_velocity`, and `n` be the normalized contact normal. Calculate `closing_speed = max(0, -v_rel.dot(n))`. Units are m/s. Reject nonfinite data and invalid normals. This combines opposing velocities, subtracts same-direction velocities and excludes tangential speed. Coalesce a body's manifold contacts to the largest closing speed; do not sum corner contacts or use absolute chassis speed.

| Category | Default normal closing speed |
| --- | --- |
| Ignored | Below 1.5 m/s, separating or invalid data |
| Minor | 1.5 to below 5 m/s |
| Moderate | 5 to below 12 m/s |
| Major | 12 m/s or more |

Thresholds are unchanged at 1.5/5/12 m/s. Ignore `abs(n.y) > 0.65`: floor/ramp support and landings get no crash event. Suspension rays themselves are not rigid-body contacts. A pair's episode rearms after 0.35 s without contact. Unlike the initial implementation, an ignored/minor touch does not consume a later significant impact: higher categories may upgrade once, at most three events per unbroken episode. A major cannot repeat until separated. A 0.12 s **per-pair upgrade** interval queues the strongest pending upgrade instead of dropping it. Distinct colliders are independent; there is no vehicle-wide event cooldown. Pending events coalesce per pair and are bounded to eight per component.

Either vehicle's report is normalized into the lower-ID owner's perspective (swap participants/contact positions and negate normal/relative velocity). The canonical owner receives reports even if its own contact buffer is empty, uses its configured thresholds and deduplicates both reporters. This fixes confirmed one-sided sensor loss. Reset/destruction/respawn clears pending events and reactions for both sides. Recovery grants 0.35 s grace. Physics-frame time handles temporary freezing without an indefinitely latched episode.

### Optional major-impact exaggeration

Disabled by default. When a canonical major event is dispatched, queue one reaction for each enabled participant and consume it in that body's next force integration, rechecking lifecycle and collider validity. Apply planar central impulse `J = planar_normal * clamp(mass * closing_speed * impulse_scale, 0, linear_cap)`. Defaults: scale **0.04**, cap **700 N·s** (at most **0.5 m/s** added at 1,400 kg). Separately apply only the yaw component of `(contact - body_origin - world_COM_offset).cross(J)`, clamped to **±180 kg·m²/s**. Use the state's impulse APIs once; no continuous force or pitch/roll torque. Existing contact physics still supplies its normal collision response.

The lower instance ID owns vehicle-pair presentation; each participant applies its queued response only inside its own integration. With matching settings the planar pushes oppose each other; mixed settings are experimental. Destroyed/combat-disabled participants receive no added reaction. Power changes are isolated from this optional system; AI desired speed remains 14 m/s through its commands rather than a chassis override.

### Camera/effect limits and tuning

Camera follow settings and crash offsets are preserved: moderate 0.06 m/0.18 s, major 0.18 m/0.32 s, vertical 60%, hard amplitude ceiling 0.3 m. Minor bumps do not shake. Speed independently sets target FOV to `75 + 10 * smoothstep(8, 40, speed)` degrees, interpolated at 3/s with `1-exp(-response*dt)`, hard range 50–95°. All five FOV parameters are exported; increase zero disables speed widening. Chase orientation/obstruction remain unchanged.

Eight scene-local bursts maximum. Minor/moderate/major use 8/12/18 camera-facing triangle streaks, durations 0.30/0.45/0.65 s. Major streaks start ~0.146 m wide and 1.11 m long, move ballistically outward, retain contrast through the travel phase and fade over their final 0.24 s. A 0.265 m-radius unshaded center fades over 0.22 s. Geometry uses vertex colors and double-sided triangles in Compatibility, with no glow dependency. Preserve contact x/z but project y above visible bodywork (`spark_surface_height` 0.9 m above the involved chassis origins), avoiding the previous buried sparks. The projection is presentation only; telemetry retains the true contact point. At most 864 streak vertices plus eight low-resolution sphere meshes are active; no physical debris or persistent clutter.

### Powertrain measurements and rationale

The 22,000 N / 55 m/s candidates are retained after comparing identical long straight physics fixtures. Previous/new speeds: **18.49/22.81 m/s at 3 s** (original training baseline 18.46), **24.12/30.93 m/s at 6 s**, **26.01/34.05 m/s at 30 s**. This is about 24% more runway speed at 3 s and 31% more near-terminal straight speed, without changing mass, traction or suspension. The 55 m/s cutoff is not an attained top speed; power falloff and unchanged damping still govern the real result.

New read-only telemetry `drive_force_requested`, `drive_force_applied` (N) and `effective_linear_damping` exposes force distribution. At 30 s, previous requested/applied sums were **9249.43/9249.43 N**; new **13569.32/13569.32 N**. The existing tire-force bound is not clipping those straight-line samples. Effective damping is **0.22/s** (body 0.12 plus world 0.10). No traction/damping increase or bypass was needed. Steering gets its own 42 m/s reference so raising the power cutoff does not silently increase steering angles at the same speed. Reverse retains its 13 m/s cutoff but shares the stronger engine force. Test this response on a controller before acceptance.

The 16-contact limit suits two simple boxes and static arena geometry, not a general pileup detector. Ground-like normals and low-speed scrapes are intentionally silent. Retest when changing engine/backend, collider complexity, physics tick rate or contact-reporting limits. Human Windows/controller testing must judge noise, camera comfort, control recovery and optional impulse stability.

API references verified during implementation: [PhysicsDirectBodyState3D](https://docs.godotengine.org/en/stable/classes/class_physicsdirectbodystate3d.html), [RigidBody3D contact reporting](https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html), and [GodotPhysics3D contact snapshot construction](https://github.com/godotengine/godot/blob/4.7-stable/modules/godot_physics_3d/godot_body_pair_3d.cpp). Local engine confirmed 4.7.2.stable.official.ed1daf0bf; actual rotated-body/head-on/side scenarios validate coordinate/sign assumptions.

## Recovery and respawn

Manual reset and automatic fall recovery restore the recorded primary transform and clear momentum only when it is clear. Destroyed vehicles wait for a validated spawn before healing/reenabling controls. AI/training have empty alternative lists and retain their original primary-only behavior; local players have four alternatives. AI stuck/rollover recovery remains unchanged.

## v0.10 shared physics and safe alternate spawning

Two SubViewports share one root World3D/physics space at **120 Hz**, not two simulations. Both human cars retain the exact v0.9 mass, 22,000 N power, 55 m/s cutoff, steering/brakes/grip/suspension/damping and weapon tuning. Local camera framing is the explicit playtest adjustment below. Physical collisions still deal no health damage. A local 55 m/s opposing collision emits one canonical event and stops both chassis with >4 m separation, routing shake to both cameras.

### Local camera framing after playtest

The initial half-height view preserved 75° vertical FOV, giving approximately 141° horizontal at 1280×345 (`2*atan(tan(vertical/2)*aspect)`); widening to 85° vertically gave ~147° across. This explains the stretched edges and small, distant-looking car. Local cameras now use `Camera3D.KEEP_WIDTH` with **110° horizontal**, widening by **5°** at speed. Distance **6.5 m**, height **2.4 m**, focus height **0.55 m** frame the entire car with a closer/lower view. `local_duel.gd` exports all five values. Smoothing 9/s, yaw response 4/s, speed thresholds/response, obstruction ray and collision shake are unchanged.

The shared chase script exposes `focus_height` (default **0.8 m**) and `maximum_fov` (default **95°**); AI/training still use their original 8.5 m / 4 m and 75–85° vertical lens. Only the local scene sets its horizontal cap to 115°. HUD/world geometry is not stretched to achieve this. See [Godot Camera3D aspect/FOV](https://docs.godotengine.org/en/stable/classes/class_camera3d.html). Stationary, moving and resized views were rendered and inspected; human framing approval remains pending.

Local `alternate_spawn_points` are four flat-arena corners at (±55, 1.25, ±55), searched in authored order; they retain the primary spawn's heading. Health waits **1.5 seconds after an occupied normal respawn countdown** before alternatives become eligible. At each physics step, try the primary first, then alternatives: physical chassis overlap query, mask 3, own RID excluded, 0.3 m margin; alternatives also require all four wheel-mount downward rays (2 m, world mask 1) to hit support with normal-up dot ≥0.7. The recorded candidate is rechecked inside integration immediately before moving. Health waits for a new `reset_generation` before restoration/protection/input. Re-evaluate blocked candidates rather than reserving a location that could become occupied. If every candidate is unsafe, defer and retry. This replaces spawn camping deadlock in the authored two-car local arena without unsafe teleporting.

The manual reset API and v0.9 input/physics contract stay compatible. Alternate points are empty by default on the shared chassis; only the local player scene configures them. Projectiles gain weak shooter attribution through an optional source-aware damage method, without adding a physical collision force or health-damage path.

Local sparks use two crossed quads per streak so the one simulated effect remains visible from both cameras. Colors, velocities, counts, durations, center and eight-burst cap are unchanged. Local major maximum: **1,728 streak vertices** across eight bursts plus their centers; single-player remains 864. No new effect instances or particle simulations are created per viewport. Split-screen sound has one root listener at the participants' midpoint; listeners in both render views are disabled.

## Tuning and regression procedure

1. Record current tunables and reproduce a baseline in the training/duel scene.
2. Change one group of parameters at a time; do not fix collision feel by silently degrading steering.
3. Repeat runway acceleration, hard braking, reverse, high-speed steering, ramp landing, barrier collision, and two-car collision tests.
4. Track grounded wheels, signed speed, pose, and impact outcomes. Compare both headless tests and interactive feel.
5. Document measured results, test engine version, approved defaults, limitations, and any change to multiplayer fairness.

See [TESTING](TESTING.md) for commands and [GAME_DESIGN](GAME_DESIGN.md) for desired handling identity.
