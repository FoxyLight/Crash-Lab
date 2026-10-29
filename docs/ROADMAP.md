# Crash Lab development roadmap

> **Status:** Proposed milestone sequence as of October 29, 2026. The **zero-paid-CI constraint is approved**. Milestone scope, priorities, dates, and designs can change following playtests. A milestone is complete only when implemented, validated, documented, and merged. See [GAME_DESIGN](GAME_DESIGN.md).

## North star

Build a small, polished, original Windows vehicular-combat game with responsive arcade handling, convincing physical weight, memorable crashes, different tactical weapons, reactive arenas, and enjoyable two-human-player matches. Preserve the already-approved driving baseline as new systems are introduced.

## Current baseline: v0.8 (implemented)

- Godot 4 / GDScript, one drivable muscle car with four-ray suspension and a chase camera.
- Separate training arena and default duel against a moving AI rival.
- Player blaster and heavy cannon, health/respawn, repair pickups, duel scoring, procedural audio.
- Nine tracked automated test suites, runnable locally. Historical v0.8 README reports **192 passing behavior checks**; this is not a claim that every later branch has been tested.
- Tracked architectural, design, physics, and testing documentation.
- **No GitHub Actions workflow is configured yet.**

## Approved cost policy for future CI (mandatory)

GitHub Actions is permitted only when the repository remains **public** and the workflow uses GitHub's **free standard GitHub-hosted runners**. This permission is **not** approval for paid Actions, premium compute, storage, or related services.

1. **Runner allowlist:** use documented standard labels such as `ubuntu-24.04` or `windows-2025`. Prefer a single pinned standard runner and the smallest practical number of jobs. Never use larger/premium/GPU runners, paid hosted runners, or paid external CI services.
2. **No uploaded or retained build artifacts:** do not use `actions/upload-artifact`, `actions/cache`, or other artifact/cache storage actions. Do not publish build packages or cache dependencies through CI. Run tests and inspect exit codes/log output directly. The workflow itself must not save artifacts.
3. **Private-repository safety:** if the repository is private (or becomes private), **do not run hosted CI** until an explicit new cost decision. Planned workflows must have a job-level guard such as `if: ${{ github.event.repository.private == false }}` so a visibility change fails closed; also disable workflows if visibility changes and recheck billing policy.
4. **No paid add-ons:** no paid actions, premium tools, paid marketplace services, deployments, or third-party compute without separate approval. Review any workflow change that affects runner class, storage, or billing.
5. **Minimal permissions:** default to read-only `contents: read` permissions; restrict triggers to useful pushes and pull requests, set `timeout-minutes`, and use concurrency cancellation to limit duplicate runs.
6. **Logs are different from artifacts:** GitHub automatically keeps workflow logs/checks subject to retention settings. Do not promise zero server-side storage. Consider the minimum suitable retention setting in repository Actions settings; no changes to account billing or settings are implied by this plan.
7. **Local fallback:** `tests/run_checks.ps1` and the locally installed Godot engine remain the authoritative fallback. If a zero-cost path cannot be verified, **skip CI rather than incur costs**.

Official reference: [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions) and [standard runner labels](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job). Recheck current terms before implementing or changing any workflow.

## Milestones

| Version | Milestone | Deliverable | Acceptance gate |
| --- | --- | --- | --- |
| v0.8.1 | **Free development foundation** | One narrowly scoped, public-only CI workflow using a free standard runner; run existing headless Godot suites without artifacts/caches. | All existing suites run on an allowed runner; deliberate failure makes the check fail; no premium runner/storage action; local runner still works. |
| v0.9 | **Impact Lab** | Impact telemetry, severity classification, restrained crash exaggeration, debris/sparks/audio, improved recovery. | Head-on, rear, side and glancing-impact regressions plus human confirmation that driving stays responsive. Keep collision damage initially optional/off. |
| v0.10 | **Multiplayer Lab** | Two independent local input providers; split-screen cameras/HUDs; two-human duel; scoring and safe spawn improvements. | Two people can finish and restart a match without input conflicts or unfair spawn/score errors. |
| v0.11 | **Destruction Lab** | Breakable props, controlled debris, one meaningful arena hazard, performance bounds. | Driving/shots produce readable destruction; physics and frame pacing stay stable. |
| v0.12 | **Vehicle identity** | Heavy pickup versus muscle car; distinct handling/ramming trade-offs; one signature ability per vehicle. | Human playtests establish meaningful, reasonably balanced choices. |
| v0.13 | **Playable vertical slice** | Menu, vehicle/match selection, HUD/audio polish, packaging, repeatable local and AI matches. | A new player can launch, play a full match, view results, and replay without developer assistance. |

**Deferred:** online networking, campaign/progression, large roster, extensive customization, and content-heavy maps until the vertical slice proves fun. No target delivery dates are committed.

## Execution sequence and scope control

- Plan the smallest testable change, then implement it on a short-lived feature branch.
- Split multi-system milestones into reviewable PRs; do not automatically merge.
- Capture current car physics tunables as a baseline before modifying impacts.
- Add automated physics/lifecycle regression checks whenever practical; human driving and listening tests remain required for feel.
- Maintain player-facing behavior in [README](../README.md), system ownership in [ARCHITECTURE](ARCHITECTURE.md), decisions in [GAME_DESIGN](GAME_DESIGN.md), physics in [PHYSICS](PHYSICS.md), validation in [TESTING](TESTING.md), and version entries in [CHANGELOG](../CHANGELOG.md).
- **Every feature PR includes documentation and changelog updates**, or clearly explains why a particular document does not apply.

## Tracking status

| Workstream | Status | Evidence |
| --- | --- | --- |
| v0.8 combat prototype | Implemented | Merged PRs [#1–#8](https://github.com/FoxyLight/Crash-Lab/pulls?q=is%3Apr+is%3Amerged) |
| Repository documentation foundation | Implemented | [PR #9](https://github.com/FoxyLight/Crash-Lab/pull/9) |
| Free-only CI policy | Documented in proposed roadmap | This file; no workflow enabled yet |
| v0.8.1 and later milestones | Proposed / not implemented | Requires separate feature PRs and validation |

When a milestone is merged, update status and evidence here in the same PR; distinguish planned, in progress, tested, and merged.
