# Overnight run — 2026-09-06

> ## Read this first
>
> **15 substantive commits on `overnight`, off `main` at `9a5060b`. `main` is untouched.**
> Gates: 80 core, 36 sim, all green, `make check` in 3.6s. One commit per change, so
> anything here can be reverted on its own.
>
> ### The thing that mattered most
>
> **Board A could reach exactly one place.** A sweep of 50 flipper contact points found
> that no shot from any point on either flipper could reach anywhere except the ramp —
> nothing above y=550 outside that channel existed as a target. All three bumpers, the
> board's declared character, measured **zero hits**. The upper playfield was not empty,
> it was *unreachable*, and the cause was a ramp mouth sitting 88px above the flipper
> pivots, intercepting every shot before it could travel sideways.
>
> Close behind: the two boards' identities were **backwards** (the one documented as
> forgiving drained more often), and the post was **not a trade but a pause button** —
> raised, it blocked 100% of shots *and* 100% of drains, so nothing could happen at all.
>
> None of those are things a person notices in a few minutes of play. All of them are
> things a person feels.
>
> ### What to do first
>
> ```
> make check    # 3.6s, everything
> make run      # play it
> ```
>
> Play, then quit with `Esc` — it writes a session log and prints the path. Paste the
> summary back and the evening becomes data rather than an impression.
>
> Three things to attend to, because they are where the measurements point and stop:
>
> 1. **Receiving on Foundry** has ~20ms of usable timing, about one 60fps frame. Skill,
>    or coin flip?
> 2. **The post** now costs the pass on one flipper and barely touches the other,
>    differently per board. Tactical, or just inconsistent?
> 3. **The cross-board loop** — charge Foundry, pass, clear the vault, come home to lit
>    bumpers. Does that arc survive two people shouting at each other?
>
> ### What needs you, not me
>
> - **Session structure (§13.2).** Untouched, and now the biggest open question in the
>   project. There is a score and *nothing that ends* — no team lives, no run, no goal.
>   Every system built tonight assumes an endless session, so this call reshapes what
>   sits on top of it. I left it alone deliberately.
> - **Two of the six §13 open questions got provisional answers** — board identity
>   (§13.1) and rescue mechanics (§13.5). Both are written up in `design.md` as
>   PROVISIONAL with the reasoning and the numbers behind them, so overruling either is
>   cheap. The other four are untouched: session structure, tube count, the operator
>   resource model, and whether nudge exists.
> - **Nothing here has been played.** Every number below comes from a headless probe.
>   They say the systems function. They cannot say the game is fun.

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

### 8. The post is too absolute  ·  DONE (b07a9fe)

Blocks 20/32 → 0/32 of pass shots. Legible, but it parks the flipper player, which
brushes pillar 1. Try narrowing it / letting flat shots under. Target: a number
meaningfully above 0 that still makes the guard a real trade. Measure both.

### 9. Pass difficulty off a moving ball  ·  DONE (e940adb)

~60% is measured off a static, perfectly timed flip, which is not the game. Measure
from realistic incoming trajectories, then tune.

### 10. Playtest capture so tomorrow produces data  ·  DONE (395d370)

§5.1 gets recording free from the intent stream. A session that writes intents + stats
turns Polle's morning play into a measurement instead of an impression.

### 13. prototype.md now describes a game that no longer exists  ·  DONE (9c7edd7)

§1 still says "No scoring, no modes, no cross-board unlocks" and §4 lists provisional
calls that have since been made and measured. The doc has been patched section by
section as the night went on; it needs one honest pass to describe what is actually
there, so Polle reads the game rather than its history.

### 14. What sets Foundry's 20ms timing window?  ·  OPEN (five suspects eliminated)

Receiving on Foundry has a usable band of roughly 5–25ms before contact, against
Glasshouse's 15–70ms. Both have a hard cliff at lead 0 — flip late and nothing happens,
which is just pinball. The unexplained part is the **width**, not the position.

**Ruled out by measurement:**

| suspect | result |
|---|---|
| The bumper cluster randomising the descent | Removing it: peak 63% → 72%, window unchanged at 20ms |
| The drain gap (27.6px vs 43.6px) | Widening Foundry to match: window unchanged, peak drops to 53% |
| A truncated sweep hiding the peak | Negative leads score 0% on both boards |
| Arrival speed | At matched speeds the two boards behave almost identically |
| Balls reaching the tube without a flip | 0% on both boards with nobody flipping |

**Found instead, and worth knowing on its own:** the window narrows sharply with
arrival speed on *both* boards — 40ms at 150px/s down to 10ms at 850px/s
(`tests/probe_speed_window.lua`). Since §9 raises arrival speed by up to 55% with relay
heat, **a hot rally is harder to hold for this reason as well as the intended one.**
That is either a happy accident or a difficulty spike nobody chose; a human at the
keyboard should say which.

