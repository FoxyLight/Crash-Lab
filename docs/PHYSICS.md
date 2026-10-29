# Driving and physics

> Implementation reference for v0.8. Gameplay feel must be validated in interactive playtests; passing headless tests alone does not establish that driving is fun.

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

No dedicated impact classification, exaggerated knockback, ramming-damage system, or impact-specific camera feedback is implemented. Avoid documenting these as shipped features.

## Recovery and respawn

Manual reset and automatic fall recovery restore the recorded spawn transform and clear linear/angular velocity only when the destination is clear. Destroyed vehicles wait for an unoccupied spawn before healing/reenabling controls; there is currently **no fallback spawn**. The AI separately detects stuck movement and prolonged rollover and can request recovery.

## Tuning and regression procedure

1. Record current tunables and reproduce a baseline in the training/duel scene.
2. Change one group of parameters at a time; do not fix collision feel by silently degrading steering.
3. Repeat runway acceleration, hard braking, reverse, high-speed steering, ramp landing, barrier collision, and two-car collision tests.
4. Track grounded wheels, signed speed, pose, and impact outcomes. Compare both headless tests and interactive feel.
5. Document measured results, test engine version, approved defaults, limitations, and any change to multiplayer fairness.

See [TESTING](TESTING.md) for commands and [GAME_DESIGN](GAME_DESIGN.md) for desired handling identity.
