# Boards v2 — bigger, more traditional, actually reachable

**Status:** plan, not built · 2026-09-06 · companion to `design.md` §7

---

## 1. The diagnosis, measured

The brief was "the boards need to be bigger and have more features, with two
slingshots and two side lanes, and the ramp is way too close to the flippers".
Running `probe_reach` first turns three of those into one root cause.

Foundry, 50 swept flipper shots — the reachable map:

```
       0   0   1   2     (x00 px)
 168         =*             the ramp channel, and
 240         #*             nothing else above y=280
 336   -- =  %+
 432  .:.=-::.##
 552 +*-:.-+***+-::+.       everything else lives
 648   #@%%****%@@@@*       in the bottom 150px
```

    pass 54%   drain 44%   left orbit 14%   right orbit 0%

Board B is the same shape: pass 66%, left orbit 6%, right orbit 10%.

**The upper playfield is not sparse, it is unreachable.** The pass ramp is a
106px-wide channel running from y=540 to y=150 through the dead centre of a
384px board — a wall across the middle with 39px of playfield either side of
it. A ball leaving a flipper at a realistic angle travels 70–100px sideways
before it reaches y=540, so it cannot get past the channel. That is *also* why
the ramp feels too close to the flippers (mouth 148px above the pivots) and why
adding features to the current boards would be adding things nothing can hit.

Board A's own comments already record this being fought at the wrong end: the
mouth was raised 600 → 540 to buy 14%/10% orbit reach, and the note admits the
trade is monotonic — every pixel of reach is bought with pass rate. It is
monotonic because the *width* of the obstruction was never the variable.

So the three complaints have one fix: **stop putting a 106×390px wall down the
middle of the board, and use the space that frees up.**

## 2. What v2 is

| | now | v2 |
|---|---|---|
| Playfield | 384 × 768 | **448 × 960** |
| Ball as % of width | 4.5% | 3.9% (a real table is 5.2%) |
| Mouth above pivots | 148px | **≥ 275px** |
| Bottom furniture | flippers, one centre drain | **outlane / divider / inlane / slingshot, both sides** |
| Drain paths | 1 | **3** (centre + two outlanes) |
| Element kinds | walls, bumpers, standups | + slingshots, rollovers, drop targets, spinner |
| Pass shot | identical centre channel on both boards | **different in kind per board** |

The ball, gravity, flipper length and every tuned threshold stay put. Growing
the board and not the ball is the whole point: it is what buys room, and it is
also the one thing here that changes feel globally, so §7 isolates it.

Honest trade recorded up front: at 448 wide the ball is *relatively smaller
than on a real table*, and at 960 tall it spends longer crossing the board
under unchanged gravity. Expect ball life up and points/s down before any
retuning. If it reads as floaty the knob is gravity, not ball radius — radius
is baked into a dozen measured thresholds.

## 3. The traditional bottom

Every real table spends its bottom 25% on the same five things, and we have
none of them. Budget per side at 448 wide (153px from wall to flipper pivot,
which is 34% of the width — the same fraction a Williams playfield uses):

```
  x=14 ── outer wall
  14..40    outlane        26px, 1.5 ball widths
  40..48    lane divider   8px
  48..76    inlane         28px
  76..150   slingshot      74px triangle, kick face on the hypotenuse
  x=167 ── left flipper pivot
```

Vertically: rollover buttons at the lane tops (y≈700), slingshots y≈786..848,
pivots y=858, drain_y=935.

**Slingshots** are the one place this design has to argue with itself.
`design.md` §6.1 forbids impulses — but that rule is about *operator* actions,
and a slingshot is table furniture, not something a player fires. It is built
the way bumpers already are: a static fixture with restitution > 1, no new
machinery, and the same "no debounce needed" measurement applies.

**Outlanes are the interesting half.** They give the board a second way to lose
the ball, and that fixes a real defect: today the post guards the *only* drain,
so a raised post stops 100% of drains and the geometry note in `board_a.lua`
worries — correctly — that a guard which costs nothing gets held up forever.
With outlanes the operator can no longer seal the board. It also sharpens §8:
a ball down an outlane is unrescuable, so the rescue stops being a universal
undo. Both effects are large and both must be measured, not assumed.

## 4. New element kinds

Each is data (`§5.3`), validated in `core/validate.lua`, geometry-checked in
`core/geometry.lua`, built in `sim/board.lua`, drawn in `app/render.lua`.

- **`slingshots`** — three points; the named face gets restitution ~1.35 and
  reports a `sling` event. Geometry check: not inside a flipper's swept arc,
  and no sub-ball-width throat against the inlane wall.
- **`rollovers`** — sensor circles in a group (`lane = "abc"`). Lighting the
  whole group awards and resets, reusing the bank rule shape. This is what
  gives an inlane a reason to exist.
- **drop targets** — `targets` gain `drop = true`. A struck drop target goes
  down (fixture → sensor) and stays down until its bank completes, then all
  reset. Clearing a bank therefore *physically opens the shot behind it*,
  which is the cheapest good mechanic in pinball and needs one boolean in the
  step loop.
- **`spinners`** — a sensor lane that awards proportional to crossing speed,
  with a blade the renderer spins. Phase 5.