**Where to look next.** Dropping the ball straight onto the flipper reproduces
Foundry's real 20ms but *not* Glasshouse's real 50ms. So the difference is in the
approach path — where along the flipper the ball lands, and with what horizontal
velocity — not in the flipper or the ramp. That is the next thing to instrument.

### 11+ Think of other ways to improve the game  ·  IN PROGRESS

Polle's addition. If the backlog runs out before the night does, keep going: think of
cool things to add or improve, document them, add them here.

- **Purgatory rescue (§8)** · DONE (98bb9c7). Picked because it was the largest gap
  between what `design.md` marks DECIDED and what existed.
- **Objective readout + dormant-panel flash (§7)** · DONE (0b6e034). The cross-board
  loop worked and was invisible; now it says what it wants.
- **Integration soak** · DONE (9d6b4cd). Found that the rescue was firing for free.
- **Frame cost measured** · DONE (e68d9bd). Nothing added tonight was costed until now.
- **Session structure (§13.2)** · NOT ATTEMPTED, deliberately. There is a score and
  nothing that ends. It is the biggest open question left, and it is also the one where
  a wrong guess costs the most: team lives, run length and whether there is an ending
  at all determine the shape of everything above them. Polle should make this call.

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

### Iteration 8 — the post was a pause button · `b07a9fe`

`prototype.md` flagged the post as maybe too absolute (20/32 passes down, 0/32 up).
Re-measuring found it worse: **absolute in both directions.**

| board | post | pass rate | drains stopped |
|---|---|---|---|
| Foundry | down | 58% | 32% |
| Foundry | **UP** | **0%** | **100%** |
| Glasshouse | down | 69% | 17% |
| Glasshouse | **UP** | **0%** | **100%** |

With it raised *nothing could happen at all* — you couldn't pass and you couldn't lose
the ball. Not §6.2's trade but a pause button, breaking pillar 1 with a device that
looks like it's helping: nothing to do **and** nothing to fear.

The cause was 12 pixels. The post sat at y=676, *above* the pivots at y=688, directly
in every shot's launch path. At y=713 it sits below them: Foundry 58%→40%, Glasshouse
69%→31%, still stopping 100% of drains. (y=726 is the opposite failure — a guard that
costs nothing gets held up forever.) The slope is ~16 points of pass rate **per pixel**,
so any edit to that number is a redesign of the device.

**The best part wasn't designed.** The cost is sharply asymmetric, because each board's
ramp is off-centre and the post blocks whichever flipper shoots *across* the middle:

| | left flipper | right flipper |
|---|---|---|
| Foundry, post up | 58% → **25%** | 58% → 54% |
| Glasshouse, post up | 75% → 54% | 63% → **8%** |

So a raised post doesn't stop the pass, it **moves** it — work the ball to the near
flipper. The flipper player has something to do while their partner guards, and the two
boards block opposite sides so the skill doesn't transfer.

**Two harness bugs found on the way**, both of which would have shipped a wrong
conclusion. My first test swept Foundry's *right* flipper — the one the post barely
affects — and concluded it cost nothing. The second used the shared `on_flipper`
helper, which starts the ball 15.9px clear rather than 10.6px; that's enough for it to
bounce before the flip lands, washing the effect out entirely (13/28 vs 14/28, against
58% and 40% from a ball actually resting on the flipper). Those two harnesses disagree,
which is now written down where the next agent will see it.

### Iteration 9 — the pass is not too easy · `e940adb`

`prototype.md` worried the pass was too easy at ~60%, noting that number came from a
static perfectly-timed flip. Measured from a ball that actually arrives out of the tube
and has to be caught:

| board | peak pass | window at ≥ half peak |
|---|---|---|
| Foundry | 63% | **20ms** |
| Glasshouse | 85% | 50ms |

A 60fps frame is 17ms, so receiving on Foundry gives the player about **one frame** of
usable information. That's a concern in the opposite direction from the one the doc
raised. The peak rate was never the interesting number — a 90% shot you can only hit
within one frame is not an easy shot.

**Three harness rewrites, each of which gave a confident wrong answer first:**

1. **Trials that weren't trials.** 28 "samples" with nothing varying but a 7-value
   speed cycle, so every rate came out a multiple of 1/7 — 0%, 14%, 57%, 100%.
2. **A timing axis that couldn't go early.** Triggering on a y-line means no amount of
   negative "error" fires sooner than the line, so −80ms and 0ms were identical and I
   nearly read that as a flat response.
3. **A metronome instead of a player.** Flipping at a fixed delay while arrival speeds
   varied randomly mistimes nearly every ball by construction, and reported 96% of
   received balls draining. That said nothing about the game. The policy now predicts
   contact from live position and velocity, which is what a person does.

