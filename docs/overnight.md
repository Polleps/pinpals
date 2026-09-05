# Overnight run — 2026-09-06

Autonomous work log for the night of 2026-09-05/06. Branch: `overnight`, off `main`
at `9a5060b`. **This file is the state the loop resumes from.** Every iteration
reads it, takes the top unstarted item, and writes back what happened.

Polle's calls before bed:
- **Focus:** all four axes — juice/feedback, playfield content, tuning, harness.
- **Git:** one branch, one commit per change, measurements in the message.
- **Latitude:** make the OPEN calls in `design.md` §13, document each as provisional.

## Rules for every iteration

1. `make check` passes before any commit. No exceptions, no `--no-verify`.
2. One commit per item. The message states what was **measured**, not what was intended.
3. Never end an iteration with a dirty tree or a broken gate. If an item can't be
   finished, revert it and mark it BLOCKED here with the reason.
4. Prefer measuring to asserting. This repo's whole culture is "measured, not guessed"
   (`prototype.md` §3) — a claim about feel with no number behind it is not done.
5. Changes that alter *feel* stay reversible: constants in `core/constants.lua`, or
   data in `data/tables/`. Never bury a tuning knob at a call site.
6. Anything answering a §13 OPEN question gets written up in `design.md` as
   **PROVISIONAL** with the reasoning, so Polle can overrule it cheaply.

## Why this order

The prototype "works but isn't fun". Three plausible causes, cheapest first:

- **It never reacts to you.** No audio, no impact, no escalation. A pinball table is
  90% feedback; this one is silent. Fixing this changes nothing about the simulation,
  so it is pure upside and lands first.
- **There is nothing to do while you hold the ball.** Both upper playfields are empty
  (`prototype.md` §5). Pillar 1 says nobody waits, and right now the flipper player
  waits between passes.
- **Nothing accumulates.** No score, no cross-board state. §9 puts the multiplier on
  passing and §7 makes each board arm the other; neither exists, so a rally is just a
  rally, and the second one feels like the first.

Tuning comes after content, because tuning the post's absoluteness is pointless if
the answer is "give the flipper player something to do while it's up".

---

## Backlog

Status: TODO / DOING / DONE / BLOCKED. Newest notes at the bottom of each item.

### 1. Audio — the game makes no sound at all  ·  TODO
`§10: audio does the warning work.` The module is switched off. Synthesize waveforms
at load (`love.sound.newSoundData`) rather than shipping asset files — keeps the repo
text-only and the footprint at zero. Needs: flipper thwack, bumper pop, gate travel
loop, tube whoosh, arrival warning, drain. Pitch rises with relay heat.
Lives in `app/`. Must degrade silently when audio is unavailable (headless tests).

### 2. Visual juice — impacts, shake, trail  ·  TODO
Bumper pop, flipper contact flash, ball trail scaled to speed, screenshake on drain,
device travel telegraphed rather than snapping. All in `app/render.lua`; the sim must
not learn about any of it. Guard: `make shot` still renders, `check_layers.sh` clean.

### 3. Tube transit gets its beat  ·  TODO
§10 wants the camera to pull out and show the ball crossing between both boards. Right
now it is ~800ms of dead air. This is the game's signature moment and it currently
reads as a pause.

### 4. Relay heat as real scoring  ·  TODO
§9: the multiplier lives on passing, not on shots. Score model in `core/` (pure, unit
tested), readout in `app/`. Heat rises per crossing, resets on drain — a risk curve
generated entirely by cooperation. Answers §13.2 partially; write it up PROVISIONAL.

### 5. Board A upper playfield has nothing in it  ·  TODO
Give the flipper player something to shoot while holding the ball, so not passing is a
real choice (§5: "passing must be tempting, not compulsory"). Data-only where possible;
`make geometry` is the guard against bad coordinates.

### 6. Glasshouse is thin — answer §13.1  ·  TODO
"Two bare rails is not yet a character, just an absence of one." Board identity is the
reason to pass, so this blocks everything about the pass being a decision. Make the
call, document as PROVISIONAL in `design.md`.

### 7. Cross-board state — the design's core hook, entirely absent  ·  TODO
§7: completing something on A arms something on B; you play A to prepare B, pass, cash
in, which arms A again. This is the thing that makes two boards a *game* rather than
two boards. Depends on 5 and 6.

### 8. The post is too absolute  ·  TODO
Blocks 20/32 → 0/32 of pass shots. Legible, but it parks the flipper player, which
brushes pillar 1. Try narrowing it / letting flat shots under. Target: a number
meaningfully above 0 that still makes the guard a real trade. Measure both.

### 9. Pass difficulty off a moving ball  ·  TODO
~60% is measured off a static, perfectly timed flip, which is not the game. Measure
from realistic incoming trajectories, then tune.

### 10. Playtest capture so tomorrow produces data  ·  TODO
§5.1 gets recording free from the intent stream. A session that writes intents + stats
turns Polle's morning play into a measurement instead of an impression.

---

## Log

*(iterations append here)*
