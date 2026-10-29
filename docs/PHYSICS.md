# Driving and physics

> Implementation reference for v0.9 on its feature branch. Gameplay feel must be validated in interactive playtests; passing headless tests alone does not establish that driving is fun.

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
| `engine_force` | 15000 | Forward drive-force setting (N) |
| `brake_force` | 24000 | Braking-force setting (N) |
| `maximum_speed` | 42 m/s | Forward power cutoff, **not** a hard speed clamp |
| `reverse_speed` | 13 m/s | Reverse power cutoff |
| `steering_angle` | 0.52 rad | Low-speed steer angle |
| `high_speed_steering_angle` | 0.20 rad | High-speed steer angle |
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

v0.9 adds impact classification and presentation without changing these physical defaults. No ramming damage is implemented. Optional extra impulses default off.

## Impact calculation and contact reporting

The shared rigid body sets `contact_monitor = true` and `max_contacts_reported = 16`. Inside `_integrate_forces`, `ImpactDetector` reads `PhysicsDirectBodyState3D` contact position, normal, collider object and both contact-point velocities. For this validated **GodotPhysics3D** backend, these are world-space snapshots captured before the collision solver changes velocities. Angular contact-point velocity is already included by the engine; it must not be added twice. In particular, `get_contact_local_position()` is documented in global coordinates despite its name. Normal is the receiving body's outward separating direction in world space in the validated backend.

Let `v_rel = contact_local_velocity - contact_collider_velocity`, and `n` be the normalized contact normal. Calculate `closing_speed = max(0, -v_rel.dot(n))`. Units are m/s. Reject nonfinite data and invalid normals. This combines opposing velocities, subtracts same-direction velocities and excludes tangential speed. Coalesce a body's manifold contacts to the largest closing speed; do not sum corner contacts or use absolute chassis speed.

| Category | Default normal closing speed |
| --- | --- |
| Ignored | Below 1.5 m/s, separating or invalid data |
| Minor | 1.5 to below 5 m/s |
| Moderate | 5 to below 12 m/s |
| Major | 12 m/s or more |

Thresholds are exported on each `ImpactDetector`. Classifier enforces ordered comparisons even if tuning is inconsistent. Ignore `abs(n.y) > 0.65`: ordinary floor/ramp support and landings get no crash event. Suspension rays themselves are not rigid-body contacts. One event is allowed at the start of a contact episode, with 0.35 s without contact required to rearm and a 0.12 s per-reporting-body event interval. The strongest contact in the first eligible step sets severity; a continuing scrape does not later upgrade to major while still touching. Recovery/respawn grants 0.35 s grace. Time uses the physics frame clock, so a temporarily frozen body does not retain an episode indefinitely.

### Optional major-impact exaggeration

Disabled by default. On a fresh major collision, each enabled vehicle applies its own planar central impulse `J = planar_normal * clamp(mass * closing_speed * impulse_scale, 0, linear_cap)`. Defaults: scale **0.04**, cap **700 N·s** (at most **0.5 m/s** added at 1,400 kg). Separately apply only the yaw component of `(contact - body_origin - world_COM_offset).cross(J)`, clamped to **±180 kg·m²/s**. Use the state's `apply_central_impulse` and `apply_torque_impulse` once; no continuous force or pitch/roll torque is added. Existing contact physics still supplies its normal collision response.

The lower instance ID owns vehicle-pair presentation, while each enabled participant independently owns its own response. With matching settings the planar pushes oppose each other; mixed settings are possible for experimentation and are not a balanced competitive configuration. Do not enable this to conceal handling issues. Destroyed/combat-disabled participants receive no added reaction. Defaults for mass, power, steering, braking, grip, damping, suspension, center of mass, AI, weapons and recovery are unchanged.

### Camera/effect limits and tuning

Camera follow settings are preserved. Moderate offsets peak at 0.06 m over 0.18 s; major at 0.18 m over 0.32 s. Vertical offset is 60% of horizontal amplitude; envelopes decay to zero with no RNG or persistent impairment. Exported amplitudes have a hard 0.3 m runtime ceiling. Minor bumps do not shake. Eight scene-local mesh bursts maximum, 8/12/16 line segments for minor/moderate/major, durations 0.26/0.34/0.42 s; no debris rigid bodies or terrain modification.

The 16-contact limit suits two simple boxes and static arena geometry, not a general pileup detector. Ground-like normals and low-speed scrapes are intentionally silent. Retest when changing engine/backend, collider complexity, physics tick rate or contact-reporting limits. Human Windows/controller testing must judge noise, camera comfort, control recovery and optional impulse stability.

API references verified during implementation: [PhysicsDirectBodyState3D](https://docs.godotengine.org/en/stable/classes/class_physicsdirectbodystate3d.html), [RigidBody3D contact reporting](https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html), and [GodotPhysics3D contact snapshot construction](https://github.com/godotengine/godot/blob/4.7-stable/modules/godot_physics_3d/godot_body_pair_3d.cpp). Local engine confirmed 4.7.2.stable.official.ed1daf0bf; actual rotated-body/head-on/side scenarios validate coordinate/sign assumptions.

## Recovery and respawn

Manual reset and automatic fall recovery restore the recorded spawn transform and clear linear/angular velocity only when the destination is clear. Destroyed vehicles wait for an unoccupied spawn before healing/reenabling controls; there is currently **no fallback spawn**. The AI separately detects stuck movement and prolonged rollover and can request recovery.

## Tuning and regression procedure

1. Record current tunables and reproduce a baseline in the training/duel scene.
2. Change one group of parameters at a time; do not fix collision feel by silently degrading steering.
3. Repeat runway acceleration, hard braking, reverse, high-speed steering, ramp landing, barrier collision, and two-car collision tests.
4. Track grounded wheels, signed speed, pose, and impact outcomes. Compare both headless tests and interactive feel.
5. Document measured results, test engine version, approved defaults, limitations, and any change to multiplayer fairness.

See [TESTING](TESTING.md) for commands and [GAME_DESIGN](GAME_DESIGN.md) for desired handling identity.
