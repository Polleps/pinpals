# Pinpals — Prototype 0.1

**Status:** built and running · **Companion to:** `design.md` §14, `technical-choices.md`

The §14 prototype: the smallest thing that can answer *"does the rally feel good?"*

```
make run                  play
make check                every gate (§7), ~0.7s
make shot TICKS=420       render N fixed steps to a PNG and quit
```

Controls, shared keyboard. Your keys do different things depending on where the
ball is — that is the game, not a bug.

| | Player 1 (Foundry) | Player 2 (Glasshouse) |
|---|---|---|
| Flippers, when the ball is on **your** board | `A` / `D` | `←` / `→` |
| Gate, when it is on **their** board | `W` | `↑` |
| Post, when it is on **their** board | `S` | `↓` |

`R` restart · `F1` debug readout · `Esc` quit

---

## 1. What is in it

Exactly §14's list, and nothing else. No scoring, no modes, no cross-board unlocks.

- Two crude, non-mirrored boards; one ball; one screen; two players
- One tube each way, with the transit beat animated between both boards (§5, §10)
- Two operator devices per board, both persistent states with real trade-offs (§6)
- Roles implicit in ball position, no role UI (§4)
- A rally counter, which is the instrument for the question the prototype asks

The architecture is the one in `technical-choices.md` §5, enforced by a gate rather
than by good intentions: `core/` is pure Lua, `sim/` may touch `love.physics` and
nothing else, dependencies run `app → sim → core`. `scripts/check_layers.sh` fails
the build if that erodes.

## 2. The two devices

Both are persistent states with a visible travel time (§6.1), and both give and
take (§6.2). They interlock, which is where the shouting comes from.

**Gate** (~300ms) — seals the top of the pass ramp.
Closed, a ramp shot comes back down to you: the ramp is a safe return loop and
you keep the ball. Open, the ramp feeds the tube and the ball is your partner's
problem. You cannot pass without your partner opening it for you.

**Post** (~260ms) — rises from the floor between the flippers.
Up, it guards the centre drain, which is the only drain on either board. Up, it
also blocks the ramp shot completely — measured, not asserted: the pass goes from
20/32 to **0/32** while the post is raised. So the operator cannot keep their
partner safe and let them pass at the same time, ever. Both facts are locked in by
tests.

## 3. What measuring changed

The headless harness earned its keep before a human ever played it.

- **The pass shot did not exist.** The first layout put the pass lane down the
  right wall, the way a pinball orbit usually runs. A sweep of flipper contact
  points showed shots crossing that height between x=145 and x=239 — the lane was
  at x=328. It was hit **1 time in 30**. The lane moved to a flared centre ramp,
  where shots actually go, and now lands ~60% from a clean flip. `tests/sim/spec.lua`
  keeps it there.
- **Flippers were mounted wrong.** Box2D takes a revolute joint's reference angle
  from the bodies' angles at construction, so building the flipper already rotated
  silently redefined its limits. It swung into the floor.
- **Flippers chattered.** Driving the motor toward a target angle compared each
  step reverses every other step once the limit overshoots slightly. Drive at the
  limit and let the limit hold it.
- **The ball ceiling was ~2x too fast.** At 10x scale, distances and gravity are
  10x, so speeds scale by sqrt(10), not 10. The old ceiling let the ball cross more
  than its own diameter per step, and bumpers with restitution > 1 pumped it there.
- **A 30fps frame ran the game in slow motion.** `MAX_CATCHUP` was 8 steps; a
  30fps frame legitimately needs 8 at 240Hz, so the cap fired in normal play and
  silently dropped time.

None of these are visible by looking at the screen for a few seconds, and all of
them would have been blamed on "Box2D feels bad" — the exact §11 risk.

## 3a. Playtest 1 — 2026-09-05

Verdict: **physics feel fine, boards were bad.** That is the good half of the
§11 risk table clearing — Box2D can carry this game — and the bad half being a
layout problem, which is cheap to fix because layouts are data (§5.3). Nothing
in `core/`, `sim/` or `app/` changed to fix any of the below.

Reported: the ball gets stuck in several places, and the flippers poke out far
enough that a slow ball wedges beside them. Found and fixed:

- **Two wall chains had a local minimum.** Board A's lower right turned back
  *up* at the end to meet the flipper pivot, putting a V at (300,702) that
  swallowed the ball. Board B's lower left had the same at (84,702). Wall
  chains that feed a flipper now descend monotonically. Any local minimum in a
  chain is a pocket.
- **The wall ended underneath the flipper pivot.** That put the wall's endpoint
  inside the flipper's own rectangle and left a notch *behind* the pivot, where
  a slow ball sat unreachable by a flipper that rotates away from it. Walls now
  stop just outside and above the pivot: a ~7px gap, which the 17px ball cannot
  enter, and clear of the swept arc.
- **The closed gate was a shelf.** A level bar across a channel holds a ball
  forever, and tilting it only moves the resting place into the corner against
  the wall — every downward-facing corner is a wedge. Fixed by roofing the ramp
  head so nothing can land on the gate at all.
- **Board B's two rails crossed** into a funnel that caught 19 of 182 test
  drops. They no longer touch.

The scan that found these also flags a shelf on top of the closed gate inside
the now-sealed ramp head. That one is a scan artifact: 720 simulated seconds of
random play and 640 adversarial gate-slams at every ball speed and every closing
moment never put a ball there, because anything with enough speed to enter the
head has enough to reach the mouth. Both probes are now regression tests.

