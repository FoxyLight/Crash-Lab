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

## Merged playable baseline (v0.9)

The default duel pits the player against one moving AI rival. Drive and fire, destroy or be destroyed, earn eliminations, respawn between non-final eliminations, and play until the first participant reaches the configured target (default: three). Restart a finished match. Player weapon switching provides a fast blaster and slower heavy cannon. Green repair pads restore up to 25 HP, become unavailable for a 12-second default cooldown, and can also be taken by the rival. The separate training scene contains a stationary turret and target dummy.

Current scenes, tuning, controls, and limitations are described in [README](../README.md).

v0.9 Impact Lab is merged at `cb76c23`, including refined acceleration, reliable collision telemetry, visible sparks and speed FOV. Those approved settings form the baseline for local multiplayer.

## v0.10 local multiplayer decisions (implemented; human acceptance pending)

- **One physical match:** two equal human player cars share the existing duel arena, physics, weapons and repair pads. Horizontal split is a presentation layer over one world. AI duel and training remain separate launchable scenes; no online mode or menu expansion.
- **Controls:** default keyboard/mouse P1 plus first pad P2; F2 selects two pads. Explicit device IDs and independent raw-event state avoid global action cross-talk. A disconnected car coasts with zero commands, and the match continues. Neutral is required before a newly assigned pad joins; remaining players retain their pad slot. No automatic pause/lobby/remapping in this milestone.
- **Fairness:** both humans use 100 HP, identical blaster/cannon tuning, three-second respawn and 1.5-second protection. Only a lethal hit attributed to the opponent earns a local-match point. Self/unknown kills respawn without points; no stale attacker/assist credit. First to three, with same-tick winning trades resolved as draws.
- **Spawn camping:** after the normal countdown and 1.5 seconds of blockage, try separated deterministic alternatives with ground/clearance validation. Retry safely if all are blocked; never force a reset into another body. One opponent cannot occupy all four authored alternatives simultaneously.
- **Readability:** separate compact health/loadout/score/respawn/device HUDs and P1/P2 labels. One global winner/draw overlay, one shared mute/result cue and a midpoint speaker mix. Each involved camera reacts to a crash; one shared burst uses crossed streak geometry. Physics, weapons and collision tuning are unchanged.
- **Camera playtest response (October 30):** user reported the camera too far back/stretched, with the rest looking/feeling good. Local framing moves to 6.5 m back / 2.4 m up / 0.55 m focus and a 110–115° horizontal lens; remove the excessive ~141–147° sideways expansion of the original split view. Keep the whole car framed and hide only its redundant own-world nameplate. Shared follow smoothing/obstruction/shake and AI/training defaults remain intact. Another human camera check is pending; this feedback is not merge approval.
- **Evidence and gate:** 70 multiplayer checks plus all 256 existing checks pass locally; real Windows renders cover layout, collision in both views, protected respawn, resize and result. A short scripted rendering probe shows ~5.5 ms average frame time on the inspected GTX 1060, with no measurable single-/two-view difference beyond noise at the same total render area. Physical controllers were not connected, so two-person driving, input/hotplug comfort, aiming readability and final fairness still require human acceptance. Details in [TESTING](TESTING.md#v010-local-multiplayer-validation).

## v0.9 collision decisions (merged)

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
| Impact Lab (merged baseline) | Does the approved feedback remain readable and comfortable with two human cameras? |
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