Foundry's narrow window is **not** the bumper cluster — the obvious suspect, ruled out
by measurement. Filed as item 14.

Also: the cross-board link validator from iteration 7 caught my bumpers-removed
experiment before it ran, refusing a board set where Glasshouse lights a cluster
Foundry no longer has. Nice to have that confirmed by accident.

### Iteration 10 — a session now produces numbers · `395d370`

Quitting writes a log and prints the path. Play, quit, paste the summary — that turns
an impression into something checkable:

```
score 75500    best single rally was worth 28000
passes 3 (1.0/min)   drains 13 (4.3/min)   longest rally 1 crossings

rally length, 13 completed rallies:
  mean 0.2   median 0   p90 1   max 1
  10 of 13 rallies (77%) ended without a single pass

operator duty cycle (share of that board's active time):
  board a: gate  48%   post  56%
```

*(that sample is random input, not play — it shows the shape of the output)*

Two lines are chosen to catch specific failures rather than to be interesting.
**"Rallies that ended without a single pass"** is the number that would say the
prototype has failed outright — if most balls die before a crossing there is no rally
to have a feel about. **Operator duty cycle** is pillar 1 as an instrument: an operator
near 0% is what "waiting" looks like as a number.

Every drain records the rally it ended and whether the post was up, so "we lost it on
the fourth pass with the post down" becomes checkable. The tick-stamped intent stream
follows, which is what makes a session replayable later (§5.1).

Verified by generating a real log from simulated play and reading it, rather than
waiting for a human to produce one — a capture nobody has looked at is a capture nobody
knows is broken.

### Iteration 11 — docs, and two suspects eliminated · `9c7edd7`

**`prototype.md` now describes the game that exists.** It still opened with "Exactly
§14's list, and nothing else. No scoring, no modes, no cross-board unlocks" — all
three of which the night added. §4 still called the board identities "a guess with a
shape" after they'd been measured and found backwards. §5 still listed no audio, empty
playfields, a thin Glasshouse and an absolute post as open, all four closed.

A doc describing a previous version of the game is worse than no doc: it's confidently
wrong exactly where someone would trust it.

What's genuinely still open is now stated louder — session structure (§13.2) untouched
and now the largest question in the file, Foundry's receiving window, and the fact that
**none of the overnight work has been played.** §6 gained three specific things to
attend to at the keyboard, chosen because they're where the measurements point and
where they stop being able to help.

On item 14, two suspects eliminated cleanly (bumpers, drain gap) plus a methodological
check: negative leads score 0% on both boards, so Foundry's peak isn't sitting off the
edge of a truncated sweep. The band is 5–25ms vs 15–70ms; the width is what's
unexplained, not the position.

### Iteration 12 — purgatory rescue · `98bb9c7`

Picked from item 11 because it was the largest gap between what `design.md` marks
**DECIDED** and what actually existed. §8 calls it "the best feeling co-op can produce"
and it wasn't there at all: a drain ended the ball, the rally, and everything the rally
was worth, instantly, with nothing anyone could do.

Now a drained ball hangs for 1.9s and the **partner** can pull it back by raising the
post on the board that lost it. Nothing is lost until the window expires — relay, rally
score and the drain counter all stay untouched while it hangs, so a rescue costs the
team nothing they'd already earned.

§13.5 asked where the rescue should live. Answered provisionally: **the post the
operator already has.** No new device, no new binding — and it can't have been held
already, because a raised post stops 100% of drains, so if the ball drained the post
was down. Reaching for it is always a real action inside the window.

**And it costs.** §6.2 says an action that's always correct makes the operator a
button-presser, and a free rescue is exactly that. A rescue spends every vault charge on
both boards — the cross-board preparation from iteration 7. *Keep the rally, or keep the
preparation?*, decided in under two seconds while being shouted at. The HUD states the
cost before you commit.

Audio moved with it: the drain sound no longer plays when the ball crosses the line,
because telling the players it's over while they still have 1.9s to prove otherwise is a
lie. A peril sound plays instead; the loss lands when the window closes.

**Deliberately not attempted: session structure (§13.2).** There's a score and nothing
that ends. It's the biggest open question left and the one where a wrong guess costs
most — team lives, run length and whether there's an ending at all determine the shape
of everything above them. That's Polle's call, not mine.

### Iteration 13 — item 14: five suspects down, and a finding I wasn't looking for

No answer yet on Foundry's narrow window, but the map is much sharper. Eliminated:
bumpers, drain gap, a truncated sweep, arrival speed, and free passes with no flip.

