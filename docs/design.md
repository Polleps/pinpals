# Pinpals — Game Design Document

**Status:** draft v0.1 · **Scope of this doc:** the game, not the code (see `technical-choices.md`)

Items marked **DECIDED** are settled. Items marked **OPEN** need a call before they block work.

---

## 1. Pitch

Two players. Two *different* pinball tables, physically linked by tubes. **One ball.**

Whoever has the ball plays the flippers. Whoever doesn't reaches into their partner's
table and starts messing with it — sliding gates open, raising walls, charging magnets —
trying to help. The moment the ball crosses a tube, the roles swap.

It is a game about handing something fragile to a friend, and about the friend
rearranging the floor beneath it while shouting about what they're doing.

## 2. Design pillars

1. **Nobody waits.** There is no state in which a player has nothing to do. Ball position
   assigns roles; both roles are active at all times.
2. **The pass is the game.** Passing isn't transport, it's the central skill. A pass
   carries difficulty: where the ball arrives, how fast, and how prepared the receiving
   board is are all the sender's responsibility.
3. **Talking is a mechanic.** The operator can't act well without telling the flipper what
   they're about to do. We design for two people shouting at each other in one room.
4. **Generosity under pressure.** Almost every choice is "do I take the safe thing for me,
   or set up the good thing for you." That tension is the whole game.

## 3. Scope — v1 **DECIDED**

| | v1 | Later |
|---|---|---|
| Players | 2 | 3–4 (ring topology) |
| Balls | 1 | Multiball as an escalation |
| Boards | 2, different, interconnected | More boards |
| Multiplayer | Local, one screen, two inputs | Online (see §11) |

Starting at one ball is deliberate: it keeps the role-swap clean, and it *preserves
multiball as an escalation* we can spend later. If balls-per-player were the baseline we'd
have burned pinball's best card on the tutorial.

## 4. Core loop

```
        ┌─────────────────── ball crosses a tube ───────────────────┐
        │                                                           │
        ▼                                                           │
  Player A: FLIPPER                                       Player B: FLIPPER
  - owns board A's flippers                               - owns board B's flippers
  - scores, chases modes                                  - scores, chases modes
  - decides when and where to pass                        - decides when and where to pass
        +                                                           +
  Player B: OPERATOR                                      Player A: OPERATOR
  - controls devices ON BOARD A                           - controls devices ON BOARD B
  - opens/closes routes, saves, sets traps                - opens/closes routes, saves, sets traps
        │                                                           │
        └─────────────────── ball crosses a tube ───────────────────┘
```

Both players are always looking at the same board — the one with the ball. Roles are
implicit in ball position; there is no role-select UI and no mode switch.

## 5. The link

**DECIDED:** Boards are connected by tubes. A ball entering a tube on one board emerges at
a defined entry point on the other.

- **Multiple exits, multiple entries.** Each board has several tube mouths; each maps to a
  different arrival point on the partner board. Choosing which tube to shoot is choosing
  how hard your partner's next ten seconds are.
- **The pass carries state.** A clean ramp shot arrives controllable; a desperate flail
  arrives fast. A bad pass is a real thing you can do to your friend.

  **As built (2026-09-06), only the SPEED survives, not the direction or the spin.** The
  tube carries a scalar, and the receiving board launches the ball along its own entry
  vector at that speed. That is deliberate for direction — an arrival that kept its
  original heading could emerge travelling into a wall — but it does mean a pass is
  currently one number, and "arrives high and controllable" versus "fast and low" is
  only the fast/slow half of that sentence. Spin is not transferred at all. If the pass
  should carry more, this is the place it would go in.
- **Transit is visible and takes time.** ~700–900ms, animated along the tube where both
  players can see it. This is the telegraph, the breath between phases, and (later) the
  network latency budget. See `technical-choices.md` §6.
