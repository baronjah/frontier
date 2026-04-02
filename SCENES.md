# FRONTIER — Scenes

---

## Existing scenes

### scenes/gravity_demo.tscn  ← current startup scene
On-foot gravity demo. Planetoid + station + landed ship.
**What works:** walking, jumping, custom gravity on any surface, pick up crates, rippable doors.
**What's missing:** nothing, it's a complete demo of its own system.

### scenes/main.tscn
The space game scene (ship, planets, BooBies, aliens).
**What works:** flight, boost, scanning aliens, docking, market buy/sell, credits/cargo.
**What's missing:** nothing visible at market (no cargo objects), no way to land and get out.

---

## Proposed demo scenes  (build these one at a time)

### demo_market.tscn
**Tests:** docking, market HUD, buy/sell, credits, cargo limits
Setup: ship starts 200m from BooBies, already facing it.
No planets, no aliens, just the station and one trade route to test (BooBies ↔ one other location 500m away).
Success: can buy food at location A, fly 500m, sell at location B, credits go up.

### demo_trade_route.tscn
**Tests:** economy balance across all 3 locations
Setup: three locations placed 1000m apart in a triangle so you can do a full loop quickly.
Same markets as main scene. No aliens, no distractions.
Success: can run the triangle and end up with more credits than you started.

### demo_shipyard.tscn
**Tests:** Phase 3 — ship upgrades
Setup: one SHIPYARD location, ship starts with 500 credits.
Shows upgrade menu (cargo expansion, thrust boost, scan range boost).
Success: buy cargo expansion, _cargo_max goes from 20 to 30.

### demo_discovery.tscn
**Tests:** Phase 4 — findable objects (wrecks, cargo pods)
Setup: 5–10 scannable objects scattered in space, no markers.
Flying within range (say 300m) triggers a discovery message + adds rare goods to cargo.
Success: find 3 objects, collect exotic tech, sell it at a station.

### demo_landing.tscn
**Tests:** the ship ↔ on-foot transition
Setup: a single planet. When docked (L key near planet), instead of market, ship "lands" and switches to player_body walking on the surface.
Pressing L again launches back to ship.
This bridges ship_controller.gd and player_body.gd for the first time.
Success: get out, walk around, get back in, fly away.

### demo_mecha.tscn
**Tests:** Phase 4 endgame — mecha mode
Setup: ship lands, player gets out (from demo_landing), presses a key to enter mecha frame.
Mecha = player_body but bigger, different stats.
This is likely the most complex demo — needs demo_landing working first.

---

## Suggested build order

```
demo_market        ← verify what we just built actually works
  ↓
demo_trade_route   ← tune economy numbers
  ↓
demo_shipyard      ← Phase 3 upgrades
  ↓
demo_discovery     ← Phase 4 finding stuff
  ↓
demo_landing       ← bridge flight + on-foot
  ↓
demo_mecha         ← endgame
  ↓
main.tscn          ← assemble all pieces together
```

---

## Notes on main.tscn right now

The planets and BooBies are thousands of meters away — at max speed (380 m/s) it takes:
- BooBies: ~6 seconds (2.4 km away)
- Betelgeuse: ~17 seconds (6.5 km away)
- Planet X: ~26 seconds (10 km away, boost helps)

For demo scenes, place locations much closer (200–1000m) so testing is fast.
For the real main scene, the distances are part of the experience.
