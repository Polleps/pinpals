# Foundry foundation

Foundry is now 640 x 960 (43% wider), with the original ball size, flipper
spacing, and lower inlane shapes. The upper shoulders flare out; the lower
448px deck is translated 96px right. Glasshouse keeps its current layout.

The left shoulder houses a powered workshop loop with a dedicated left-inlane
return. The upper arena holds the bumper triangle. A flush generator marks the
power station. The right shoulder remains open for future machinery. Section
surfaces, labels, and glowing wiring distinguish these spaces without adding
solid objects across the shooting field.

The always-open pass is just right of centre. Moving it all the way to the right
shoulder made it practically unreachable from the right flipper. Its entrance
retains the previous local edit's shortened y=470 channel, now at x=350.

## Playing the workshop

1. Shoot through the striped generator at (411,490). A crossing at 180px/s or
   more gives one power; 850px/s gives two. Two powers ready the workshop (was three
   until 2026-09-24: in eight matches only four runs happened).
2. The operator holds the existing gate action (P2 Up arrow while Foundry is
   active; gamepad A). The powered gate takes 0.3 seconds to open.
3. Shoot the workshop entrance at (240,550). Entry consumes the stored power,
   closing the gate behind the ball. The ball is already on the raised track
   and remains free to finish even if the operator releases the button.
4. A full loop exits at (153,650), into the left inlane. It awards the existing
   750 ramp points and lights the 12-second pass combo. Rolling back spends the
   attempt but does not earn a completed ride. Unspent power survives drains.

The HUD shows power, the actual key, and completed/attempted runs. The physical
generator is a flush energy strip, not a simulated mechanical spinner.

## Extending it

- `sections`: named floor surfaces with bounds and colors.
- `switches`: a sensor's bounds, speed thresholds, debounce, and circuit ID.
- `circuits`: stored capacity, destination route, and visible wire polyline.
- `devices[].circuit`: gates an operator command on stored power.
- `ramps[].device`: admits entry only once that device is powered and open.

`core/circuit.lua` owns serializable energy and route state. Physics emits switch
crossings and ramp events; presentation reads the same state. Wiring is validated
before loading. New ball transformations or boss mechanisms can use these
connections; neither is implemented yet. The coordinate overlay names the new
switches, sections, and wire vertices.

## Verification and limits

- `make check`: layers, lint, types, geometry, 160 core tests, 62 physics tests,
  including a complete generator -> gate -> loop -> return test.
- `PINPALS_SUITE=tests.probe_workshop love . --test`: 140 shots per power state,
  five contact points per flipper, 14 seeds (9700 + seed*31). Cold: 58 passes,
  no workshop entries. Powered: 57 passes, 14 entries, all 14 completed and
  returned to the flipper deck. No stalls. A ball resting at a flipper pivot
  gets one fresh 0.22-second flip, so a catch is not confused with a geometry jam.
- Eight 180-second matches (`probe_fun`, seeds 8277..15116 at intervals of 977):
  84 passes versus the pre-change baseline's 89; 85 generator crossings, two
  workshop entries, both completed, zero stalled seeds. These random controls
  rarely aim at the workshop; its human difficulty/frequency remains to tune.
- `probe_serve`: all 240 Foundry serves reached tube-mouth height; neither Forge
  target received any hits in the first second after a serve.
- `probe_soak`: ten minutes / 144,000 ticks, no broken invariants, longest slow
  spell 0.47s. This includes circuit bounds and active-route consistency checks.
- Desktop captures inspected for Foundry, transit, and a powered workshop ride.

`love . --shot 100 --workshop` charges the circuit through two actual generator
crossings and photographs a launched workshop ride. `--shot 1 --workshop` shows
the powered entrance, and `--shot 400 --pass` shows the board handoff. Screenshot
setup only runs with `--shot`. Restart LÖVE for rule/render changes; board-only
edits continue to hot reload.
