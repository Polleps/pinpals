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

### 1. Audio — the game makes no sound at all  ·  DONE (61a6733)

`§10: audio does the warning work.` The module is switched off. Synthesize waveforms
at load (`love.sound.newSoundData`) rather than shipping asset files — keeps the repo
text-only and the footprint at zero. Needs: flipper thwack, bumper pop, gate travel
loop, tube whoosh, arrival warning, drain. Pitch rises with relay heat.
Lives in `app/`. Must degrade silently when audio is unavailable (headless tests).

### 2. Visual juice — impacts, shake, trail  ·  DONE (354dde4)

Bumper pop, flipper contact flash, ball trail scaled to speed, screenshake on drain,
device travel telegraphed rather than snapping. All in `app/render.lua`; the sim must
not learn about any of it. Guard: `make shot` still renders, `check_layers.sh` clean.

### 3. Tube transit gets its beat  ·  DONE (6934eec)

§10 wants the camera to pull out and show the ball crossing between both boards. Right
now it is ~800ms of dead air. This is the game's signature moment and it currently
reads as a pause.

### 4. Relay heat as real scoring  ·  DONE (c5808a1)

§9: the multiplier lives on passing, not on shots. Score model in `core/` (pure, unit
tested), readout in `app/`. Heat rises per crossing, resets on drain — a risk curve
generated entirely by cooperation. Answers §13.2 partially; write it up PROVISIONAL.

### 5. Board A upper playfield has nothing in it  ·  DONE (d85964a)

Give the flipper player something to shoot while holding the ball, so not passing is a
real choice (§5: "passing must be tempting, not compulsory"). Data-only where possible;
`make geometry` is the guard against bad coordinates.

### 6. Glasshouse is thin — answer §13.1  ·  DONE (5a4c5c3)

"Two bare rails is not yet a character, just an absence of one." Board identity is the
reason to pass, so this blocks everything about the pass being a decision. Make the
call, document as PROVISIONAL in `design.md`.

### 7. Cross-board state — the design's core hook, entirely absent  ·  DONE (e322a02)

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

### 11+ Think of other ways to improve the game  ·  TODO

Polle's addition. If the backlog runs out before the night does, keep going: think of
cool things to add or improve, document them, add them here.

### 12. Board A's bumper cluster is nearly unreachable  ·  DONE (d85964a — same bug as 5)

Found while measuring impulses for item 1: **1 bumper contact in 240 seconds** of
random play, against 23,088 wall contacts. `prototype.md` §4.1 calls the cluster
Foundry's defining feature — "chaotic and forgiving, keeps the ball alive" — and in
practice the ball almost never gets there. Either the cluster is in the wrong place
or nothing feeds it. Measure reachability from real flipper shots before moving
anything; this may be most of why board A has no character in play.

---

## Log

### Iteration 1 — audio · `61a6733`

Built the impact-event plumbing first, because items 1 and 2 both need it: sim/
reports ball contacts, app/ decides what they look and sound like.

The one real decision was the threshold below which a contact is not a hit. Rather
than pick one by ear I measured 240s of random play, and the distribution answered
it outright — 90% of wall contacts sat at 0.249–0.250 against a predicted resting
impulse of `m·g·dt·METER` = 0.2519. That cluster *is* the ball sitting still, so the
floor is defined as a margin above it rather than as a magic number, and it now
follows gravity and tick rate automatically if either changes.

| floor | impacts/s | reading |
|---|---|---|
| 0.20 | 96.9 | a 240 Hz buzz |
| **0.30** | **7.2** | hits |

Eleven synthesized voices, no asset files. Relay heat pitches the kit up so the
table tightens audibly as a rally gets hotter — the first thing in the build that
makes rally #6 feel different from rally #1.

Incidental finding worth keeping: **bumpers were hit once in 240 seconds.** Board A's
cluster is supposed to be its whole character and the ball essentially never reaches
it. That is a live suspect for "not fun yet" and is now item 12.

### Iteration 2 — visual juice · `354dde4`

Impact rings, bumper flashes, sparks, a speed-scaled ball trail and screen shake,
all fed by iteration 1's event stream so sound and light come from one hit rather
than two systems guessing separately.

Two judgement calls worth flagging for the morning, both easy to overrule:

- **Shake is deliberately rare.** Only a drain and a genuinely hard hit produce any.
  A cabinet does not wobble when the ball touches a wall, and constant shake reads as
  a bug rather than as impact. If it feels too subtle at the keyboard, `add_shake`
  call sites are the one knob.
- **Sparks need `s > 0.30`.** At ~7 impacts/s, drawing every contact is television
  static. Rings still draw for all of them.

Relay heat is now visible as well as audible — the ball's halo runs white to hot
through rally 10.

`--shot` now drives fx the way `love.update` does. Without that every §7 screenshot
showed a game with no trail, no sparks and no lit bumpers, which would have made the
visual gate quietly useless for exactly the thing it was added to check.

