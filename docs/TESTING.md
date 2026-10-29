# Testing and validation

> Report tests actually executed, not presumed. This document tracks the **v0.8** workflow. There is currently **no GitHub Actions CI** configured; local validation remains necessary.

## Environment

- Target: Windows PC, Godot 4.x / GDScript; the [README](../README.md) reports validation with **Godot 4.7.2.stable**.
- Project root contains `project.godot`.
- Local Godot directory supplied for development: `E:\Backup\Downloads\Godot`. Find the actual executable inside; **never commit an absolute machine-specific path**.
- Godot uses 120 physics ticks/sec for this project.

## Run the full Windows validation

From the repository root in PowerShell:

```powershell
# Replace the placeholder with the actual Godot executable path.
.\tests\run_checks.ps1 -Godot "FULL_PATH_TO_GODOT_EXE"
```

The runner performs headless editor import and startup checks, then runs all nine test scripts at a fixed 120 FPS. It rejects nonzero process exit codes and reported `SCRIPT ERROR` / `ERROR` lines.

## Automated suites

| File | Main coverage |
| --- | --- |
| `tests/driving_smoke.gd` | Acceleration, braking, reverse, steering, suspension, handbrake, ramp, reset, barrier |
| `tests/weapon_smoke.gd` | Firing, projectile sweeps, obstacle blocking, dummy damage/respawn |
| `tests/combat_smoke.gd` | Turret targeting, cover, vehicle health, destruction, safe respawn |
| `tests/rival_smoke.gd` | AI driving/aim, vehicle collisions, stuck recovery, spawn obstruction |
| `tests/rival_soak.gd` | Bounded 60-second unattended rival simulation |
| `tests/match_smoke.gd` | Scoring, same-tick draws, match completion, restart, repeated lifecycles |
| `tests/audio_smoke.gd` | Procedural audio and event dispatch, mute/lifecycle |
| `tests/loadout_smoke.gd` | Weapon selection, firing exclusivity, cooldown, cannon impacts |
| `tests/repair_smoke.gd` | Repair amounts, overlapping collectors, respawn, feedback/audio, match end |

The v0.8 README **reports** 192 passing behavior checks and separate duel-soak results. These figures are historical documentation, not evidence that the latest PR has been executed.

## Manual playtest checklist

- [ ] High-speed steering, braking, reverse, handbrake, jumps and rollover recovery feel responsive.
- [ ] Collisions feel heavy but do not leave the player helpless for long.
- [ ] Weapons can be distinguished visually and audibly; switching while moving is intuitive.
- [ ] Duel score, destruction, respawn and restart remain readable.
- [ ] Repair crosses are visible at speed, collect only when damaged, and cannot be exploited to stall a match unfairly.
- [ ] Test keyboard **and physical controller** inputs.
- [ ] Verify test arena and duel arena both still work.
- [ ] Watch for script/runtime errors and frame-time regressions.

## Pull request testing requirements

Every change should state: **engine version**, **commands run**, **automated outcomes**, **manual scenarios**, **what could not be tested**, and **known limitations**. Attach screenshots or short clips for visible behavior when helpful. Do not use headless passing to claim human play-feel or audio quality.

For changes involving timing/physics, add deterministic regression scenarios where practical. For lifecycle changes, check repeated restarts and stale signal connections. New scripts should enter `tests/run_checks.ps1` when runnable. Introduce CI when available, without replacing manual playtesting.

See [PR template](../.github/PULL_REQUEST_TEMPLATE.md) and [ARCHITECTURE](ARCHITECTURE.md).
