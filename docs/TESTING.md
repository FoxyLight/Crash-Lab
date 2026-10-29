# Testing and validation

> Report tests actually executed, not presumed. This document tracks the approved **v0.8.1** baseline and **v0.9** feature validation awaiting acceptance. The presence of a workflow does not establish a passing run; check its current GitHub check results. Local validation remains necessary.

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

The runner performs headless editor import and startup checks, then runs all ten test scripts at a fixed 120 FPS. It rejects nonzero process exit codes and reported `SCRIPT ERROR` / `ERROR` lines.

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
| `tests/impact_smoke.gd` | Actual head-on/glancing/side/rear/wall/ground physics, event coalescing, severity/finite data, optional impulse bounds, camera/audio dispatch, lifecycle |

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

## GitHub Actions automated validation (v0.8.1)

The repository includes [`.github/workflows/godot-headless.yml`](../.github/workflows/godot-headless.yml). When enabled on the **public** repository, it runs on push to `main` and pull requests targeting `main`, using a single standard `ubuntu-24.04` runner.

- Installs the official **Godot 4.7.2-stable Linux x86_64** release from `godotengine/godot-builds`. Verifies its published SHA-256 digest before executing the binary; checks the engine version.
- Runs headless editor import, default scene startup, and the same ten smoke suites used by the Windows PowerShell runner, including Impact Lab. Rejects nonzero engine exits, timeouts, and lines beginning `SCRIPT ERROR:` or `ERROR:`.
- Runs with read-only repository permissions, a 30-minute job timeout, five-minute per-command timeouts, and cancellation of redundant runs.
- **Cost boundaries:** job-level `github.event.repository.private == false` guard; free standard runner only; **no** uploaded test/build artifacts, package publishing, or workflow caches. Job logs and check status are retained automatically by GitHub under repository settings.
- The workflow does not install export templates, make distributable builds, use paid third-party services, or modify repository billing settings.
- If repository visibility changes to private, the hosted job must remain skipped; disable the workflow, re-evaluate billing, and continue with the local runner.

**Test reporting:** read the workflow's actual results in the GitHub Actions / Checks view. A workflow file being present or a PR being opened is **not** evidence that the suites passed. Headless Linux checks complement, but do not replace, Windows gameplay/controller/audio testing. See [ROADMAP](ROADMAP.md) for the approved zero-paid-CI policy.

## Pull request testing requirements

Every change should state: **engine version**, **commands run**, **automated outcomes**, **manual scenarios**, **what could not be tested**, and **known limitations**. Attach screenshots or short clips for visible behavior when helpful. Do not use headless passing to claim human play-feel or audio quality.

For changes involving timing/physics, add deterministic regression scenarios where practical. For lifecycle changes, check repeated restarts and stale signal connections. New scripts should enter `tests/run_checks.ps1` when runnable. Introduce CI only under the [approved free-only policy](ROADMAP.md#approved-cost-policy-for-future-ci-mandatory), without replacing manual playtesting.

See [PR template](../.github/PULL_REQUEST_TEMPLATE.md) and [ARCHITECTURE](ARCHITECTURE.md).

## v0.9 Impact Lab validation

Local Windows validation on October 29, 2026, using existing **4.7.2.stable.official.ed1daf0bf**, GodotPhysics3D and fixed 120 physics steps/sec:

- Baseline v0.8.1 (`9c0a242`): all nine existing suites passed before implementation.
- Feature: `tests/run_checks.ps1 -Godot FULL_PATH_TO_GODOT_EXE` passed editor import, default-scene startup and all ten suites without reported script/runtime errors. **229 behavior checks** (192 existing + **37 new impact checks**) plus the separate 60-second rival soak passed. New suite has bounded loops, a 100-second simulated watchdog and nonzero failure exits.
- Actual physics: low-speed contact emitted one minor event; opposing 20 m/s head-on cars reported **38.53 m/s**, one major event; fast glancing motion reported **3.64 m/s**, minor; rear-end 20 versus 8 m/s reported **11.55 m/s**, moderate; perpendicular side ram classified major. Exact values are observations, not trajectory assertions.
- Powered wall pushing produced one event, then a separated second ram produced one more. Flat-ground acceleration produced no events. Optional impulse bounds, finite contact data, unchanged health, one canonical audio/feedback dispatch, camera bounds/decay, recovery/death/respawn/finish/restart/training all passed.
- Existing behavior: driving reached **18.46 m/s** after three seconds; default duel soak traveled **235.264 m**, upright **7200/7200** frames, **0** AI resets, **27** shots, **2** stationary-player deaths and score **0–2**. This matches the approved baseline observation; no broader frame-time benchmark is claimed.
- Graphical Windows inspection (Compatibility renderer, GTX 1060): actual collision created one visible burst, with both health values intact. A presentation stress probe of 30 dispatches reached exactly **8** concurrent bursts and **0** after expiry; match completion removed all bursts and camera offset. Training loaded graphically without reported runtime errors. Actual audio playback paths executed, but listening quality was not evaluated. Screenshots: [major collision](images/impact-major.png), [result cleanup](images/impact-result.png). Result screenshot was a controlled finish fixture, not a human-played victory.
- GitHub CI: results are recorded in the feature PR checks for the pushed commit. Local success is not a claim of hosted success; consult the linked PR/run evidence in delivery. The workflow change only adds the tenth suite, preserving standard `ubuntu-24.04`, the private-repository guard, read-only permissions, no artifacts/caches and bounded execution. [GitHub's public standard-runner policy](https://docs.github.com/en/billing/concepts/product-billing/github-actions) was rechecked during implementation.

### Remaining human acceptance

- [ ] Keyboard and physical controller: compare slow bump, fast head-on, side/rear ram, glancing scrape, wall pushing and ramp driving in both arenas.
- [ ] Confirm crash strength is readable while steering stays responsive and the original driving feel is preserved.
- [ ] Listen for appropriate minor/moderate/major differentiation, no scrape spam, acceptable combat mix, and working mute.
- [ ] Assess camera comfort; reduce exported amplitudes if distracting.
- [ ] Repeat destroy/respawn, R/D-pad recovery, finish/restart and repair/weapon use near collisions.
- [ ] Compare optional exaggeration only after the default; watch for spin, flipping, launching or unfair recovery.

Human acceptance is approved through v0.8 only. **v0.9 collision feel has not been human-approved.** Automated upright/cleanup checks and screenshots cannot establish fun, controller comfort or perceived audio quality. No continuous performance profiling was performed; effect quantity, lifetime and unchanged soak behavior are the available bounds/observations.
