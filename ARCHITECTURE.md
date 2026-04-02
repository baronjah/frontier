# FRONTIER — Architecture
_Last updated: 2026-03-27_

Everything is code-only. No hand-made .tscn nodes — all geometry built in `_ready()`.
Two scene roots exist only as script anchors.

---

## Scene → Script map

| Scene | Script | Role |
|---|---|---|
| main.tscn | space_world.gd | Space: stars, planets, station, aliens, ship |
| demo_spaceport.tscn | space_port.gd | BooBies interior: diner, booths, NPCs, clerk |
| gravity_demo.tscn | gravity_demo_world.gd | Sandbox: planetoid, station, platform ship |
| landing_demo.tscn | landing_demo.gd | Flat planet test |

---

## Data flow: world → ship

`space_world` builds the ship Node3D, attaches `ship_controller.gd`, then passes data via `set_meta()`:
```
_ship.set_meta("alien_data",     ALIEN_DATA)       # array of alien dicts
_ship.set_meta("boobie_pos",     BOOBIE_POS)        # Vector3
_ship.set_meta("location_nodes", _locations)        # array of Location nodes
```
Ship's `_ready()` fires after world's (Godot defers child-during-ready), so metadata is ready.

---

## Economy persistence (GameState autoload)

```
scan alien (R)         → pending_aliens.append({id, woolongs})
dock at BooBies (L)    → sync credits/cargo/woolongs to GameState, save_game()
enter SpacePort (G)    → space_port loads from GameState
F at CLERK desk        → pending_aliens cleared, woolongs credited, save_game()
G at launch pad        → save to GameState, change_scene_to main.tscn
```

GameState fields: `credits · woolongs · cargo · registered_aliens · pending_aliens · ship_position · ship_basis`
Save file: `user://frontier_save.json`

---

## Gravity system

`GravityWell` (Area3D) — emits inverse-square gravity to everything inside its sphere.
Bodies call `add_well(self)` / `remove_well(self)` via Area3D signals.
Each body accumulates all active well accelerations per frame (vector sum = correct multi-gravity).

Key values:
- Planetoid surface g ≈ 5 m/s² at r=60m: `density=3200, radius=60`
- Planet surface (landing demo) g ≈ 9.8: `grav_param = 9.8 * floor_dist²`
- BooBies / SpacePort constant floor g: `grav_param = 9_800_000`, well at y=-1000

Platform ship rule: any structure not coaxial with main planet needs its own well strong enough to dominate at floor level.

---

## Planet LOD (planet_lod.gd)

4 levels based on camera distance:
```
d > 12000m  LOD0  emissive dot (grain of sand)
d > 3000m   LOD1  simple sphere (12 segs)
d > 800m    LOD2  rough sphere (32 segs) + transparent ocean overlay
d < 800m    LOD3  8×8 chunk terrain grid at +Y pole
                  each chunk: tile + collision + 8-20 grains + optional rock
```
Atmosphere halo always rendered within 6× radius. Observer switches: ship in space, PlayerBody on foot.

---

## ProceduralBeing (procedural_being.gd + being_blueprints.gd)

Blueprint-driven 3D body builder. Part types:
- `bone` — CapsuleMesh limb
- `joint` — SphereMesh connector / head
- `panel` — BoxMesh armour plate
- `edge` — CylinderMesh wire between two points
- `eye` — emissive sphere
- `thruster` — engine bell with inner glow disc

```gdscript
var alien := ProceduralBeing.build(BeingBlueprints.humanoid_alien(Color(0.4, 0.8, 0.3)))
add_child(alien)
```

Presets in `being_blueprints.gd`: `humanoid_alien()` · `mecha()` · `scout_ship()`

---

## Key rules

- Every autoload access guarded: `if has_node("/root/GameState"):`
- PlanetLOD observer set explicitly: `_planet_x.set_observer(_ship)` — doesn't auto-detect
- `_cam.make_current()` must be called after player camera added — or black screen on exit
- `set_law()` in Scriptura takes `"A"` or `"B"` only — not arbitrary strings
- Scan gives no woolongs immediately — deferred to CLERK desk via `pending_aliens`

---

## What exists vs what's missing

**Exists:**
- Flight, boost, roll, flight assist, scanning, trading, docking
- Full on-foot system with multi-gravity, jetpack, grab, rippable doors
- BooBies interior with 4 NPCs, 3 booths, clerk registration
- GameState persistence across all scene changes
- Planet LOD 4 levels
- ProceduralBeing builder

**Missing / next:**
- Shipyard: spend woolongs on engine/cargo/scanner upgrades
- Alien NPCs that react (flee, patrol, attack)
- Same-ship landing (approach + touchdown, not teleport)
- Physical cargo in world (crates, pods)
- Resource mining
