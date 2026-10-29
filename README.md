# Crash Lab v0.6

A small Godot 4 arcade vehicle combat playground for Windows PC. The default mode is a **first-to-three-eliminations match** against one blue moving rival, ending in victory, defeat, or a draw with an immediate replay option. Both vehicles share the rigid-body driving system, exchange projectile fire, collide physically, and respawn between non-final eliminations. The original continuous training playground remains available. Approved driving, camera, player weapon, and rival AI settings are preserved.

v0.6 adds procedural combat audio: distinct player/enemy shots, world impacts, accepted damage, destruction, respawn, and victory/defeat/draw cues. It does not change the approved combat balance or match rules.

## Run

1. Open `project.godot` with Godot 4.7.2 (the version validated for this prototype).
2. Press **F5** to launch `scenes/duel.tscn`. Drive, dodge the blue rival's orange shots, and line up your forward blaster. Scores and the elimination target appear at the top center, player health at the bottom left, and rival health/state at the top right and above the car.
3. The player starts at (-22, 1.25, 28), and the rival at (22, 1.25, -28). Solid boundaries and three spaced cover blocks provide maneuvering room. There is no active turret in the duel.
4. To revisit training, open `scenes/main.tscn` and press **F6**. The original runway, slalom, ramps, target dummy, and northeast turret remain there. The right-side firing range is centered on x = 48; the turret is at (40, 0, -103).
5. After a result, press **Enter** or **controller Start/Menu** to play again. Release the button before another deliberate restart press. R/D-pad remains vehicle recovery during play and never resets scores or restores health.
6. Use your normal Windows sound output. Press **M** or **D-pad down** to mute/unmute at any time, including the result screen. Audio status is shown at the bottom right; mute persists across scene restarts until the app closes.

No external assets, plugins, or downloads are required. The project uses the Compatibility renderer and Godot Physics at 120 physics ticks per second. Earlier Godot 4 versions have not been validated.

| Action | Keyboard | Controller |
| --- | --- | --- |
| Accelerate | W | Right trigger |
| Brake, then reverse | S | Left trigger |
| Steer | A / D | Left stick |
| Handbrake | Space | South face button (Xbox A) |
| Reset to starting position | R | D-pad up |
| Hold to fire blaster | Left mouse button or F | Right shoulder (Xbox RB) |
| Restart finished match | Enter | Start / Menu |
| Mute / unmute audio | M | D-pad down |

Controller steering and triggers are analog, with a 0.15 deadzone. Bindings are editable in **Project Settings → Input Map**. Opposite pedal input brakes before changing direction. Releasing the pedals allows the car to coast.

## Combat audio

The same scene-local audio observer serves both duel and training. Existing weapon, health, and match signals trigger sound; projectiles now report collision positions through their firing weapon. Audio never changes damage, cadence, movement, scoring, or AI, and synthesis uses its own seeded RNG rather than gameplay randomness.

| Event | Feedback |
| --- | --- |
| Player shot | Bright descending blaster sound at the muzzle |
| Rival/turret shot | Lower pitched blaster sound at the muzzle |
| Projectile collision | Short world impact; missed shots expire silently |
| Accepted opponent/target damage | World hit sound at the damaged actor |
| Accepted player damage | Centered damage cue |
| Destruction | World destruction burst |
| Respawn | World cue for other actors; centered cue for the player |
| Victory / Defeat / Draw | Three distinct centered result phrases |

Protected/rejected damage does not trigger a damage cue, and healing does not create false hit feedback. Muzzle and impact flashes remain as before. Match completion stops combat sounds and plays its result cue once; late combat cues are blocked until restart. Muting stops current voices immediately and suppresses new playback without changing gameplay. Unmuting does not replay an old result.

Select **CombatAudio** in either scene to tune startup **Volume Db** (default -16 dB), **World Voice Limit** (12), and **UI Voice Limit** (3). Restart after changing startup settings. Spatial sounds use distance attenuation with a 100 m cutoff and a close-range gain cap. Impact bursts are limited to one cue per 0.04 seconds. Pools reuse existing players and replace the oldest slot when full; there is no unbounded node allocation during sustained fire.

`sound_bank.gd` generates ten original mono 22,050 Hz, 16-bit PCM cues with short envelopes, controlled sample peaks, and no external assets. Streams are cached once per app session. These are intentionally simple synthesized placeholders. There is no music, engine loop, tire/collision audio, acoustic occlusion, or volume/settings menu in this milestone. Perceived loudness, positioning, fatigue, and cue quality need human listening on speakers/headphones.

## Match rules and lifecycle