The seven new tests were each verified against the bug they claim to catch: removing
the ring cap, the trail retraction, the shake decay or the shake clamp fails exactly
one test apiece and no others.

### Iteration 3 — the transit beat · `6934eec`

The dead air was not the camera. `render.lua` faded the HUD to zero for the whole
800ms, and the comment said why: the pulled-back boards supposedly reached into its
column. They do not — measured:

| | board A ends | board B starts | room for HUD |
|---|---|---|---|
| normal play | 381.1 | 618.9 | 213.8px |
| transit | 292.8 | 707.2 | **390.4px** |

Pulling the boards back makes *more* room. The fade bought nothing and cost the
entire beat: `prototype.md` §4.5 hands the sender the destination board's devices
for exactly those 800ms, so the operator's panel was hidden during the one window in
which its owner is the operator. A pillar-1 violation ("nobody waits") wearing a
camera move as a disguise.

The HUD already keyed off `state.active`, so it had been showing the correct board
all along — it just could not be seen. Now relabelled for the moment: **PREPARING**
rather than ON, **RECEIVING** rather than FLIPPER.

Added on top: incoming rings collapsing onto the entry point, a brightening wake
along the travelled arc, and a transit progress bar.

Worth noting for the morning: **two of the four bugs in this iteration were only
findable by looking at the render** — a fixed pixel offset printed the countdown
through the word "GLASSHOUSE", and the progress bar landed on the controls hint. The
gates were green through both. `--shot` is doing real work now that it draws fx.

### Iteration 4 — relay heat scoring · `c5808a1`

The multiplier is now the crossing count: ×7 means "we have passed seven times
without dropping it", which either player can say out loud mid-rally. The curve:

| crossings | mult | rally total | same passes scattered | ratio |
|---|---|---|---|---|
| 1 | ×1 | 1,000 | 1,000 | 1.0× |
| 5 | ×5 | 15,000 | 5,000 | 3.0× |
| 10 | ×10 | 55,000 | 10,000 | 5.5× |

A drain takes the rally and everything it was worth. That makes **best rally score**
the number that answers §14 quantitatively — a monotonically rising session total is
a record, not a measurement.

I wrote heat as `1 + relay` first, which had the first pass of every life already
paying ×2 and left the multiplier with no meaning of its own. The
scattered-versus-together test caught it on the day it was written.

**Two things measured away rather than shipped**, both worth knowing about:

- **A bumper cooldown.** I assumed a ball leaving a high-restitution bumper would
  register several begin-contacts and score for each. It does not — a 0.02s cooldown
  suppresses *exactly* as many repeats as no cooldown (21 of 120 approaches either
  way), so there is no solver jitter to filter, and the repeats that exist are
  50–400ms apart: the ball genuinely coming back, which pinball rewards. Deleted the
  constant and the per-bumper state. `tests/probe_scoring.lua` is kept so the next
  agent tempted to add one re-runs it first.
- **`TRANSIT_MAX_SP` at 40 m/s.** The top 384 px/s was dead range — sim clamps to
  `BALL_MAX_SPEED` on the next step, so an arrival could never reach it. The constant
  had been quietly lying about its range. Now pinned to the ball's own ceiling.

Heat also raises arrival speed (+5%/crossing to +55%), which is §9's "moving faster".
Deliberately *not* done by shortening transit: §5 and §11 make that 800ms the online
latency budget, and spending it on escalation would foreclose network play to buy
something the speed multiplier already gives.

**Still unanswered and now more visible:** bumpers are the only shot content in the
game, and item 12 says the ball reaches them once per 240s. The multiplier currently
has almost nothing to multiply. Items 5 and 6 are where that gets fixed.

### Iteration 5 — board A had exactly one shot · `d85964a`

Items 5 and 12 turned out to be the same bug, and it is worse than either
description. A sweep of 50 flipper contact points across both flippers:

    pass 62%   drain 38%   left orbit 0%   right orbit 0%

**Nothing above y=550 outside the ramp channel was reachable by any shot from any
contact point on either flipper.** The upper playfield was not empty — it was
unreachable, and adding targets to it would have added nothing. All three bumpers
measured reach 0. Foundry's entire declared character did not exist at the table.

The cause was geometric: the ramp mouth sat 88px above the flipper pivots and
intercepted every shot before one could travel sideways. The outer shell already
forms a complete orbit — the serve runs it every time — but no flipper shot could
enter it.

| mouth y | pass | left orbit | right orbit |
|---|---|---|---|
| 600 (shipped) | 62% | 0% | 0% |
| 570 | 58% | 6% | 4% |
| **540** | **52%** | **14%** | **10%** |
| 510 | 42% | 42% | 16% |

