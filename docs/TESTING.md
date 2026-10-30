# Testing and validation

> Report tests actually executed, not presumed. Current merged baseline: **v0.9**, `cb76c23`. Current feature: **v0.10 Local Multiplayer**, awaiting physical-controller/two-person acceptance and merge. Older sections below retain historical evidence; they do not replace current head checks.

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

The runner performs headless editor import and startup checks, then runs all eleven test scripts at a fixed 120 FPS. It rejects nonzero process exit codes and reported `SCRIPT ERROR` / `ERROR` lines.

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
| `tests/multiplayer_smoke.gd` | Independent raw input/device slots, two shared-world views/HUDs, simultaneous driving/fire, damage credit, safe alternate spawns, repeated local matches |

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
- Runs headless import, default startup and the same eleven suites as the Windows runner, including Impact Lab and multiplayer. Rejects nonzero exits, timeouts and lines beginning `SCRIPT ERROR:` or `ERROR:`.
- Runs with read-only repository permissions, a 30-minute job timeout, five-minute per-command timeouts, and cancellation of redundant runs.
- **Cost boundaries:** job-level `github.event.repository.private == false` guard; free standard runner only; **no** uploaded test/build artifacts, package publishing, or workflow caches. Job logs and check status are retained automatically by GitHub under repository settings.
- The workflow does not install export templates, make distributable builds, use paid third-party services, or modify repository billing settings.
- If repository visibility changes to private, the hosted job must remain skipped; disable the workflow, re-evaluate billing, and continue with the local runner.

**Test reporting:** read the workflow's actual results in the GitHub Actions / Checks view. A workflow file being present or a PR being opened is **not** evidence that the suites passed. Headless Linux checks complement, but do not replace, Windows gameplay/controller/audio testing. See [ROADMAP](ROADMAP.md) for the approved zero-paid-CI policy.

## Pull request testing requirements

Every change should state: **engine version**, **commands run**, **automated outcomes**, **manual scenarios**, **what could not be tested**, and **known limitations**. Attach screenshots or short clips for visible behavior when helpful. Do not use headless passing to claim human play-feel or audio quality.