A fresh duel automatically starts **Playing**, with scores at zero. Destroying the rival awards one player elimination; destroying the player awards one rival elimination. Each destruction is credited once until that vehicle respawns. The first participant to reach **three** wins. Change **Duel → MatchController → Elimination Target** to configure the target. It is a scene setting; save it before launching if it should persist across restarts.

Eliminations are grouped by the physics tick in which destruction signals occur. At the next physics boundary the controller resolves the completed tick as a batch, regardless of callback order. Both valid eliminations receive points. If both reach the target in that tick, the result is **Draw**; if only one reaches it, that participant wins. A result normally appears within one 120 Hz physics step of the decisive destruction. There are no rounds or match timer.

Non-final eliminations retain existing destruction countdowns, safe spawn checks, and spawn protection. At the winning elimination, the match becomes **Finished** and shows **Victory**, **Defeat**, or **Draw**, final scores, and restart controls. Both cars freeze in place with zero momentum. Damage is rejected, health timers stop, pending respawns and recovery resets are cancelled, input providers stop, and weapons reject firing. Existing projectiles and muzzle/impact flashes are removed. The camera and arena remain visible behind the result overlay. The physics tree is not globally paused, so restart input remains available.

Restart reloads the duel scene: scores, health, vehicles, AI state, cooldowns, effects, signal connections, and the result display are rebuilt. Both cars return to their original clear starting positions with the original initial protection state (no initial shield; protection still applies after ordinary respawns). Held physical driving inputs can naturally become active again in the new match. Restart works only while Finished, only once per request, and requires release after a reload to avoid a held key skipping a later result.

Match rules are local to `duel.tscn`. Training has no match controller, scoring, or result gate and continues to respawn practice actors indefinitely.

### Architecture

`scripts/match/duel_match.gd` owns scoring, completed-tick event batches, Playing/Finished state, result, and restart. It connects to health destruction/respawn signals rather than polling zero health. `scripts/debug/match_hud.gd` observes score/result signals and owns their presentation.

On completion the controller calls the participants' explicit `finish_combat()` hook. Vehicle, health, input, and weapon components stop their own responsibilities; health and weapons retain durable guards against further damage, processing, or direct firing calls. The chassis integration path also ignores reset/force work after completion. Training never invokes these hooks. No global match singleton or global pause is introduced. Driving forces, geometry, collision masks, camera settings, projectile tuning, AI logic, and input bindings from v0.4 are unchanged apart from the new restart action.

## Structure

- `scenes/duel.tscn`, `scripts/duel_arena.gd`: default duel with one player, one rival, cover, and boundaries.
- `scenes/main.tscn`: original v0.3 training scene, vehicle, camera, and debug overlay.
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
- `scenes/vehicles/rival_car.tscn`, `scripts/enemies/rival_driver.gd`: inherited muscle car with blue visuals and an AI command provider.
- `scripts/combat/vehicle_hurtbox.gd`: projectile-only area covering the visible body/roof, without changing the physical chassis.
- `scripts/debug/rival_hud.gd`: duel controls, rival name/health/state, and floating nameplate.
- `tests/rival_smoke.gd`, `rival_soak.gd`: deterministic duel checks and a one-minute unattended encounter.
- `scripts/match/duel_match.gd`, `scripts/debug/match_hud.gd`: duel scoring, result lifecycle, keyboard/controller restart, and match UI.
- `tests/match_smoke.gd`, `tests/fixtures/tick_damage.gd`: match/restart checks, including real damage callbacks before and after the controller in one physics tick.
- `scripts/audio/sound_bank.gd`, `combat_audio.gd`: original procedural cues, scene signal wiring, bounded spatial/centered playback pools, mute, and result/restart lifecycle.
- `tests/audio_smoke.gd`: waveform, event dispatch, rate limiting, mute, playback, and lifecycle checks.
- `tests/run_checks.ps1`: editor/startup validation and all seven suites; also rejects Godot runtime errors even when the engine exits with code zero.

## Rival behavior and tuning

The rival inherits the muscle car's physics, weapon, and health components. Its `DriverInput` node runs `rival_driver.gd`, which supplies the existing throttle/brake/steering/fire/reset commands and never reads player input. The vehicle controller still performs all physical movement. The rival has **120 HP**, a **four-second** destruction delay, and **1.5 seconds** of spawn protection. Enemy shots travel at **28 m/s**, deal **10 HP**, and fire at **0.8 shots/s**; player blaster settings are unchanged.