**The useful accident:** the timing window narrows sharply with arrival speed on *both*
boards — 40ms at 150px/s down to 10ms at 850px/s. §9 raises arrival speed by up to 55%
with relay heat, so **a hot rally is harder to hold for this reason too**, not only the
intended one. Whether that compounding feels like escalation or like the game turning on
you is a keyboard question.

Also learned where *not* to look: dropping the ball straight onto the flipper reproduces
Foundry's real 20ms but not Glasshouse's real 50ms, so the difference lives in the
approach path — where along the flipper the ball lands and with what horizontal velocity
— not in the flipper or the ramp.

Stopping the investigation here rather than burning more of the night on it. Five clean
eliminations and a signposted next step is worth more than a sixth guess.

### Iteration 14 — the loop says what it wants · `0b6e034`

The cross-board loop worked and was **invisible**. A player saw a score, a multiplier,
and two numbers moving off to the side, with nothing saying *charge the vault, pass,
cash it, come home to lit bumpers*. Pinball has always solved this with a line of text
telling you what's lit, and §7 asks for it specifically.

| state | readout |
|---|---|
| fresh ball on Foundry | CHARGE THE VAULT ON GLASSHOUSE |
| Foundry, vault part-charged | PASS TO CLEAR THE VAULT ×5 |
| Foundry, vault full | PASS — VAULT IS FULL *(urgent)* |
| on Glasshouse, vault charged | CLEAR THE VAULT ×7 |
| bumpers lit | BUMPERS LIT ×5 (9 left) *(urgent)* |

Derived from the board data's `links` rather than hardcoded, so a new cross-board
relationship gets a readout for free and can't silently become a mechanic nobody is
told about. Coloured by where it wants doing — amber for "act here", blue for "this
wants a pass" — so both players can see whose problem it is without reading it.

Lit bumpers outrank a full vault deliberately: a charged vault waits, a lit board is a
timer running out, and the readout should point at the thing that expires.

Plus the §7 panel flash — a board outlines itself when its cross-board state changes,
so a charge landing on the *dormant* board is visible there rather than being something
you have to remember.

### Iteration 15 — the soak found a free rescue · `9d6b4cd`

Every system added tonight is tested alone, and none had been run against the others
for a sustained stretch. A 10-minute random-play soak with invariants checked every
tick found a real bug in the first run:

```
29 rescues, 1 drain
```

The ball essentially never died. My rescue condition was "post commanded at any point
in the window" — a **state**, not an action. An operator idling with the post up
rescued every ball for free, and after a rescue the post was usually still up to
rescue the next one.

I had argued this couldn't happen: a raised post stops 100% of drains, so if the ball
drained the post was down. **That's only true of a post fully raised.** One commanded
but still travelling doesn't stop the ball and does satisfy the check.

The rescue now arms on the post being *down* when purgatory opens and requires a fresh
raise; releasing an already-up post re-arms it, so the save stays available to anyone
who does something to earn it.

| | rescues | drains | score |
|---|---|---|---|
| before | 29 | 1 | 814,600 |
| after | 22 | 5 | 323,650 |

Random play toggles far more often than a person would, so 22/5 isn't a balance target
— only evidence the save is no longer free.

A 60-second version of the soak is now part of `make check` (2.0s → 3.6s): one ball
while playing, meters and lit counters in range, rally score never exceeding the
session, the objective never empty, the feed never past its cap. It's the only test
that runs everything at once.

### Iteration 16 — handoff, and costing the frame · `1ad472e`, `e68d9bd`

Two things, both about not leaving loose ends.

**A read-this-first at the top of this file.** Fifteen iteration entries is the right
amount of detail and the wrong thing to open at breakfast. The summary leads with the
finding that mattered most (board A could reach exactly one place), says what to try
first, and says plainly what still needs a human. While writing it I claimed six §13
questions had been answered; checking `design.md`, it's two. Corrected before it shipped.

**Frame cost, which nothing tonight had.** Impact events, particles, a trail, a
synthesized audio kit, a recorder and an objective readout evaluated every draw all
landed on the per-frame path unmeasured. If the game had started dropping frames, every
one of them would have made it worse and the cause would have been a guess.

| per call | µs | share of budget |
|---|---|---|
| sim step (4166µs budget at 240 Hz) | 6.3 | 0.15% |
| `fx.update` | 0.5 | 0.00% |
| `record.update` | 0.2 | 0.00% |
| `objective.current` | 0.5 | 0.00% |

A 60fps frame is **26µs, 0.2% of 16.7ms**; the `MAX_CATCHUP` worst case is 2.3%.
`technical-choices.md` §3 has asserted "performance is not the discriminator" since day
one and now cites numbers instead. A loose gate (a sim step under 25% of its budget,
forty times the measured cost) guards against someone adding an O(n²) loop.

*(iterations append here)*
