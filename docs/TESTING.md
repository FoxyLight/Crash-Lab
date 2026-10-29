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

## Future GitHub Actions policy: free standard runners only

**Approved constraint, not yet implemented.** The project may add GitHub Actions only for **public-repository jobs using free standard GitHub-hosted runners** (for example `ubuntu-24.04` or `windows-2025`). Larger, premium, GPU, and paid runners are prohibited. Do not configure paid integrations or external CI.

- No `actions/upload-artifact`, `actions/cache`, package publication, or any other workflow artifact/cache storage. Inspect ordinary job logs and exit codes instead. GitHub retains workflow logs and check results under its retention settings; those are not optional artifact uploads.
- Every future hosted test job must **skip when the repository is private** (for example, with job-level `if: ${{ github.event.repository.private == false }}`). If the repository becomes private, disable CI and use local testing until costs are explicitly revisited.
- Use read-only job permissions, bounded timeouts, targeted triggers, and cancellation of duplicate runs. Review GitHub's official billing/runners documentation before implementation or any cost-related workflow edit.
- Keep the existing Windows `tests/run_checks.ps1` working. If free CI cannot be verified, run tests locally rather than risk billing.

See [ROADMAP](ROADMAP.md) for the binding project cost constraint and proposed v0.8.1 acceptance criteria. **No workflow was added by this documentation change.**

## Pull request testing requirements

Every change should state: **engine version**, **commands run**, **automated outcomes**, **manual scenarios**, **what could not be tested**, and **known limitations**. Attach screenshots or short clips for visible behavior when helpful. Do not use headless passing to claim human play-feel or audio quality.

For changes involving timing/physics, add deterministic regression scenarios where practical. For lifecycle changes, check repeated restarts and stale signal connections. New scripts should enter `tests/run_checks.ps1` when runnable. Introduce CI only under the [approved free-only policy](ROADMAP.md#approved-cost-policy-for-future-ci-mandatory), without replacing manual playtesting.

See [PR template](../.github/PULL_REQUEST_TEMPLATE.md) and [ARCHITECTURE](ARCHITECTURE.md).