Moving the ramp alone did not fix the bumpers — the orbit hugs the wall at x=24–72
and the cluster sat at x=95–140, just inside the lane and outside the ball's path.
Repositioned against the measured lane: **0.60 hits/s against 0.017, a 36×**, with
all three now scoring where two previously never fired at all.

**Methodology note worth keeping.** My first bumper sweep, on one seed, showed 80 →
129 hits from a 4px radius change. That was noise wearing the costume of a result.
Re-run averaged over 6 seeds, the two radii are indistinguishable (72.2 vs 74.7, sd
~7). Pinball is chaotic enough that single-run layout tuning measures nothing —
`tests/probe_reach.lua` now averages by default.

**And a correction to my own work.** The probe first reported 10% of shots stuck.
That was the probe holding the flipper up for the whole 6s trace, which parks it out
of the way and leaves a notch at the pivot no ball can escape. With a realistic
press-and-release it is 0%. The geometry gate was right and my instrument was wrong
— worth remembering before trusting the next number it produces.

### Iteration 6 — §13.1 answered, and it was backwards · `5a4c5c3`

The identities had never been measured. When I measured them:

| board | gap | ball life | drains/s | pts/s | survival |
|---|---|---|---|---|---|
| Foundry ("forgiving") | 33.6 | 10.22s | **0.0815** | 26 | 15% |
| Glasshouse ("punishing") | 43.6 | 9.86s | 0.0777 | 125 | 27% |

**Foundry drained more often per second than Glasshouse despite a 10px narrower gap**,
while also being harder to pass from and worth less — worse on every axis at once. Not
an identity, a bug wearing one.

Now, after narrowing Foundry's drain and giving Glasshouse a target bank:

| board | gap | ball life | drains/s | pts/s |
|---|---|---|---|---|
| Foundry | 27.6 | **12.19s** | **0.0725** | 24 |
| Glasshouse | 43.6 | 9.05s | 0.0810 | **351** |

Answer written into `design.md` §7 as PROVISIONAL: **Foundry is where a rally survives,
Glasshouse is where it pays.** 15× the points per second, a ball that dies a third
faster. That puts §6.2's trade onto the pass itself.

**Three times the measurements overruled me this iteration:**

1. **The bank is two targets, not three.** The rail splits the ball into streams at
   x=244 and x=336 with nothing down the middle; a three-target row puts its middle at
   x=290 (geometry forbids closer) where it took 4 hits against 50 and 52. A bank whose
   middle can't be reached never completes — worse than no bank, because it visibly
   exists and silently can't be finished.
2. **Fixing that by moving the rail broke the board.** The distribution balanced
   beautifully at 18/24/12 — and mean ball life went to 30.00s, the probe's timeout,
   with a drain rate of *exactly zero*. The ball rattled in the bank forever. Only
   having ball life in the same table caught it. A pretty distribution nearly shipped a
   board the ball cannot leave.
3. **Narrowing Foundry's drain woke a sleeping pocket** beside the pivots — always
   there, never reached, until the ball started spending time down there. Preserving
   the old 7px wall-to-pivot offset did *not* fix it (14% stuck); pulling back to 9.9px
   did.

New `target` device kind (scores, lights, forms banks) and two new geometry checks. The
target-to-target wedge check caught this very commit's first draft: three targets 33px
apart at 34px wide, overlapping into one bar on screen. **Only the screenshot revealed
it** — which is twice now that looking at the render found what the gates could not.

### Iteration 7 — the cross-board loop · `e322a02`

§7's hook, built and verified end to end:

```
  Foundry bumpers  ──charge──▶  Glasshouse vault
        ▲                              │
        │                          clear it
     lit ×5                            │
        └──────────arms────────────────┘
```

Grind Foundry (0.6 bumper hits/s fills the ×10 vault in ~17s) → pass → clear the vault
for a bonus scaled by everything Foundry built → Foundry's bumpers light at ×5 for 12
hits → which recharge the vault.

**The cap is the load-bearing part.** Past ×10, Foundry pays only its own 24 pts/s, so
grinding stops out-earning passing. That is §5's "tempting, not compulsory" resolved in
the direction that keeps the tube a decision: the home-grind line exists, pays, and
then runs out.

Verified in real matches rather than assumed — a loop like this can be entirely correct
and still never occur:

| seed | passes | max charge | banks | lit fired | score |
|---|---|---|---|---|---|
| 1 | 1 | 10 | 2 | yes | 33,400 |
| 3 | 4 | 10 | 1 | yes | 37,000 |
| 4 | 3 | 10 | 4 | yes | 55,500 |

The wiring is **board data**, not rules — §5.3 lists cross-board wiring as part of a
table definition, so a new relationship is a `links` entry rather than a branch in
`core/state.lua`. `core/validate.lua` rejects a link naming a board, meter or target
that doesn't exist: a typo there would be a mechanic that silently never fires, which
is the worst failure available to something two players are building toward together.

*(iterations append here)*
