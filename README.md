# Crash Lab v0.3

A small Godot 4 arcade vehicle combat playground for Windows PC. Drive a placeholder muscle car through a runway, slalom, ramps, and solid obstacles, practice on a target dummy, or fight a stationary enemy turret. The player can take projectile damage, be destroyed, and respawn. Moving enemy AI, multiplayer, detailed damage, progression, and environmental destruction are outside this prototype.

## Run

1. Open `project.godot` with Godot 4.7.2 (the version validated for this prototype).
2. Press **F6** with `scenes/main.tscn` open, or **F5** to run the configured main scene.
3. Start on the left runway. The handling course is to the right; the ramps are near the center.
4. Drive to the **FIRING RANGE** in the far right lane (x = 48). Approach from the south, near z = 15, and point north toward the red target at z = -12. The backstop is behind it at z = -20. Hold fire: five 20-damage hits destroy the 100 HP target, which respawns after three seconds.
5. For combat, drive farther north to **COMBAT ZONE** in the northeast corner. The orange turret is at (40, 0, -103); approach near (40, 1, -78), face north, and keep moving while returning fire. Two cover blocks help break line of sight. The original runway spawn remains outside its 38 m detection range.

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
- `scripts/combat/vehicle_health.gd`: separate player damage receiver, destruction, input lock, and protected respawn.
- `scenes/enemies/stationary_turret.tscn`, `scripts/enemies/stationary_turret.gd`: stationary tracking enemy that reuses target health/respawn and the existing weapon.
- `scripts/debug/combat_hud.gd`: player health bar, hit overlay, death countdown, and turret warning/status.
- `tests/combat_smoke.gd`: player damage, cover, destruction, recovery, turret defeat, and repeat combat checks.

## Combat loop and tuning

The player starts with **100 HP**. Orange turret shots deal **15 HP**, travel at **26 m/s**, and fire at **0.75 shots/s**. The stationary turret smoothly aims at the player's current position without predicting movement. It requires an unobstructed view within **38 m**, alignment, and a **one-second warning** before firing. The HUD announces locking/firing, and the turret has a floating health/status label. Cover, range, player destruction, or spawn protection breaks its lock; reacquiring requires another warning. Projectiles already in flight continue normally.

The turret has **120 HP** (six default blaster hits) and returns **six seconds** after destruction. Its gun hides and stops firing while destroyed. Player death darkens the car, disables driving/firing/reset input, and shows a **three-second respawn countdown**. The wreck retains physical momentum while waiting. Automatic respawn requests the existing physics reset, clearing momentum at the original safe runway spawn and restoring full health with **1.5 seconds of damage protection**. Normal R/D-pad recovery does not restore health. Physical collisions do not cause health damage in this milestone.

Tune player health, respawn delay, and protection on **MuscleCar → DamageReceiver**. Tune turret health, respawn delay, range, warning time, and aim response on **EnemyTurret**. Open its scene to tune **Head → Blaster** projectile speed, damage, cadence, lifetime, and orange color. Player blaster defaults, all chassis driving parameters, and the camera are preserved. The health component only gates input during destruction and issues the existing reset command; it does not retune physics.

## Weapon and target tuning

Select **MuscleCar → Blaster** to tune fire rate (7 shots/s), projectile speed (110 m/s), damage (20 HP), and lifetime (2 seconds). Ammo is unlimited. The weapon reads `fire_requested` from the existing input provider and has no recoil or influence on chassis physics. The vehicle physics controller and all established driving settings are unchanged from v0.1.

Player shots follow the front barrel's forward direction in world space, including chassis pitch on ramps. There is no screen-center aim correction, player turret, homing, inherited chassis velocity, or gravity. Every physics tick sweeps a ray from the previous position to the next, using collision layers 1 (arena/targets/turret) and 2 (vehicles). The firing collider RID is excluded, and rays detect starting inside other solid obstacles. The first solid hit stops the shot. Damage calls `take_damage(amount)` on the collider or its `DamageReceiver` child, allowing health to remain separate from vehicle physics. Shots disappear on impact or expiry. Cyan player and orange enemy tracers are visual; collision uses a zero-width ray.

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
godot --headless --path . --fixed-fps 120 --script res://tests/combat_smoke.gd
```

Editor import and headless launch completed without script or scene errors. The physics suite checks settling on four wheels, forward acceleration, braking, reverse, right steering while upright, handbrake stability, reset with cleared momentum, collision against a solid barrier, traversal of the ramp pair with upright landing, and automatic fall recovery. It uses synthetic Input Map actions; failures return a nonzero exit code. Forward acceleration reached approximately 18.46 m/s after three seconds. These checks verify behavior, not enjoyable driving feel.

For v0.3, all 10 original driving checks, 18 weapon checks, and 17 combat checks pass. Weapon checks cover held-fire cadence while accelerating, steering/handbrake compatibility, release, high-speed target hits, hit feedback, thin obstacle blocking, shots starting inside obstacles, shooter exclusion, other vehicle collision, expiry, two destruction/respawn cycles, mounted-weapon aiming through the input provider, cleanup, and physical car-to-target contact without damage. Combat checks cover the safe spawn, acquisition warning, slow enemy projectiles dealing damage, HUD health, recovery without healing, cover, lethal damage/input lock, reset suppression, ignoring destroyed players, safe respawn with restored health/momentum, temporary protection and its expiry, destruction of the turret by the player blaster, no firing while destroyed, restored turret appearance/health, and combat resuming after turret respawn.

The user approved human playtests for v0.1 driving and v0.2 weapons. For v0.3, a graphical Windows launch rendered the combat approach and destroyed-car state; the health bar, damage tint, respawn countdown, turret, cover, and HUD were visually checked. Combat behavior is verified using synthetic input and physics checks. Human testing of dodging, encounter difficulty, warning readability, and the full loop on keyboard/controller remains pending. Automated checks do not establish satisfying combat feel.

### Human playtest checklist

- Enter the combat zone, watch for the locking warning, and dodge orange shots while returning fire.
- Use cover and distance to break the turret's lock; assess warning readability and difficulty.
- Destroy the turret, wait for its return, and repeat with keyboard/mouse and a controller.
- Allow the car to be destroyed; verify the countdown, safe full-health respawn, restored controls, and temporary shield.
- Confirm the established driving and firing controls remain comfortable.

### Known limits

Suspension rays only contact static arena layer 1; tires are visual placeholders without rolling collision or wheel spin. There is no drivetrain/gearing simulation, advanced tire model, or automatic rollover recovery (press reset). The camera checks the desired chase line against the arena; it is a simple ray, not a swept camera volume.

Weapon feedback is simple geometry without audio. Projectiles use zero-width sweeps against current physics collider positions, not continuous relative-motion sweeps for fast moving targets. Fire cadence is quantized to physics ticks, with at most one shot per tick. Target/turret respawn restores solid collision in place; move away from their footprints before they return. Projectile nodes and flashes are short lived rather than pooled. The turret has simple tracking and visibility checks rather than predictive aiming or moving AI. There is no armor, collision damage, vehicle deformation, player health regeneration, score, or progression. Human combat feel requires hands-on review.
