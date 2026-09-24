# Glasshouse v4 — 2026-09-24

Why the board looks the way it does, and what each change measured. The board
file keeps only the current reasoning; earlier layouts live in git history
(`git log -p data/tables/board_b.lua`).

## What was wrong with v3

- **The pass was the default outcome of any flip.** `probe_shots` put 57 of 84
  swept shots into the tube. The funnel mouth (106px) sat exactly where the
  flux map shows nearly every upward shot travelling, so nothing else on the
  board was a shot.
- **Four lone standups in two banks**, placed where falling traffic was
  measured rather than where a shot goes: 3–7 swept-shot hits each, with no
  visual grouping.
- **The operator had only the post and the guard.** Foundry's operator also
  has a powered gate.
- **A trivial lane.** Lane C sat above the flippers, and 74 of 84 shots crossed it.
- **An empty lower-middle band.** The drain was doing the job content should do: 42.9px gap.
- **~370 of 438 lines of comments** in the board file, several declaring
  themselves void.

## What v4 is

| | |
|---|---|
| Pass funnel | Mouth 106 → 84px. Still the main shot: 45/84 swept shots |
| VAULT | 3 drop targets beside the funnel mouth (new `drop = true`) |
| GALLERY | 3 inline standups on the right, tilted to shed falling balls inward |
| S-U-N lanes | Top lanes. Flipper buttons rotate the lit lanes (`lane_change`); a gold skill lane opens after each serve and arrival, and moves one lane each time |
| Magnet | Operator device over the right flipper (`kind = "magnet"`). Catches falls up to ~700px/s, drops the ball onto the bat, and cancels the skyway combo (§6.2) |
| Right shoulder rail | Turns wall-running balls in toward the inlane |
| Skyway | One-way, in at the left mouth |
| Drain gap | 42.9 → 35.9px |

## Measurements

| | v3 | v4 |
|---|---|---|
| Swept shots → pass (`probe_shots`) | 57/84 | 45/84 |
| Swept shots → any target | 19 | 44 |
| Target hits over 8 matches (`probe_fun`), min..max | 17..63 | 12..17 |
| Received-ball pass rate, best lead (`probe_received`) | 63% | 54% |
| Ball life / drains per s (`probe_identity`, 12 seeds) | 8.05s / 0.077 (5 seeds) | 7.46s / 0.075 |
| Points/s | 185 | 244 |

Foundry on the same 12 seeds: 8.50s, 0.067 drains/s, 45 pts/s.

## Things that cost a wrong turn

- **Received balls went down the right outlane 71% of the time** in the
  first v4 draft. v3's vault target at (352,340) had been deflecting the
  right-column fall inward. Nobody had designed that, so removing the target
  removed the deflection. The shoulder rail, centring the S-U-N lanes and the
  arrival point, and tilting both banks inward brought it to 2–4%.
  `probe_received` splits misses by side for exactly this.
- **The gap did not move the drain rate.** Swept 30–43px over 12 seeds: 0.072–0.077
  drains/s, inside the noise. 36px was chosen to keep the identity gate's 8px
  margin over Foundry. The gap is not the instrument that makes Glasshouse deadlier.
- **The magnet's drop point is a pixel decision.** Directly over the pivot,
  the ball rolls back up the inlane. 5px inside the pivot, it rolls down the bat
  and a flip 1.00–1.20s after release hits the vault or makes the pass.
- **The wedge gate forbade a real bank.** Aligned members of one bank may now
  sit within `C.BANK_SEAM` (3px): a seam in one face is not a throat.

## Open

- Glasshouse is only ~12% deadlier per second than Foundry now. If the identity
  should be sharper, the outlanes and the magnet's duty limit are the knobs.
  The gap is not.
- The serve and most arrivals come down lane U (26 of 30 lane crossings in 8
  matches). Lane change makes that playable, but S and N are rarely crossed
  naturally.
- The skyway is a 5% shot (7/140 swept, all completed).