Outside engagement range, or when the player is hidden, destroyed, or protected, it patrols four world-space waypoints. A visible living player within **60 m** triggers pursuit. It slows for turns, aims for **14 m/s** on straights, and reduces speed within a **10 m** following distance. If too close with the barrel off target, it briefly reverses to regain turning room. Shooting requires a clear muzzle-to-player view, range within **35 m**, and a forward aim error of at most **9 degrees**. It has no turret, homing, or predictive aiming.

Three short obstacle rays steer toward the clearer side and reduce speed. Sustained low progress for **two seconds** triggers **1.6 seconds** of reverse recovery. Three failed recovery attempts request a safe reset; sustained rollover also requests a reset after **four seconds**. Ordinary forward progress clears failed attempts. Resets use the physics integration path, never per-frame teleport following. AI state, firing commands, cooldown, and recovery timers clear on respawn.

Tune engagement range, desired speed, following distance, firing range, aim tolerance, fire cadence, obstacle lookahead, stuck delay, reverse duration, rollover delay, failed-attempt count, and patrol points on **Rival → DriverInput**. Patrol points are world positions. Tune enemy projectile settings on **Rival → Blaster** and health/respawn on **Rival → DamageReceiver**. The AI applies `fire_cadence` to its weapon at startup. Restart after changing startup settings.

### Collision, damage, and safe spawning

Both cars use physical layer 2 and now include layer 2 in their collision masks, so collisions transfer momentum instead of allowing cars to pass through. Collisions do not cause health damage. The short chassis collider, mass, center of mass, driving forces, steering, traction, suspension, and damping retain their approved values. Body color is an exported visual setting; the player keeps its original orange default.

The visible roof extends above the physical chassis. A separate damage-only area on layer 3 covers the body/roof so level forward shots can hit the opponent without raising the physical collider. Projectile sweeps include this layer and exclude both the shooter's rigid body and its damage areas. This is a simple box approximation, not detailed damage.

All vehicle reset requests check the spawn chassis shape with a 0.3 m margin against arena/vehicle colliders. Destroyed vehicles wait with controls and firing disabled if their own spawn is occupied. Health and protection restore only after physics integration confirms a completed reset. Move off an occupied spawn to let its owner return; there is no forced overlap or alternate-spawn teleport. Each car returns to its own initial spawn. Manual recovery does not heal. The turret and dummy retain their existing in-place respawn behavior in training.

Camera distance, height, response, and smoothing settings are preserved. Long duel tests exposed a floating-point axis error in planar vector interpolation during heading reversals; the implementation now interpolates the equivalent yaw angle to keep the same smoothing without that error.

## Combat loop and tuning

The player starts with **100 HP**. Orange turret shots deal **15 HP**, travel at **26 m/s**, and fire at **0.75 shots/s**. The stationary turret smoothly aims at the player's current position without predicting movement. It requires an unobstructed view within **38 m**, alignment, and a **one-second warning** before firing. The HUD announces locking/firing, and the turret has a floating health/status label. Cover, range, player destruction, or spawn protection breaks its lock; reacquiring requires another warning. Projectiles already in flight continue normally.

In training, the turret has **120 HP** (six default blaster hits) and returns **six seconds** after destruction. Its gun hides and stops firing while destroyed. Player death darkens the car, disables driving/firing/reset input, and shows a **three-second respawn countdown**. The wreck retains physical momentum while waiting. Automatic respawn requests the existing physics reset, clearing momentum at the player's original spawn and restoring full health with **1.5 seconds of damage protection**, subject to spawn clearance. Normal R/D-pad recovery does not restore health. Physical collisions do not cause health damage in this milestone.

Tune player health, respawn delay, and protection on **MuscleCar → DamageReceiver**. Tune turret health, respawn delay, range, warning time, and aim response on **EnemyTurret**. Open its scene to tune **Head → Blaster** projectile speed, damage, cadence, lifetime, and orange color. Player blaster defaults, all chassis driving parameters, and the camera are preserved. The health component only gates input during destruction and issues the existing reset command; it does not retune physics.

## Weapon and target tuning

Select **Player → Blaster** in the duel (or **MuscleCar → Blaster** in training) to tune fire rate (7 shots/s), projectile speed (110 m/s), damage (20 HP), and lifetime (2 seconds). Ammo is unlimited. The weapon reads `fire_requested` from the input provider and has no recoil or influence on chassis physics. Established player driving and weapon settings are preserved.

