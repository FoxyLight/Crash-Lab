# Changelog

Changes are grouped by prototype milestone. Versions are **development milestones, not release tags**. For detailed per-file history, consult the linked GitHub pull requests.

## Unreleased

### v0.9: Impact Lab (feature branch; acceptance pending)
- Refine after human playtesting: fix one-sided reporter loss, allow bounded severity escalation after weak touches, and replace vehicle-wide suppression with independent pair episodes and queued upgrades. Reset/finish cancels both sides' queued events/reactions. Thresholds remain 1.5/5/12 m/s.
- Replace thin-line sparks with thick animated yellow-white/orange streaks and a bright center, projected above visible bodywork; major duration 0.65 s, eight-burst cap retained.
- Raise shared power to 22,000 N / 55 m/s cutoff with original steering fade independently fixed at 42 m/s. Preserve mass, brakes, reverse cutoff, grip, damping and suspension. Add configurable smooth 75–85° speed FOV.
- Measure 22.81 m/s after 3 s (previous 18.46) and 34.05 m/s after a 30 s straight run (previous 26.01); distinguish actual speeds from power cutoff. Add contact-force telemetry, high-speed/one-sided/escalation/geometry/lifecycle and comparative driving checks. All 256 local behavior checks plus rival soak pass; renewed human feel, controller, listening and balance acceptance is pending.
- Add reusable GodotPhysics3D contact telemetry and configurable 1.5/5/12 m/s minor/moderate/major normal closing-speed thresholds; ignore support contacts and coalesce sustained collisions and vehicle pairs.
- Add original severity-specific crash cues, bounded spark bursts and restrained camera offsets. Preserve weapons, health, repair, AI commands and scoring; no collision health damage. Power/FOV refinement is explicitly described above.
- Add optional one-shot planar/yaw exaggeration, disabled by default, capped at 700 N·s linear and 180 kg·m²/s angular impulse.
- Clear impact state on recovery/destruction/respawn/finish/restart; stop crash effects at results.
- Add impact checks to local/approved free CI runners and complete design/physics/architecture/testing documentation. Include graphical collision/result and before/after spark screenshots; later refinement results supersede the initial 229-check result.

## v0.8.1 — Free development foundation (merged at `9c0a242`)

### Free standard-runner Godot CI
- Add a public-repository-only GitHub Actions workflow using a single free standard Ubuntu runner and pinned official Godot 4.7.2 binary with SHA-256 verification.
- Execute editor import, default scene startup, and the nine existing smoke test suites; fail on runtime errors or nonzero exits.
- Add bounded job/command timeouts, read-only permissions, and redundant-run cancellation without uploading artifacts or caches.
- Retain local Windows Godot testing and document private-repository fail-closed behavior. Current CI success requires evidence from each commit's GitHub checks.

### Development roadmap and cost guardrails
- Track the proposed v0.8.1–v0.13 milestone sequence in `docs/ROADMAP.md`.
- Approve only free standard GitHub-hosted runners on the public repository; prohibit premium/paid runners, artifact uploads, and workflow caches.
- Document the private-repository fail-closed requirement and local Godot testing fallback.
- **No CI workflow configured** as part of these documentation changes.

### Documentation foundation
- Add tracked architecture, game-design, physics, and testing references under `docs/`.
- Add a pull request template that requires documentation impact and test reporting.
- Add documentation navigation to `README.md` while preserving the existing detailed v0.8 notes.

## v0.8 — Repair pickups
- Add non-solid, respawning arena repair pickups, shared by player and rival.
- Add health restoration API, repair feedback/audio, and collection/lifecycle regression tests.
- [PR #8](https://github.com/FoxyLight/Crash-Lab/pull/8)

## v0.7 — Player heavy cannon and weapon selection
- Add a second player weapon and controls for selection/switching.
- Add selection/cooldown HUD and exclusive-fire regression tests.
- [PR #7](https://github.com/FoxyLight/Crash-Lab/pull/7)

## v0.6 — Combat audio
- Add procedural audio cues and session mute controls.
- [PR #6](https://github.com/FoxyLight/Crash-Lab/pull/6)

## v0.5 — Duel scoring
- Add elimination target, victory/defeat/draw, result UI, and restart lifecycle.
- [PR #5](https://github.com/FoxyLight/Crash-Lab/pull/5)

## v0.4 — Moving rival
- Add a shared-physics AI-driven opponent and duel arena.
- [PR #4](https://github.com/FoxyLight/Crash-Lab/pull/4)

## v0.3 — Vehicle health and turret
- Add vehicle damage/respawn and stationary turret combat.
- [PR #3](https://github.com/FoxyLight/Crash-Lab/pull/3)

## v0.2 — First weapon
- Add player blaster, projectile hit detection, and practice target.
- [PR #2](https://github.com/FoxyLight/Crash-Lab/pull/2)

## v0.1 — Project foundation
- Initialize Godot project, test arena, player driving physics, chase camera, and base validation.
- [PR #1](https://github.com/FoxyLight/Crash-Lab/pull/1)

## Maintenance rule

Every feature or behavior-changing PR should update the appropriate section above (or `Unreleased`) **in that same PR**. Clarify whether an item is implemented, experimental, or planned; never treat a proposal as a shipped feature. Keep player-facing details in [README](README.md) and deeper explanations under [docs](docs/ARCHITECTURE.md).