- **Passing must be tempting, not compulsory.** Some scoring lines reward staying home and
  grinding your own board. If progress *requires* a pass every cycle, the tube stops being
  a decision and becomes a corridor.

**OPEN:** How many tubes per board? Are any one-way? Proposal: 3 per board, all one-way,
so the topology is a directed cycle and "can I even get back?" is a real question.

## 6. The operator

The ball-less player acts on the *active* board. This is what makes one ball work.

### 6.1 The cardinal rule **DECIDED**

**Operator actions are persistent states, never instantaneous impulses.**

- ✅ **Good:** a gate that takes ~300ms to slide open; a wall that holds a raised position;
  a ramp that lifts; a magnet that grabs for a forgiving ~400ms window; a spinner you
  charge up; a post that stays extended.
- ❌ **Bad:** anything decided at a precise contact moment — a snapping flipper, a kicker
  fired on impact, a one-frame bumper.

Two reasons. First, it makes operator play *readable* — you can see what your partner did
and is doing, which is what allows the flipper to plan around it. Second, it's the single
constraint that makes online play viable later, at zero cost today. A remote flipper would
be unshippable over a network; a remote **paddle that holds a raised position** has the
same tactical feel at ~200ms granularity and is completely lag-proof.

### 6.2 Every operator action is a trade **DECIDED**

If opening the gate is always correct, the operator is a button-presser. Each device
should give and take:

- The gate that opens the jackpot ramp **closes the safe return lane.**
- The magnet that saves the ball **kills the combo timer.**
- The wall that guards the outlane **blocks a scoring shot.**
- Raising the paddle **opens the lane underneath it.**

This is what forces the talking. The operator has to announce, and the flipper has to trust.

**OPEN:** Do operator actions cost a resource? Proposal for v1: per-device cooldowns, no
shared meter. Simpler to read, and the trade-offs above already provide the restraint.

## 7. Boards **DECIDED**

The two boards are **different, and interconnected by state**. Not mirrors.

- Each player has a home board they'll learn deeply. Passing means handing the ball to the
  person whose board suits what you're trying to do.
- **Cross-board state:** completing something on board A arms something on board B. You
  play A to prepare B, then pass and cash in — which arms A again.
- **The dormant board keeps its state.** Your unlocks sit there waiting. Arriving on a
  board you prepared should feel like coming home to something.
- The dormant board is shown as a small panel that lights up when cross-board state
  changes, so you always know what you've built up over there.

**PROVISIONAL (2026-09-06):** Board identities/themes, and what each is *good at*.

**Foundry is where a rally survives. Glasshouse is where it pays.**

| | Foundry | Glasshouse |
|---|---|---|
| Character | chaotic, forgiving, cheap | clean, precise, expensive |
| Content | a bumper cluster in the orbit lane | a two-target bank |
| Drain gap | 27.6px | 43.6px |
| Mean ball life | 12.19s | 9.05s |
| Drains per second | 0.0725 | 0.0810 |
| Pass rate from a swept flip | 54% | 66% |
| **Points per second** | **24** | **351** |

That puts §6.2's trade — "the safe thing for me or the good thing for you" — one level
up, onto the pass itself: do I keep the rally alive, or send it somewhere it can
actually score? And because §9 makes a hot rally worth more, the temptation to cash in
on Glasshouse grows at exactly the rate the cost of losing it does. The risk curve and
the geometry pull in the same direction, which is the whole reason to have two boards
rather than one board twice.

Glasshouse pays roughly 15x per second of ball time and kills the ball a third faster.
Neither number was chosen; both fell out of giving each board content its own shape can
actually deliver to the ball.

This replaces the earlier claim ("Foundry forgiving, Glasshouse punishing to sit on"),
which had never been measured and was backwards: Glasshouse had the *higher* survival
rate of the two, 27% against Foundry's 15%, and Foundry drained more often per second
of ball time despite a narrower gap. Foundry was worse on every axis at once — not an
identity, a bug. Fixed by narrowing its flipper gap; the numbers above are after.