Player shots follow the front barrel's forward direction in world space, including chassis pitch on ramps. There is no screen-center aim correction, player turret, homing, inherited chassis velocity, or gravity. Every physics tick sweeps a ray from the previous position to the next, using collision layers 1 (arena/targets/turret), 2 (vehicles), and 3 (damage areas). The firing body and its areas are excluded, and rays detect starting inside other solid obstacles. The first hit stops the shot. Damage calls `take_damage(amount)` on the collider/area or its `DamageReceiver` child, allowing health to remain separate from vehicle physics. Shots disappear on impact or expiry. Cyan player and orange enemy tracers are visual; collision uses a zero-width ray.

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
godot --headless --path . --fixed-fps 120 --script res://tests/rival_smoke.gd
godot --headless --path . --fixed-fps 120 --script res://tests/rival_soak.gd
godot --headless --path . --fixed-fps 120 --script res://tests/match_smoke.gd
godot --headless --path . --fixed-fps 120 --script res://tests/audio_smoke.gd
```

On Windows, run everything with `./tests/run_checks.ps1 -Godot 'FULL_PATH_TO_YOUR_GODOT_EXECUTABLE'`. The runner fails on nonzero exit codes and reported script/runtime errors. The new suites have explicit simulated-time watchdogs and bounded physics loops.

Editor import and headless launch completed without script or scene errors. The physics suite checks settling on four wheels, forward acceleration, braking, reverse, right steering while upright, handbrake stability, reset with cleared momentum, collision against a solid barrier, traversal of the ramp pair with upright landing, and automatic fall recovery. It uses synthetic Input Map actions; failures return a nonzero exit code. Forward acceleration reached approximately 18.46 m/s after three seconds. These checks verify behavior, not enjoyable driving feel.

For v0.6, all **131 behavior checks** pass: the previous 102 plus 29 audio checks. Audio checks verify non-silent bounded PCM with quiet endpoints, distinct cues, deterministic generation without disturbing gameplay RNG, stream caching, no false initial/blocked/healing feedback, real weapon/impact signals, existing fire cadence, spatial muzzle placement, bounded/rate-limited pools, centered player damage, destruction/respawn, all result variants, post-result suppression, actual M and D-pad mute input events, held-button behavior, mute persistence, observer reconnection, and training audio. The match restart test now counts scoring connections specifically because health also has an audio observer; its duplicate-score protection remains covered. The original driving acceleration result remains approximately 18.46 m/s after three seconds.

The additional **60-second default duel simulation** passes: the rival traveled approximately 235 m, stayed upright for all 7,200 physics frames, required zero resets, fired 27 shots, and destroyed a stationary player twice across respawns, producing a 0–2 score. It verifies score/state consistency in addition to the original movement and stability criteria; the default encounter remains Playing at 60 seconds. Results depend on engine/version; the simulation does not rate driving or combat feel. Editor import and default scene startup also pass without reported script/runtime errors.

The user approved human/controller playtests through v0.5. Headless v0.6 checks validate waveform data and event/pool behavior without starting device playback; accelerated dummy-mixer playback is deliberately skipped. The audio suite was also run graphically on Windows, where real spatial playback started and all checks passed without reported errors or cleanup warnings. This verifies engine playback state, not perceived sound quality. Human listening, speaker/headphone mix, and physical controller mute testing remain pending.

### Human playtest checklist

- Listen on speakers/headphones: distinguish player shots, enemy shots, impacts, player damage, and destruction while moving.
- Check nearby/distant sound positioning and whether sustained firing becomes harsh or masks useful cues.
- Finish and restart a match; check the correct result phrase, stopped combat tails, and clean playback afterward.
- Mute/unmute with M and a physical controller's D-pad down, including on the result screen and across replay.
- Revisit training with F6 and listen to dummy/turret damage and respawns.
- Confirm the approved handling, combat balance, scoring, and restart behavior remain unchanged.

### Known limits

Suspension rays only contact static arena layer 1; tires are visual placeholders without rolling collision or wheel spin. There is no drivetrain/gearing simulation or advanced tire model. The player uses manual rollover recovery; the AI has a delayed recovery reset. The camera checks the desired chase line against the arena with a simple ray rather than a swept camera volume.

Visual feedback remains simple geometry; audio is procedural placeholder synthesis. Projectiles use zero-width sweeps against current physics collider positions, not continuous relative-motion sweeps for fast moving targets. Fire cadence is quantized to physics ticks. Dummy/turret respawn restores solid collision in place in training; non-final vehicle respawns wait for spawn clearance. Rival navigation is local rather than a maze planner. Match scores are in-memory only and reset on scene reload. No timer, rounds, menu, pause system, pickups, collision damage, deformation, progression, additional enemies, or new weapons are included. Sound is distance-based without wall occlusion, and voice limits can truncate older sounds. Human audio/playtesting remains necessary.
