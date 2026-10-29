# Crash Lab v0.1

A small Godot 4 arcade vehicle physics playground for Windows PC. Drive a placeholder muscle car through a runway, slalom, ramps, and solid obstacles. Weapons, AI, multiplayer, damage, progression, and destruction are outside this prototype.

## Run

1. Open `project.godot` with Godot 4.7.2 (the version validated for this prototype).
2. Press **F6** with `scenes/main.tscn` open, or **F5** to run the configured main scene.
3. Start on the left runway. The handling course is to the right; the ramps are near the center.

No external assets, plugins, or downloads are required. The project uses the Compatibility renderer and Godot Physics at 120 physics ticks per second. Earlier Godot 4 versions have not been validated.

| Action | Keyboard | Controller |
| --- | --- | --- |
| Accelerate | W | Right trigger |
| Brake, then reverse | S | Left trigger |
| Steer | A / D | Left stick |
| Handbrake | Space | South face button (Xbox A) |
| Reset to starting position | R | D-pad up |

Controller steering and triggers are analog, with a 0.15 deadzone. Bindings are editable in **Project Settings → Input Map**. Opposite pedal input brakes before changing direction. Releasing the pedals allows the car to coast.

## Structure

- `scenes/main.tscn`: main scene, vehicle, camera, and debug overlay.
- `scenes/test_arena.tscn`, `scripts/arena.gd`: sky, lighting, and procedural static arena geometry.
- `scenes/vehicles/muscle_car.tscn`: reusable rigid chassis and player input provider.
- `scripts/vehicles/vehicle_controller.gd`: force-based driving, suspension, placeholder visuals, and recovery.
- `scripts/vehicles/player_vehicle_input.gd`: converts mapped inputs into commands; a future AI or network provider can expose the same fields.
- `scripts/camera/chase_camera.gd`: smoothed chase camera with upright heading and obstacle ray query.
- `scripts/debug/driving_debug.gd`: speed, direction, handbrake, grounded wheel count, and controls.
- `tests/driving_smoke.gd`: executable physics regression checks.

## Physics and tuning

The 1,400 kg `RigidBody3D` chassis has a box collider, continuous collision detection, and a lowered center of mass. Four downward contact rays apply spring/damper suspension forces. Each tire applies lateral velocity correction and longitudinal drive/braking forces, limited by the suspension load. Front tire directions steer; their lateral forces turn the chassis physically. Rear tire grip drops under the handbrake. No per-frame chassis teleporting is used; recovery explicitly restores the spawn transform and clears velocity inside physics integration.

Select **MuscleCar** in the main scene to tune exported parameters. Defaults include 15,000 N engine force, 24,000 N braking force, 42 m/s forward power cutoff (~151 km/h), 13 m/s reverse power cutoff, speed-sensitive steering angles, steering response, lateral traction, rear handbrake grip, tire force limit, mass, damping, suspension stiffness/damping/travel, and recovery heights. Speed limits are power cutoffs, so slopes or impacts can carry the car faster. The initial defaults are applied at startup; restart the scene after changing chassis mass/damping.

Camera distance, height, heading response, and position smoothing are exported on **ChaseCamera**. Debug speed is total velocity in km/h; direction uses the chassis forward velocity. Grounded counts suspension contacts, so a car resting on its roof may show zero.

## Validation

Validated with the existing Windows Godot **4.7.2.stable.official.ed1daf0bf** installation. Substitute your local executable for `godot` below; no machine-specific engine path is stored in the project.

```powershell
godot --version
godot --headless --path . --editor --quit
godot --headless --path . --quit-after 180
godot --headless --path . --fixed-fps 120 --script res://tests/driving_smoke.gd
```

Editor import and headless launch completed without script or scene errors. The physics suite checks settling on four wheels, forward acceleration, braking, reverse, right steering while upright, handbrake stability, reset with cleared momentum, collision against a solid barrier, traversal of the ramp pair with upright landing, and automatic fall recovery. It uses synthetic Input Map actions; failures return a nonzero exit code. Forward acceleration reached approximately 18.46 m/s after three seconds. These checks verify behavior, not enjoyable driving feel.

The project was also launched in a visible Windows game window. Visual inspection confirmed that the car, arena, chase camera, sky, and readable debug overlay render. Sustained manual driving and a physical controller have not been tested.

### Human playtest checklist

- Compare low-speed maneuvering and high-speed steering; tune for precise combat movement.
- Try keyboard pedal transitions, handbrake turns, roof recovery, ramps, and oblique impacts.
- Verify real Windows controller mapping, trigger range, deadzones, and reconnect behavior.
- Assess chase camera readability during sharp impacts and close to barriers.

### Known limits

Suspension rays only contact static arena layer 1; tires are visual placeholders without rolling collision or wheel spin. There is no drivetrain/gearing simulation, advanced tire model, or automatic rollover recovery (press reset). The camera checks the desired chase line against the arena; it is a simple ray, not a swept camera volume. Human driving feel and physical controller behavior require hands-on review.