## 3b. The geometry gate

`core/geometry.lua`, run by `make geometry` and as part of `make check`. Board
layouts are hand-authored coordinates, and every board bug so far has been a
coordinate typo found by simulating thousands of ball drops — or by you playing.
All of them are visible in the data. Four checks, no physics:

| Check | Finds |
|---|---|
| **bowl** | a wall vertex lower than everything it joins. A peak sheds the ball and is fine, so this is not "chains must be monotone", it is "chains must never turn back up". Vertices are keyed by position, so a bowl formed *between* two polylines is caught the same way as one inside a chain. |
| **flipper-jam** | wall geometry inside a flipper's swept arc — either it jams the flipper, or it leaves a notch behind the pivot that the flipper rotates away from. |
| **wedge** | any two surfaces closer than the ball is wide: wall/wall, bumper/wall, bumper/bumper. Proximity, not intersection — board B's rails never crossed, they converged to 10.8px. |
| **gate-leaks / gate-blocks / post-misses / post-stuck-out** | devices that do not do what they claim: a gate whose closed tip does not reach a wall, or whose open position leaves less than a ball of clearance; a post that does not span the drain gap, or does not retract below the drain line. |

Reintroducing the bug from playtest 1 gives, instantly:

```
geometry: 2 defect(s)
  board a [bowl] wall vertex (300, 702) is lower than everything it joins: the ball settles here
  board a [flipper-jam] wall 3 passes through the right flipper's swept arc at (251, 692), 4.0px from the pivot
```

`tests/core/geometry_spec.lua` reconstructs all eight shipped bugs and asserts
each is caught, plus two legitimate shapes (a chevron peak, a dangling wall end)
that must *not* be flagged. A validator nobody has tested against real bugs is
decoration.

**Not implemented:** a "the closed gate is a horizontal shelf" check. It cannot
be made precise — the post is a horizontal shelf on purpose, and the gate is
7.4 degrees off horizontal and perfectly safe because it is roofed. Whether a
surface is a trap depends on whether the ball can reach its upper side, which is
a reachability question that static analysis cannot answer. That class stays
covered by the two stuck-ball tests in `tests/sim/spec.lua`.

## 4. Calls made to unblock the build

These answer `design.md` §13 questions **provisionally**, for the prototype only.
They are choices to react to, not decisions.

1. **Board identities (§13.1).** Foundry is chaotic and forgiving — a bumper
   cluster keeps the ball alive but crowds the aim. Glasshouse is clean and fast,
   with no bumpers and a wider flipper gap: easy to aim the pass, punishing to sit
   on. Their ramps are on opposite sides so they do not reward the same muscle
   memory. This is a guess with a shape, not an answer.
2. **Tube count (§13.3).** One each way, per §14.
3. **Operator resource model (§13.4).** Neither cooldowns nor a meter. The
   devices' own trade-offs are the restraint, which is worth testing before adding
   any economy on top.
4. **Rescue (§13.5).** Not built. A drain re-serves on the board that lost it
   after ~0.9s. Purgatory rescue is a second mechanic on top of the one being
   tested, and §14 does not ask for it.
5. **The operator acts on the destination board during transit.** The moment the
   ball enters the tube the destination becomes active, so for those ~800ms the
   sender is already the operator over there, preparing the landing. This falls
   straight out of §4 and makes the transit beat active for both players.
6. **The centre gap is the only drain.** Both side lanes feed the flippers. It
   makes the post the single clear guardian and keeps the prototype about the
   rally rather than about cheap outlane losses.

## 5. Known soft spots

- **The post may be too absolute.** Blocking 100% of pass shots is a clean,
  legible trade, but while it is up the flipper player has nothing productive to
  do, which brushes against pillar 1 ("nobody waits"). Narrowing it, or letting
  flat shots under it, is the obvious first tuning knob.
- **The pass may be too easy** at ~60% from a static, perfectly timed flip. A real
  moving ball is harder, so this needs a human before it is tuned.
- **Glasshouse is thin.** Two bare rails is not yet a character, just an absence
  of one. It needs whatever answers §13.1 properly.
- **The upper playfields are empty.** Both boards are mostly a ramp plus space.
  Fine for testing the rally, but there is nothing to do while you hold the ball.
- **No audio.** §10 wants audio doing the warning work; the module is switched off.
- **The §7 lint and static-analysis gates are live.** `luarocks` had been broken
  by a Homebrew `lua` bump to 5.5 that left its shebang pointing at a deleted
  `lua5.4`; upgrading it to 3.13 fixed that. `luacheck` and `lua-language-server`
  are installed and wired into `make check` as hard gates, configured by
  `.luacheckrc` and `.luarc.json`. Both are clean across all 18 files.
- `busted` is installable again (`luarocks install --local busted`, and it is
  installed) but nothing uses it yet: `tests/harness.lua` stays the
  dependency-free stand-in with the same API, so `make test-core` needs no rocks.
  Switching the specs over to `busted` is a separate call, not a blocked one.
  Note `~/.luarocks/bin` is not on `PATH`, so `busted` needs its full path.

## 6. The question

Play it. The prototype exists to answer one thing, and only a human at the keyboard
can: **does the rally feel good, and does the tube transit read clearly?** If yes,
everything in `design.md` is worth building. If not, nothing else saves it.