For changes involving timing/physics, add deterministic regression scenarios where practical. For lifecycle changes, check repeated restarts and stale signal connections. New scripts should enter `tests/run_checks.ps1` when runnable. Introduce CI only under the [approved free-only policy](ROADMAP.md#approved-cost-policy-for-future-ci-mandatory), without replacing manual playtesting.

See [PR template](../.github/PULL_REQUEST_TEMPLATE.md) and [ARCHITECTURE](ARCHITECTURE.md).

## Initial v0.9 Impact Lab validation (before playtest refinement)

Historical initial Windows validation on October 29, 2026, before the refinement below, using **4.7.2.stable.official.ed1daf0bf**, GodotPhysics3D and fixed 120 physics steps/sec:

- Baseline v0.8.1 (`9c0a242`): all nine existing suites passed before implementation.
- Feature: `tests/run_checks.ps1 -Godot FULL_PATH_TO_GODOT_EXE` passed editor import, default-scene startup and all ten suites without reported script/runtime errors. **229 behavior checks** (192 existing + **37 new impact checks**) plus the separate 60-second rival soak passed. New suite has bounded loops, a 100-second simulated watchdog and nonzero failure exits.
- Actual physics: low-speed contact emitted one minor event; opposing 20 m/s head-on cars reported **38.53 m/s**, one major event; fast glancing motion reported **3.64 m/s**, minor; rear-end 20 versus 8 m/s reported **11.55 m/s**, moderate; perpendicular side ram classified major. Exact values are observations, not trajectory assertions.
- Powered wall pushing produced one event, then a separated second ram produced one more. Flat-ground acceleration produced no events. Optional impulse bounds, finite contact data, unchanged health, one canonical audio/feedback dispatch, camera bounds/decay, recovery/death/respawn/finish/restart/training all passed.
- Existing behavior: driving reached **18.46 m/s** after three seconds; default duel soak traveled **235.264 m**, upright **7200/7200** frames, **0** AI resets, **27** shots, **2** stationary-player deaths and score **0–2**. This matches the approved baseline observation; no broader frame-time benchmark is claimed.
- Graphical Windows inspection (Compatibility renderer, GTX 1060): actual collision created one visible burst, with both health values intact. A presentation stress probe of 30 dispatches reached exactly **8** concurrent bursts and **0** after expiry; match completion removed all bursts and camera offset. Training loaded graphically without reported runtime errors. Actual audio playback paths executed, but listening quality was not evaluated. Screenshots: [major collision](images/impact-major.png), [result cleanup](images/impact-result.png). Result screenshot was a controlled finish fixture, not a human-played victory.
- GitHub CI: [run 40915139484](https://github.com/FoxyLight/Crash-Lab/actions/runs/40915139484) **passed** on implementation commit `fd4cbcf` in [PR #12](https://github.com/FoxyLight/Crash-Lab/pull/12). Hosted Linux logs confirm all ten suites, including 37 impact checks with zero failures. Later documentation-only commits receive their own check; consult the current PR checks for the latest head. The workflow change only adds the tenth suite, preserving standard `ubuntu-24.04`, the private-repository guard, read-only permissions, no artifacts/caches and bounded execution. [GitHub's public standard-runner policy](https://docs.github.com/en/billing/concepts/product-billing/github-actions) was rechecked during implementation.

### Remaining human acceptance

- [ ] Keyboard and physical controller: compare slow bump, fast head-on, side/rear ram, glancing scrape, wall pushing and ramp driving in both arenas.
- [ ] Confirm crash strength is readable while steering stays responsive and the original driving feel is preserved.
- [ ] Listen for appropriate minor/moderate/major differentiation, no scrape spam, acceptable combat mix, and working mute.
- [ ] Assess camera comfort; reduce exported amplitudes if distracting.
- [ ] Repeat destroy/respawn, R/D-pad recovery, finish/restart and repair/weapon use near collisions.
- [ ] Compare optional exaggeration only after the default; watch for spin, flipping, launching or unfair recovery.

At this historical test point v0.9 acceptance was pending; v0.9 has since merged at `cb76c23`. v0.10 two-person/controller acceptance remains pending. Automated upright/cleanup checks and screenshots do not establish fun, comfort or audio quality.

## v0.9 playtest refinement validation

The user reported unreliable collision feedback, hard-to-see sparks and sluggish acceleration. These results supersede the initial build's current-behavior claims, using the same Windows Godot 4.7.2 and 120 Hz engine setup.

- **Diagnosis:** real one-sided-contact and minor-bump-then-major regressions failed on the original implementation. The original component also used a vehicle-wide event interval that discarded another collider's event; the corrected two-wall fixture isolates this with two actual hits within 14 physics ticks. None required lowering the 1.5/5/12 m/s severity thresholds. Physical 55 m/s opposing/side/rear/glancing and thin-wall scenarios did not reproduce tunneling, so CCD, contact-monitor configuration and chassis geometry remain unchanged. This does not prove arbitrary roof/pileup collisions.
- **Local full runner:** `tests/run_checks.ps1 -Godot FULL_PATH_TO_GODOT_EXE` passed import, startup and all ten suites: **256 behavior checks**, including **19 driving** and **55 impact**, plus the separate 60-second AI soak. No reported script/runtime errors. Driving uses a 120-second simulated watchdog; impact uses 100 seconds. After the final visual contrast adjustment, the affected impact suite was rerun: 55 checks, zero failures.
- **Physics/event counts:** one-sided actual collision = **1 major**; minor physical bump then forceful contact = **1 minor + 1 major**, no further spam; two close distinct walls = **2 majors**. Opposing 55 m/s cars = **107.99 m/s** measured closing, **1 major**, ~**4.27 m** final center separation, both upright and no pass-through. A 55 m/s side ram and rear-end each report one major; high tangential speed remains non-major when normal closing is small. A 0.15 m wall stops the 55 m/s body without tunneling. Sustained pushing and ordinary ground filtering still pass.
- **Measured powertrain comparison:** training 3 s speed **18.46 → 22.81 m/s** (+24%). Same long straight fixture, 6 s **24.12 → 30.93**, 30 s **26.01 → 34.05 m/s** (+31%). Cutoff **42 → 55 m/s** is distinct from actual speed. Requested/applied longitudinal forces match at the measured steady samples (new ~13,569 N), so the tire-force limit does not clip them. Effective damping remains 0.22/s. Existing braking/reverse/steering/handbrake/ramp landing/recovery checks pass. FOV rises smoothly from 75° to ~84.08° at measured terminal speed and returns after recovery.
- **AI:** unchanged desired-speed/aim/fire/recovery settings. Full 60 s default simulation: **149.65 m**, **7200/7200 upright frames**, **0 resets**, **13 shots**, **1 stationary-player death**, score **0–1**, Playing. The older powertrain produced 235.26 m/27 shots/2 deaths. A changed route is expected from changed power and is not evidence of balanced/fun combat. No golden route assertion was weakened.
- **Graphical Windows inspection:** actual 55 m/s head-on fixture produces **1 burst**; normal chase screenshots show the bright center and thick yellow/orange streaks near **0.42 s**. A 30-dispatch probe caps at **8 bursts**, returns to **0**, and match finish leaves **0 bursts / 0 shake**. Both arenas load graphically without reported runtime errors. [Before](images/impact-major-before.png), [refined center](images/impact-major.png), [refined later streaks](images/impact-major-late.png), [controlled result cleanup](images/impact-result.png). These are inspected real renders, not claims based solely on headless success. The result image is a fixture, not a human-played victory.
- **Geometry/lifecycle tests:** major has 18 quads/108 vertices plus its low-resolution center, thick triangle width, unshaded colors, outward movement, center fade, visible lifetime beyond 0.42 s and complete expiry after 0.65 s. Surface projection retains contact x/z and clears bodywork. Existing restart/health/weapons/scoring/pickups regressions remain in the unchanged full runner.
- **CI:** refinement [run 40919581352](https://github.com/FoxyLight/Crash-Lab/actions/runs/40919581352) passed 256 checks in [PR #12](https://github.com/FoxyLight/Crash-Lab/pull/12), subsequently merged at `cb76c23`. No runner, artifact/cache policy, billing setting or private guard changed in that refinement.

This v0.9 section is historical; use the v0.10 checklist below for current acceptance. Controller driving/audio quality cannot be established by automated fixtures.

## v0.10 local multiplayer validation

Windows, existing **Godot 4.7.2.stable.official.ed1daf0bf**, GodotPhysics3D at 120 Hz, Compatibility/OpenGL renderer. Base `cb76c23` was fetched from main and all 256 existing checks passed before edits.

### Automated evidence

- `tests/run_checks.ps1 -Godot FULL_PATH_TO_GODOT_EXE`: editor import, default AI-duel startup and **all eleven suites pass**, **326 behavior checks** (256 existing + **70 multiplayer**) plus the separate 60 s AI soak. Failures are nonzero; the new suite has bounded steps and a 120-second simulated watchdog. No reported script/runtime errors. Existing test assertions were not weakened or rewritten.
- Raw native key events through `Input.parse_input_event` physically drive/fire only P1. Synthetic JoypadMotion/JoypadButton events use the production router method and inventories with IDs **3, 9 and 14**: separate analog steering/triggers, deadzone, handbrake, simultaneous driving/fire, independent selection/cooldown/recovery, ignored unassigned IDs, stable slots after disconnect, neutral reconnect and no duplicate/held cycles. A disconnected owner stops without cancelling the other player's pending recovery. Dead/respawn-held inputs cannot switch weapons or bypass respawn.
- These fixtures **do not create virtual hardware**. Inventories are reinjected after test reloads; production enumeration uses actual `Input.get_connected_joypads()` and hotplug signals. The graphical engine reported **no connected controllers**. Actual Windows device mapping, reconnect enumeration and two-person controller feel are still manual requirements.
- Both cameras track explicit actors and share the exact root World3D; each HUD receives its own actor. Resize maintains two equal views and correct health state. Per-player health/damage/weapon/repair HUDs, session mute, one result and repeated controller-mode/HUD reconstruction are checked.
- Actual projectiles from **each** human earn the correct score via physical collider/hurtbox receivers. Self/unattributed lethal calls give **zero points** in local mode; a nonlethal earlier attacker is not reused. Same-tick winning trades produce **1–1 draw**. Dead-life deduplication, no shooting after finish and repeated reload cleanup pass.
- Occupied primary waits through the configured delay, then picks the first clear supported alternative. Health/input/shield/source state restore only after integration acknowledges the reset. If every candidate is occupied, no healing/firing/unsafe reset occurs; clearing one candidate resumes respawn. Existing AI primary-only spawn tests continue unchanged.
- An actual opposing **55 m/s** local collision stops both chassis, leaves >4 m separation, emits **one canonical major** and reaches **both camera reactions / one crash sound**. One shared major spark uses 216 crossed-quad vertices, not two particle simulations; expiry and result cleanup pass. All original 55 impact checks still pass.
- Original driving observation remains **22.81 m/s at 3 s**; straight-run **34.05 m/s at 30 s**. Default AI soak remains **149.65 m**, **7200/7200 upright frames**, **zero resets**, **13 shots**, **one stationary-player death**, score **0–1**. No v0.9 tuning changes were needed.

Hosted [run 40936246949](https://github.com/FoxyLight/Crash-Lab/actions/runs/40936246949) **passed all 326 checks / eleven suites** on implementation head `6cde0d7` in [PR #13](https://github.com/FoxyLight/Crash-Lab/pull/13). Logs confirm 70 multiplayer checks with zero failures. Documentation-only follow-ups receive their own check; consult the current PR head. The only workflow edits add the eleventh suite/name. Standard `ubuntu-24.04`, public-only guard, read-only permissions, timeouts, cancellation and no artifacts/caches are retained. [GitHub's public standard-runner policy](https://docs.github.com/en/billing/concepts/product-billing/github-actions) was rechecked; no billing settings changed.

### Graphical Windows inspection and performance

Real rendered captures: [initial split](images/local-duel.png), [one physical crash in both views](images/local-collision.png), [resized](images/local-resized.png), [protected respawn](images/local-respawn.png), [shared result](images/local-result.png). These are controlled/scripted engine fixtures, not two-person playtest claims. The result fixture temporarily uses a two-point target; the shipped default remains three. Collision capture records **one burst** and **0.17 s shake remaining in each view**, with both health values intact. Respawn returns P2 to **100 HP**, **~1.27 s protection**, the same two views and clean feedback. Result/restart clears shared effects/projectiles and rebuilds the split. Final graphical cleanup completed without reported script/runtime errors or leaked-object warnings after allowing the real audio mixer to release stopped playback.

The project uses its existing 1280×720 logical canvas/aspect policy. Default views are **1280×345 each**, separated by a 30 px shared strip. A **960×640** window request retains project aspect scaling/letterboxing (capture render area 960×540); both HUDs/views remain aligned. No per-view physics/arena duplication or new camera tuning.

A short rendering probe used **GTX 1060 6 GB, driver 582.78, Windows OpenGL Compatibility**, uncapped frame rate/vsync disabled in the probe process only. Compare the **same local scene/two actors** with P2 rendering hidden (one 1280×690 view) against two 1280×345 views, keeping approximately equal total render pixels. Each phase warmed up 90 rendered frames, sampled **3 wall-clock seconds**, drove both cars from 30 m/s with throttle, fired both blasters and repeatedly added bursts up to the cap. No headless test ran concurrently.

| Observed render phase | Samples | Mean frame | p95 | p99 | Mean FPS | Shots / peak bursts |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| One-view control, same two physical actors | 544 | 5.52 ms | 7.29 ms | 8.32 ms | 181.3 | 48 / 8 |
| Horizontal split | 546 | 5.50 ms | 7.12 ms | 7.76 ms | 181.7 | 48 / 8 |

The difference is within short-run noise, **not proof that a second camera is free**. This is one small scene, one machine, equal total pixels and a brief synthetic workload, not an isolated GPU benchmark or long-session frame-pacing guarantee. Higher resolutions, other GPUs, real two-person combat and resize/respawn/restart hitches still need observation. No paid profiler/services, new assets, CI artifacts or caches were used.

### Required human Windows acceptance

**October 30 audio follow-up:** user heard only the win cue. A graphical `AudioEffectCapture` on the Master bus confirmed zero spatial output with the root listener, while the centered victory cue peaked at 0.076070. Hosting the midpoint listener in the first camera-bearing SubViewport and enabling 3D audio only there restores spatial output without increasing gain. The multiplayer topology assertion now checks that exact listener/view/camera relationship. Existing signal-dispatch and `.playing` checks could not detect this routing failure.

Run the additional real-mixer regression on Windows with an active audio device (not headless, and without accelerated fixed FPS):

```powershell
godot --path . --script res://tests/audio_output_smoke.gd
```

All **15 output checks pass** on the existing Godot 4.7.2 / Windows Compatibility renderer. Both real weapon events produce nonzero mixer frames at their authored starts (peak ~0.0151); ten spatial gameplay cues at the listener produce peaks ~0.0293–0.0662; mute produces silent frames; winner output and spatial firing after scene reload pass. The script has a 30-second timeout, returns nonzero on failure, and rejects headless/dummy audio drivers. These are engine mixer measurements, not physical speaker or human loudness/quality acceptance. The 326 headless behavior checks and separate AI soak remain the normal CI suite; this optional graphical check requires a real audio driver.

**October 30 camera follow-up:** user reported other gameplay looked/felt good but the camera was too far back/stretched. Local framing now uses 6.5 / 2.4 / 0.55 m distance/height/focus, 110–115° **horizontal** FOV (previously ~141–147° horizontal via the vertical lens). The existing multiplayer camera check now verifies that profile and independent speed response. Real Windows captures inspect both full cars at rest, both at ~112 km/h (113.53° horizontal FOV), and resized layout: [before](images/local-camera-before.png), [after](images/local-duel.png), [moving](images/local-camera-speed.png), [resized](images/local-resized.png). Own floating nameplates are excluded from only their own camera; HUD identity remains and opponents still see labels. Earlier collision/respawn/result images and performance measurements above predate this framing change. Human camera recheck and merge remain pending; positive feedback elsewhere is not merge approval.

- [ ] Keyboard/mouse P1 + one physical pad P2: every control, simultaneous driving/fire and no cross-control.
- [ ] Two separate pads: F2 setup, correct device slots, analog ranges/deadzones and independent handbrake/recovery/switching.
- [ ] Unplug either pad while moving/firing/holding Y; remaining player keeps control. Reconnect/release to neutral, including reversed connection order and restart while Start is held.
- [ ] Repeated full first-to-three matches: P1 win, P2 win, trade/draw, protected respawns, spawn camping/alternatives, no stale HUDs or sounds.
- [ ] Judge half-height target readability, speed FOV, aiming comfort, crash shake/sparks, keyboard/controller driving feel and fair weapon/repair use.
- [ ] Listen to shared-speaker audio, verify mute from either participant and session persistence. No per-player headphone mix/occlusion is claimed.
- [ ] Resize/fullscreen and watch active combat, high speed, maximum sparks, respawn and restart for frame-time spikes. The probe is not human performance acceptance.
- [ ] Revisit AI duel and training interactively to confirm approved v0.9 feel remains intact.