**Still open underneath this:** the two boards differ in what they are *for*, but not
yet in how they are *played*. Nothing on Foundry rewards a skill that Glasshouse
punishes.

### 7.1 The cross-board loop, as built **PROVISIONAL (2026-09-06)**

The §7 hook, concretely:

```
  Foundry bumpers  ──charge──▶  Glasshouse vault
        ▲                              │
        │                          clear it
     lit x5                            │
        └──────────arms────────────────┘
```

1. **Grind Foundry.** Each bumper hit charges Glasshouse's vault, up to ×10. At the
   measured 0.6 hits/s that fills in ~17 seconds.
2. **Pass.** Past the cap, Foundry pays only its own 24 points/s — the cap is what
   makes the pass the only way to cash, which is §5's "tempting, not compulsory"
   resolved in the direction that keeps the tube a decision.
3. **Clear the vault.** The bank bonus is multiplied by everything Foundry built, so a
   full vault pays many times a cold one.
4. **Which arms Foundry again** — its bumpers light for 12 hits at ×5, and those hits
   recharge the vault. The loop closes.

Neither board can run this alone, which is what makes the pass structural rather than
optional. The wiring lives in the board data (`links`), not in the rules, so a new
cross-board relationship is a table entry rather than a branch — and `core/validate.lua`
rejects a link naming a board, meter or target that does not exist, because a typo here
would be a mechanic that silently never fires.

## 8. Failure and rescue **DECIDED**

- **Shared ball pool.** Team lives, not per-player. Pinball is random enough that
  per-player lives just manufacture blame.
- **Purgatory rescue.** A ball that drains doesn't die immediately — it enters a brief
  purgatory, and the *partner* can rescue it back into play by hitting a save shot within a
  few seconds. My mistake becomes your chance to be a hero, which is the best feeling co-op
  can produce.

**PROVISIONAL (2026-09-06):** Rescue window length, and whether the rescue is on the
drained board or the partner board. **Built as: 1.9s, on the drained board, using the
post the operator already has.**

- **The post is the rescue.** No new device and no new binding: the operator raises the
  same post they use to guard. It cannot have been up already — a raised post stops
  100% of drains, so if the ball drained, the post was down. Reaching for it is
  therefore always a real action taken inside the window.
- **1.9s**, which has to clear the post's own 0.26s of travel with room to spare or the
  rescue is a reflex test rather than the decision §8 describes.
- **The rally survives.** Relay count, rally score and the drain counter are all
  untouched until the window actually expires. That is the point: what the two of them
  built is not thrown away by one bad bounce.
- **It costs every vault charge on both boards** (§7.1). Without a cost, rescuing is
  always correct and the operator is a button-presser again (§6.2). With one, the
  question is live and has to be answered in under two seconds while being shouted at:
  *keep the rally, or keep the preparation?*

Shared ball pool and team lives are **still not built** — a failed rescue simply
re-serves, as before. That waits on session structure (§13.2).

## 9. Scoring

The multiplier lives on **passing**, not on shots. **DECIDED**

- **Relay heat. BUILT 2026-09-06.** A ball relayed back and forth without draining gets
  hotter with each crossing — worth more, and moving faster. The multiplier *is* the
  crossing count, so ×7 means "we have passed seven times without dropping it": a
  ten-crossing rally is worth 55,000 against 10,000 for the same ten passes spread over
  ten drains, 5.5×. "Moving faster" is a separate and much gentler curve, +5% arrival
  speed per crossing to +55%, because speed is a difficulty knob and a tunneling risk
  where score is free.
- **Simultaneity objectives** for the big jackpots: both boards holding a state at once,
  or matching shots within a window. Shots you cannot make alone. **Not built.**
