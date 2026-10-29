# Crash Lab v0.2

A small Godot 4 arcade vehicle combat playground for Windows PC. Drive a placeholder muscle car through a runway, slalom, ramps, and solid obstacles, and fire a forward blaster at a respawning target dummy. AI, multiplayer, vehicle damage, progression, and environmental destruction are outside this prototype.

## Run

1. Open `project.godot` with Godot 4.7.2 (the version validated for this prototype).
2. Press **F6** with `scenes/main.tscn` open, or **F5** to run the configured main scene.
3. Start on the left runway. The handling course is to the right; the ramps are near the center.
4. Drive to the **FIRING RANGE** in the far right lane (x = 48). Approach from the south, near z = 15, and point north toward the red target at z = -12. The backstop is behind it at z = -20. Hold fire: five 20-damage hits destroy the 100 HP target, which respawns after three seconds.

No external assets, plugins, or downloads are required. The project uses the Compatibility renderer and Godot Physics at 120 physics ticks per second. Earlier Godot 4 versions have not been validated.

| Action | Keyboard | Controller |
| --- | --- | --- |
| Accelerate | W | Right trigger |
| Brake, then reverse | S | Left trigger |
| Steer | A / D | Left stick |
| Handbrake | Space | South face button (Xbox A) |
| Reset to starting position | R | D-pad up |
| Hold to fire blaster | Left mouse button or F | Right shoulder (Xbox RB) |

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
- `scenes/weapons/blaster.tscn`, `scripts/weapons/vehicle_weapon.gd`: front barrel, muzzle, tuning, and firing cooldown.
- `scripts/weapons/projectile.gd`, `hit_flash.gd`: visible swept projectiles and short-lived muzzle/impact flashes.
- `scenes/targets/target_dummy.tscn`, `scripts/targets/target_dummy.gd`: solid damage receiver, health display, hit flash, destroyed state, and automatic respawn.
- `tests/weapon_smoke.gd`: weapon, target, collision, and driving-with-fire integration checks.

## Weapon and target tuning

Select **MuscleCar → Blaster** to tune fire rate (7 shots/s), projectile speed (110 m/s), damage (20 HP), and lifetime (2 seconds). Ammo is unlimited. The weapon reads `fire_requested` from the existing input provider and has no recoil or influence on chassis physics. The vehicle physics controller and all established driving settings are unchanged from v0.1.

Shots follow the front barrel's forward direction in world space, including chassis pitch on ramps. There is no screen-center aim correction, turret, homing, inherited chassis velocity, or gravity. Every physics tick sweeps a ray from the previous position to the next, using collision layers 1 (arena/target) and 2 (vehicles). The firing chassis RID is excluded, and rays detect starting inside other solid obstacles. The first solid hit stops the shot; an object exposing `take_damage(amount)` receives damage. Shots disappear on impact or expiry. The cyan tracer is visual; collision uses a zero-width ray.

Open `scenes/targets/target_dummy.tscn` to tune maximum health (100 HP) and respawn delay (3 seconds). Health and respawn countdown appear above the target. Hits briefly flash white; destruction leaves a dark flattened placeholder and temporarily disables its collider. Respawn restores health, appearance, and collision. Physical car collisions do not invoke damage. Health, destruction, and respawn signals support future HUD or combatants without coupling them to the weapon.

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
godot --headless --path . --fixed-fps 120 --script res://tests/weapon_smoke.gd
```

Editor import and headless launch completed without script or scene errors. The physics suite checks settling on four wheels, forward acceleration, braking, reverse, right steering while upright, handbrake stability, reset with cleared momentum, collision against a solid barrier, traversal of the ramp pair with upright landing, and automatic fall recovery. It uses synthetic Input Map actions; failures return a nonzero exit code. Forward acceleration reached approximately 18.46 m/s after three seconds. These checks verify behavior, not enjoyable driving feel.

For v0.2, all 10 original driving checks and 18 weapon checks pass. Weapon checks cover held-fire cadence while accelerating, steering/handbrake compatibility, release, high-speed target hits, hit feedback, thin obstacle blocking, shots starting inside obstacles, shooter exclusion, other vehicle collision, expiry, two destruction/respawn cycles, mounted-weapon aiming through the input provider, cleanup, and physical car-to-target contact without damage. Editor import and headless launch also pass without script or scene errors.

The v0.2 project was launched in a visible Windows window and the expanded HUD was inspected. The user previously approved v0.1 driving with WASD and a controller. Automated synthetic inputs verify firing while driving in v0.2; sustained human weapon testing with keyboard/mouse and a physical controller remains pending. These results do not establish satisfying combat feel.

### Human playtest checklist

- Hold left mouse or F while driving, turning, and using the handbrake; assess shot visibility and aiming clarity.
- Shoot the range target until destroyed, wait for respawn, and repeat from multiple distances.
- Verify right shoulder firing alongside controller triggers, left stick, and handbrake; confirm original controls remain comfortable.
- Try shots near barriers and while driving over ramps; assess the effect of chassis pitch on aim.

### Known limits

Suspension rays only contact static arena layer 1; tires are visual placeholders without rolling collision or wheel spin. There is no drivetrain/gearing simulation, advanced tire model, or automatic rollover recovery (press reset). The camera checks the desired chase line against the arena; it is a simple ray, not a swept camera volume.

Weapon feedback is simple geometry without audio. Projectiles use zero-width sweeps against current physics collider positions, not continuous relative-motion sweeps for fast moving targets. Fire cadence is quantized to physics ticks, with at most one shot per tick. Target respawn restores solid collision in place; move away from its footprint before it returns. Projectile nodes and flashes are short lived rather than pooled, appropriate for this single-weapon prototype. Human combat feel and physical controller weapon behavior require hands-on review.