Deliberately **not** built: scoops/saucers (hold-and-eject needs a state
machine and flirts with "nobody waits"), captive balls, magnets.

## 5. The two boards

The upper field is where `design.md` §7's remaining open item lives: *"the two
boards differ in what they are for, but not yet in how they are played."* v2
answers it by making the pass shot itself a different shape on each board.

### Foundry — the pass is an orbit, and the gate is a diverter

- Full **left and right orbits** running up the sides and over the top, with
  the right orbit's exit feeding the tube mouth.
- The **gate becomes a diverter** at the top of the orbit: open, the orbit
  dumps into the tube (the pass); closed, the orbit carries on round and
  returns down the habitrail into the inlane. §6.2's stated trade — "opens the
  pass, closes the safe return loop" — becomes literally true instead of
  approximately true, and it is the most traditional device on any real table.
- A **bumper pod**: four bumpers in a pocketed nest in the upper left, entered
  through a mouth, rather than three naked circles beside a lane. Foundry's
  declared chaos should come from a place you shoot *into*.
- Two centre standups so the middle of the board is not empty once the channel
  is gone.

### Glasshouse — the pass is a short centre ramp

- A **36–40px** ramp, entrance at y≈600, tube at y≈300: 300px of channel
  instead of 390px of channel that is also 106px wide. It stops being a wall.
- A **three-target drop bank** across the right orbit's entrance: clear it and
  the orbit opens. Precision board, precision reward, and the reveal is
  physical.
- A **spinner** in the left orbit — the classic "fast ball pays more", which is
  the one scoring line that rewards Glasshouse's flatter, faster geometry.
- Still no bumpers.

## 6. What this makes stale

Every measured table in `board_a.lua`, `board_b.lua`, `design.md` §7 and
`prototype.md` §5 is a measurement of the geometry being replaced. The mouth-
height sweeps, the post's 711/713/715 cliff, the bumper x/r sweep, the board
identity table, the pass rates, ball life, points/s — **none of it carries
over.** They get deleted and re-measured, not edited. Writing a number forward
because it used to be true is exactly the failure `CLAUDE.md` lists fourth.

`core/validate.lua` also needs relaxing in one place: it hard-requires exactly
two devices, one gate and one paddle. Phase 5 may want a third.

## 7. Phases

Each phase ends green on `make check`, with a screenshot **looked at**, and
every probe number averaged over ≥6 seeds.

**0 — room.** Derive the render layout from the real window size instead of the
hardcoded 1000×780, and size the window to the desktop. Then resize both boards
to 448×960 by scaling the existing coordinates ×1.167/×1.25 — a pure zoom,
nothing redesigned. Re-run `probe_identity` and `probe_reach`.
*Gate:* all gates green; the resize's effect on ball life and pass rate is
recorded **on its own**, before anything else moves.

**1 — element kinds.** Slingshots, rollovers, drop targets: validator, geometry
checks, sim fixtures, renderer, core tests. No board uses them yet.
*Gate:* new geometry checks fail on a deliberately broken fixture board.

**2 — the traditional bottom.** Outlanes, dividers, inlanes, slingshots,
rollovers on both boards.
*Gate:* `probe_identity` for drain split (centre vs outlane) and ball life;
`probe_post` re-run, because the post's whole meaning changed.

**3 — break the centre wall.** Foundry's orbit-and-diverter, Glasshouse's short
ramp. Re-tune both gates' open/closed angles.
*Gate:* `probe_reach` — no more than 55% of swept shots ending at the ramp, and
**≥25% reaching above y=400 outside it.** This is the phase the whole plan is
for; if this number does not move, nothing else was worth doing.

**4 — upper playfield.** Bumper pod and centre standups on Foundry; drop bank
and standups on Glasshouse.
*Gate:* a new `probe_coverage` — *every* scoring element is struck at least 5
times per 120s, averaged over 6 seeds. Foundry's bumpers once measured 3 hits
in 180s with two of three at exactly zero; a gate is cheaper than rediscovering
that.

**5 — spinner, shooter lane, and possibly a third operator device** for the
outlane guard. Optional, and only if 2–4 leave the board wanting it.

**6 — rebalance and rewrite.** Re-measure both identities end to end and
rewrite §5's stale tables from the new numbers.

## 8. The risks worth naming

1. **Three drain paths may make both boards far too drainy.** Outlane width is
   the tuning knob and it is a steep one. If drains/s more than doubles,
   narrow the outlanes before touching anything else.
2. **The rescue gets rarer and the post gets weaker.** That is intended, but
   §8's 1.9s window was tuned against a post that stopped everything. Expect to
   retune it, and check the rescue does not become a mechanic nobody sees.
3. **A bigger board under unchanged gravity plays slower.** Phase 0 measures
   this alone precisely so it is not confounded with phases 2–4.
4. **The orbit-as-pass on Foundry could be much harder than a centre channel.**
   If the pass rate collapses below ~35% the boards stop being able to hand the
   ball back and forth, and the game has no rally. `probe_reach` in phase 3 is
   the early warning.
5. **Scope.** Phases 0–4 are the brief. 5 is not.
