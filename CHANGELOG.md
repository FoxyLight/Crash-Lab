# Changelog

Changes are grouped by prototype milestone. Versions are **development milestones, not release tags**. For detailed per-file history, consult the linked GitHub pull requests.

## Unreleased

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
