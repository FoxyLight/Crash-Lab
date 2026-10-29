# Game design: Crash Lab

> Working design direction, not a locked game design document. Separate **implemented** mechanics from **proposals**. Crash Lab is an original vehicular-combat project inspired by the *feel* of Vigilante 8 and its sequel, not a remake of their protected characters or assets.

## Vision

A fast, accessible, physics-driven vehicular-combat game featuring **responsive driving**, **distinctive weapons**, **interactive destruction**, and **enjoyable human multiplayer**.

**Primary design rule:** Immediate arcade control, convincing weight and momentum, readable consequences. Vehicles should feel satisfying to steer at combat speeds; drifting is optional rather than mandatory.

## Four core pillars

1. **Driving and handling:** High responsiveness and speed, predictable braking/reversing, distinguishable weight and impacts. Gameplay maneuvering takes priority over driving-simulator fidelity.
2. **Weapons and specials:** Weapons with different tactical roles; later, recognizable vehicle-specific special attacks and useful counters.
3. **Destructible arenas:** Physical props and ultimately arena-changing events that create tactical opportunities, not just particles.
4. **Multiplayer combat:** Readable, fair collisions and weapon feedback. Local split-screen is a design priority; online play is not currently implemented.

## Current playable loop (v0.8)

The default duel pits the player against one moving AI rival. Drive and fire, destroy or be destroyed, earn eliminations, respawn between non-final eliminations, and play until the first participant reaches the configured target (default: three). Restart a finished match. Player weapon switching provides a fast blaster and slower heavy cannon. Green repair pads restore up to 25 HP, become unavailable for a 12-second default cooldown, and can also be taken by the rival. The separate training scene contains a stationary turret and target dummy.

Current scenes, tuning, controls, and limitations are described in [README](../README.md).

## v0.9 collision decisions (implemented, human acceptance pending)

- **Goal:** make speed and collision angle readable without making steering a chore. Severity uses relative normal contact speed; a fast glancing scrape can be minor while two approaching cars produce a major crash. A perpendicular side ram can still be major. We deliberately do not assign arbitrary multipliers by bumper/side location.
- **Feedback:** distinct procedural clatter/crunch/thump, severity-scaled short geometric sparks, and bounded decaying camera offsets for moderate/major collisions involving the followed car. No continuous steering penalty, time slowdown, new control, or collision health damage. Weapon damage and match elimination rules remain unchanged.
- **Stability choice:** ship extra collision impulses **disabled**. In response to direct sluggish-driving feedback, increase shared engine force from 15,000 to 22,000 N and power cutoff from 42 to 55 m/s, keeping mass, brakes, reverse cutoff, grip, damping, suspension and original steering-by-speed curve. Optional planar/yaw exaggeration stays available for comparison; no hands-on evidence yet justifies enabling it by default.
- **Noise control:** ignore support normals, tiny scrapes and repeated same-category pushing. A weak touch can escalate to a genuinely stronger category; distinct obstacles do not suppress each other. Either vehicle's data can feed the shared event owner. Keep severity thresholds unchanged instead of disguising missed-event bugs with lower thresholds. A short local yellow-white center replaces an optional screen flash; existing damage feedback stays readable.
- **Readability:** replace thin lines with 8/12/18 thick directional streaks, bright centers and animated movement. Major duration grows from 0.42 to 0.65 s. Project the visual origin above placeholder roofs while retaining actual contact x/z and true telemetry. Retain eight-burst cap, no expensive glow/particle dependency and complete lifecycle cleanup. Add a smooth, configurable 75–85° speed FOV without changing chase orientation or adding motion shake.
- **Evidence:** actual physics regressions exercise one-sided reporting, minor-to-major escalation, close distinct collisions, sustained contact and 55 m/s chassis/obstacle hits. Three-second runway speed rises from 18.46 to 22.81 m/s; near-terminal straight speed from 26.01 to 34.05 m/s. The AI remains upright with zero resets in its 60-second regression. Normal-camera graphical inspection shows bright centers and visible streaks near 0.42 s, with cap/expiry/results cleanup. These establish behavior/presentation, not satisfying crash feel or fair final balance.
- **Revisit after playtest:** adjust speed thresholds, cue balance and shake strength first. Consider low enabled exaggeration only if it adds weight without spinning, lift, loss of control or multiplayer unfairness. Keep collision damage absent until a separately approved design.

## Design hypotheses to test

| Hypothesis | Question to answer through playtests |
| --- | --- |
| Impact Lab (implemented; acceptance pending) | Do the current feedback and optional modest exaggeration produce memorable rams without ruining steering? |
| Destruction Lab | Do breakable objects and an arena hazard meaningfully change player decisions? |
| Signature weapons | Can a unique special be powerful yet avoidable and legible during high-speed combat? |
| Local multiplayer | Do combat camera, controller bindings, respawns, and collision reactions remain fair with two humans? |
| Vehicle diversity | Can a heavy pickup and lighter car feel different without one becoming a clear best choice? |

These are candidate experiments, **not confirmed roadmap commitments**. A new feature should not silently retune approved vehicle handling or existing weapon balance.

## Playtest criteria

- The player can drive precisely at high speed while aiming or dodging.
- A good attack angle or driving maneuver matters as much as weapon damage.
- Opponents can understand why they were hit and quickly recover control.
- Arena interactions produce decisions rather than obscure visual noise.
- Features enhance head-to-head fun, not just the number of systems in the prototype.

## Decision log convention

Record significant design choices here or in a future dedicated decision record with: **context**, **alternatives**, **decision**, **reason**, **test evidence**, and **revisit condition**. Do not present untested assumptions as player-approved design.

See [ARCHITECTURE](ARCHITECTURE.md) for implementation ownership and [PHYSICS](PHYSICS.md) for current handling constraints.