- **Home-grind lines. BUILT, as the vault cap.** Foundry's bumpers charge Glasshouse's
  vault (§7.1) at ~0.6 hits/s to a ceiling of ×10, so staying home pays for about 17
  seconds and then stops. That is what makes the pass the only way to cash without
  making it compulsory — §5's temptation rule expressed as a number rather than a hope.

**OPEN:** Session structure. Endless high-score run? A goal-based run with an ending?
Roguelite meta between runs (drafting board segments)? This determines a lot of scaffolding
and should be answered before scoring is tuned.

> **That sequencing was not followed, and it is worth knowing.** The scoring above was
> built on 2026-09-06 while this question was still open, which means it assumes an
> endless session throughout: nothing resets, nothing ends, and `best_rally_score` is
> the only number that behaves like a result. Deciding on team lives or a run length
> will likely require revisiting the curve — a rally worth 5.5× more is a very
> different proposition when you have three balls than when you have infinite ones.
>
> It was built anyway because "it works but it isn't fun" needed answering and a score
> was the cheapest part of that. But the doc warned about exactly this ordering, so the
> debt is recorded rather than discovered later.

## 10. Presentation

All four are **built as of 2026-09-06**; the notes say how.

- **One shared camera on the active board.** Because both players are always attending to
  the same board, we need no split screen and make no compromise on framing. This falls out
  of the one-ball decision and is a large part of why it's the right call.
- **Dormant board as a live side panel**, small, with change highlights. The panel
  outlines itself when its cross-board state moves (§7.1), so a charge landing on the
  board nobody is watching is visible on that board.
- **Tube transit gets its own beat** — both boards pull back, the ball arcs between them
  leaving a wake, and rings collapse onto the entry point it is heading for. The HUD
  stays up throughout, which it did not originally: hiding it was what made the beat
  read as dead air, since §4.5 hands the sender the destination board's devices for
  exactly those 800ms.
- **Audio does the warning work.** Thirteen synthesized voices, no asset files. Incoming
  ball, operator devices arming, the purgatory window, and relay heat pitching the whole
  kit up as the rally gets hotter. The drain sound deliberately does not play when the
  ball crosses the line — the ball may still be rescued, and saying otherwise would be
  a lie told 1.9 seconds early.

## 11. Designing for online, while shipping local

Local co-op is the target. But the following are cheap now and expensive to retrofit:

- The operator rule in §6.1 (persistent states, not impulses) is the whole ballgame. Keep
  it and online is a networking problem; break it and online is a redesign.
- Tube transit time (§5) is a real latency budget — ~750ms of slack at 100ms RTT.
- Never assume the two players share a screen *in the simulation*. Presentation may; game
  logic must not.

Note the structural consequence: because the operator inputs into the *active* board, we do
**not** get clean one-client-owns-the-ball handoff. Both players' inputs affect one
simulation continuously. That's exactly why §6.1 matters — it's what makes plain
host-authoritative netcode sufficient instead of needing something exotic.

## 12. Non-goals for v1

- Online play (architected for, not built)
- More than 2 players
- Multiball
- Roguelite / meta progression
- Table editor
- Tilt / nudge mechanics — **OPEN** whether these exist at all, and who owns them

## 13. Open questions, consolidated

1. ~~Board identities — what is each board *for*?~~ **PROVISIONAL, see §7**
2. Session structure — endless, goal-based, or run-based? (blocks scoring)
3. Tube count and directionality
4. Operator resource model — cooldowns only, or a meter?
5. ~~Rescue window mechanics~~ **PROVISIONAL, see §8**
6. Does nudge/tilt exist, and is it an operator power?

## 14. First prototype

Build the smallest thing that answers *"does the rally feel good?"*:

- Two crude boards, one ball, one screen, two keyboards/gamepads
- One tube each way, working transit animation
- Two operator devices per board (one gate, one paddle) with real trade-offs
- No scoring, no modes, no cross-board unlocks

If the rally is fun and the tube transit reads clearly, everything else in this document is
worth building. If it isn't, nothing else saves it.
