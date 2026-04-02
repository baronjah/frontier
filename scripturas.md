# FRONTIER — Scripturas
Every script in the project. Number · name · what it does.

---

## Scripts

1 game_state.gd
2 gravity_body.gd
3 gravity_demo_world.gd
4 gravity_well.gd
5 landing_demo.gd
6 location.gd
7 physics_body.gd
8 platform_ship.gd
9 player_body.gd
10 rippable_door.gd
11 ship_controller.gd
12 space_port.gd
13 space_world.gd
14 planet_lod.gd
15 procedural_being.gd
16 being_blueprints.gd

## Descriptions

1 game_state.gd — Autoload singleton. Persistent save/load (user://frontier_save.json). Game clock (1 real-sec = 60 game-min), dawn/dusk/day signals, event scheduler. Holds: credits, woolongs, cargo, registered_aliens, ship_position, ship_basis, game_minutes, game_day. Methods: save_game(), load_game(), snapshot_ship(ship), get_time_string(), schedule_event(day, min, name), pause_clock(), resume_clock().

2 gravity_body.gd — RigidBody3D that responds to GravityWells. Cargo crates, barrels, loose objects. Accumulates gravity each physics frame via apply_central_force. Registers itself via Area3D signals from nearby GravityWells. Fields: density, shape_radius (mass auto-computed). Methods: add_well(w), remove_well(w).

3 gravity_demo_world.gd — Scene root for gravity_demo.tscn. Standalone multi-gravity sandbox: small planetoid (r=60m), station above north pole, platform ship parked on surface, cargo crate inside station. Builds everything in code. Player spawns on planetoid, can walk around the full surface, enter station, board ship. G near ship → change_scene_to_file(main.tscn).

4 gravity_well.gd — Area3D gravity source. Any structure with mass gets one. Inverse-square law: accel_at(pos) returns acceleration vector toward well center. Auto-registers/deregisters bodies via body_entered/body_exited signals. Fields (exported or override after add_child): density, radius, influence_scale, grav_param, influence_radius. G_SCALED = 0.000004 (tuned for Earth-like g at r=60m, density=3000).

5 landing_demo.gd — Scene root for landing_demo.tscn. Proof-of-concept standalone landing scene: flat rocky disc (r=80m), single gravity well (g≈9.8 m/s²), astronaut spawns standing, ship silhouette 28m away with "[ G ] board" label. G within 15m → save + change_scene_to_file(main.tscn). HUD shows ship distance and credits.

6 location.gd — Pure data node. Dockable body: loc_name (string), loc_type ("PLANET"/"STATION"/"SHIPYARD"), dock_radius (float), market (Dictionary: {good: {buy, sell, qty}}). No logic. SpaceWorld creates 3 of these and passes them to ShipController via set_meta.

7 physics_body.gd — Orphaned base class (RigidBody3D). Defines add_well/remove_well interface. Not currently used; GravityBody and PlayerBody implement their own. Kept for reference.

8 platform_ship.gd — A landed ship structure: deck, hab modules, command tower, engine bells, rippable doors, own gravity well (g≈10 m/s² at deck level). Used in GravityDemoWorld parked at an angle on the planetoid surface. Its strong well overrides the planet's pull direction at deck level so the player stands on the deck naturally.

9 player_body.gd — CharacterBody3D on-foot controller. Multi-gravity: accumulates all active GravityWell accelerations, slerps body orientation to gravity up each frame (never gate this to is_on_floor — freezes yaw when airborne). First-person camera with mouse look (yaw=body rotate, pitch=camera tilt). Walk, jump, jetpack hover (capped so you can't escape a planet). Grab/throw GravityBody objects (F key, raycast). Charge rippable doors (hold F near door). G key → call parent.try_enter_ship(self). Methods: add_well(w), remove_well(w).

10 rippable_door.gd — Node3D door panel. Hold F to build charge 0→1. Shakes and glows red as charge builds. At full charge: rips off as a GravityBody physics object, flies outward with tumble velocity. Signal: ripped. Fields: size (Vector3), color (Color). Method: add_charge(delta) — called by player while F held.

11 ship_controller.gd — The entire flight game in one script. Flight model (Newtonian momentum + flight-assist damping), boost, strafe, roll. Alien scanning (R key, 500m range, woolong rewards). Market trading (1-9 buy, SHIFT+1-9 sell). Docking/undocking (L key near location). Full HUD (speed bar, throttle, waypoint marker, cargo, scan message, dock hint). External/cockpit camera toggle (V). G key when docked → request_exit_ship on parent (works for PLANET and STATION). On dock: syncs credits/cargo/woolongs/registered_aliens to GameState and calls save_game(). On spawn: loads credits/cargo/woolongs/registered from GameState. Restores ship at GameState.ship_position if save exists.

12 space_port.gd — BooBies Station interior (Space Dandy aesthetic: hot pink neons, cyan accents, dark walls). Three vendor booths along one wall, alien registration desk on other wall, departure bay at far end. Constant floor gravity (well 1 km below, g≈9.8 m/s²). Walk near booth → HUD shows price, F=buy, SHIFT+F=sell. G at launch pad → save to GameState → change_scene_to_file(main.tscn). Reads/writes GameState.credits, .cargo, .woolongs on entry and exit.

13 space_world.gd — Main space scene. Builds: purple environment + glow, 6000 stars (MultiMesh), sun, Planet Betelgeuse (teal, r=420m, PlanetLOD), Planet X (purple gas giant, r=680m, PlanetLOD + rings), BooBies Station (neon diner disc, spinning ring, r=120m), 5 alien ships (cat/flora/mech/gogol/rare), 3 Location nodes with markets, player ship (ShipController), 2 planet gravity wells. Ship spawns at GameState.ship_position if save exists, otherwise in front of BooBies. G key when docked at STATION → spaceport interior (change_scene_to_file). G key when docked at PLANET → spawn PlayerBody on planet surface. G key when on-foot near ship → try_enter_ship → deletes player, enables ship cameras, saves. _build_planet_rings() adds tilted cylinder ring at Planet X position.

14 planet_lod.gd — Distance-based LOD for planets. class_name PlanetLOD extends Node3D. Four levels: LOD0 (d>12000m) emissive dot grain of sand, emission_energy=8; LOD1 (3000-12000m) simple sphere 12 segs; LOD2 (800-3000m) rough sphere 32 segs + transparent ocean overlay sphere; LOD3 (<800m) 8×8 chunk terrain grid at +Y pole — each chunk is BoxMesh terrain tile + StaticBody3D collision + 8-20 grain spheres (r=0.3-0.8m) + optional rock (r=2-6m, 35% chance). Atmosphere halo (cull_front sphere at radius×1.08, visible within 6× radius). Label3D name billboard. set_observer(node) — LOD updates each _process based on observer distance.

15 procedural_being.gd — Blueprint-driven 3D being/mech/vehicle builder. class_name ProceduralBeing extends Node3D. Part types: bone (CapsuleMesh limb), joint (SphereMesh connector), panel (BoxMesh armour), edge (CylinderMesh wire between two points), eye (emissive sphere), thruster (engine bell with inner glow). Static factory: ProceduralBeing.build(blueprint) → Node3D. Subclass and override _get_blueprint() for named creatures. Blueprint format: { "parts": [{type, color, pos, rot, ...}] }.

16 being_blueprints.gd — Ready-made blueprint dicts for ProceduralBeing. class_name BeingBlueprints. Three presets: humanoid_alien(color) → biped with spine/arms/legs/eyes; mecha(color) → armour plate biped with shoulder thrusters; scout_ship(color) → saucer hull with cockpit bubble, two engine bells, wing edges, nav lights. All return Dictionary. Usage: ProceduralBeing.build(BeingBlueprints.mecha()).

---

## Scenes

1 main.tscn — space_world.gd root. The full space game. Startup scene.
2 gravity_demo.tscn — gravity_demo_world.gd root. Multi-gravity sandbox.
3 landing_demo.tscn — landing_demo.gd root. Standalone on-foot landing test.
4 demo_spaceport.tscn — space_port.gd root. BooBies interior.

---

## What Must Work (test checklist)

- [ ] Ship spawns in space (main.tscn)
- [ ] Flight: WASD throttle, QE roll, AD strafe, SHIFT/CTRL up/down
- [ ] Boost: SPACE, 4.5s duration, 11s cooldown
- [ ] T: cycle targets, waypoint marker tracks them
- [ ] V: toggle cockpit/external camera
- [ ] TAB: toggle flight assist
- [ ] R near alien (500m): scan, earn woolongs, register
- [ ] L near location: dock, market panel shows
- [ ] 1-9 buy, SHIFT+1-9 sell goods
- [ ] G when docked at PLANET: spawn on surface, walk around
- [ ] G when docked at STATION (BooBies): enter SpacePort interior
- [ ] SpacePort: walk, gravity floor, 3 booths, buy/sell with F
- [ ] SpacePort: G at launch pad → back to main.tscn, ship at saved position
- [ ] Credits/cargo/woolongs persist across scene changes
- [ ] gravity_demo.tscn: walk planetoid, station, platform ship
- [ ] gravity_demo: G near platform ship → back to main.tscn
- [ ] landing_demo.tscn: walk, jetpack, G near ship → main.tscn
