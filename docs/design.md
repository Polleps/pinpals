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
- **The pass carries state.** Exit velocity and spin survive the trip. A clean ramp shot
  arrives high and controllable; a desperate flail arrives fast and low. A bad pass is a
  real thing you can do to your friend.
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

**OPEN:** Board identities/themes, and what each is *good at*. The specialisation is the
reason to pass, so this needs to be concrete before layout work starts.

## 8. Failure and rescue **DECIDED**

- **Shared ball pool.** Team lives, not per-player. Pinball is random enough that
  per-player lives just manufacture blame.
- **Purgatory rescue.** A ball that drains doesn't die immediately — it enters a brief
  purgatory, and the *partner* can rescue it back into play by hitting a save shot within a
  few seconds. My mistake becomes your chance to be a hero, which is the best feeling co-op
  can produce.

**OPEN:** Rescue window length, and whether the rescue shot is on the drained board (the
operator triggers a device) or the partner board. Leaning: an operator device on the
drained board, because it keeps both players' attention in one place.

## 9. Scoring

The multiplier lives on **passing**, not on shots. **DECIDED**

- **Relay heat.** A ball relayed back and forth without draining gets hotter with each
  crossing — worth more, and moving faster. The rally becomes simultaneously more valuable
  and more likely to end. A pure risk curve generated entirely by cooperation.
- **Simultaneity objectives** for the big jackpots: both boards holding a state at once,
  or matching shots within a window. Shots you cannot make alone.
- **Home-grind lines** that reward not passing, so §5's temptation rule holds.

**OPEN:** Session structure. Endless high-score run? A goal-based run with an ending?
Roguelite meta between runs (drafting board segments)? This determines a lot of scaffolding
and should be answered before scoring is tuned.

## 10. Presentation

- **One shared camera on the active board.** Because both players are always attending to
  the same board, we need no split screen and make no compromise on framing. This falls out
  of the one-ball decision and is a large part of why it's the right call.
- **Dormant board as a live side panel**, small, with change highlights.
- **Tube transit gets its own beat** — the camera can pull out slightly to show both boards
  and the ball travelling between them. Free drama, and it doubles as the handoff telegraph.
- **Audio does the warning work.** Incoming ball, operator device arming, purgatory timer —
  all of these need to be legible without looking.

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

1. Board identities — what is each board *for*? (blocks layout work)
2. Session structure — endless, goal-based, or run-based? (blocks scoring)
3. Tube count and directionality
4. Operator resource model — cooldowns only, or a meter?
5. Rescue window mechanics
6. Does nudge/tilt exist, and is it an operator power?

## 14. First prototype

Build the smallest thing that answers *"does the rally feel good?"*:

- Two crude boards, one ball, one screen, two keyboards/gamepads
- One tube each way, working transit animation
- Two operator devices per board (one gate, one paddle) with real trade-offs
- No scoring, no modes, no cross-board unlocks

If the rally is fun and the tube transit reads clearly, everything else in this document is
worth building. If it isn't, nothing else saves it.
