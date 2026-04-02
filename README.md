# FRONTIER
_Last updated: 2026-03-27_

Space game. Godot 4.7. Everything built in code — no hand-made scenes.

## What works right now
- Fly, boost, roll, flight assist (W/S/Q/E/A/D + SHIFT/CTRL)
- R = scan alien within 500m → stores to pending_aliens (no woolongs yet)
- L = dock at BooBies or planets → market panel opens
- F/number keys = buy/sell goods while docked
- G = exit ship onto planet surface / SpacePort interior
- On-foot: WASD walk, SPACE jetpack, multi-gravity (any surface orientation)
- SpacePort (BooBies): neon diner, 3 booths, 4 alien NPCs (2 humanoid, 2 orb)
- **CLERK desk** in SpacePort: walk to it → F = collect pending alien bounties → woolongs
- Credits, cargo, woolongs, registered/pending aliens all persist (GameState autoload, save on dock)
- PlanetLOD: 4 detail levels, switches observer between ship/player foot
- landing_demo.tscn: flat planet test scene, gravity, ship marker

## Core loop (complete in code, not yet tested in Godot)
fly → R scan alien → dock BooBies → G exit ship → walk to CLERK desk → F register → woolongs credited → G launch → fly

## Scripts (16)
```
game_state.gd          autoload: save/load, clock, scheduler, pending_aliens
space_world.gd         main world: stars, planets, station, aliens, ship
ship_controller.gd     flight + HUD + scan + market
space_port.gd          BooBies interior: booths, NPCs, clerk registration
player_body.gd         on-foot: gravity, jetpack, EVA suit mesh
planet_lod.gd          4-level LOD: dot→sphere→rough→chunk grid
gravity_well.gd        Area3D: inverse-square gravity provider
gravity_body.gd        RigidBody3D: responds to wells
gravity_demo_world.gd  sandbox test scene
landing_demo.gd        flat planet test (G → main.tscn)
platform_ship.gd       landed ship with own gravity well
rippable_door.gd       charge-and-rip door
location.gd            data node: name, type, dock_radius, market
procedural_being.gd    blueprint-driven 3D being/mech/vehicle builder
being_blueprints.gd    presets: humanoid_alien, mecha, scout_ship
```

## Scenes
```
main.tscn              → space_world.gd
demo_spaceport.tscn    → space_port.gd
gravity_demo.tscn      → gravity_demo_world.gd
landing_demo.tscn      → landing_demo.gd
```

## Next
- [ ] Actually RUN it — confirm alien scan → CLERK → woolongs works
- [ ] Shipyard: spend woolongs on upgrades
- [ ] ProceduralBeing: test spawn in scene, confirm humanoid_alien appears
- [ ] Galaxy seed + sector connect to galaxies project

## Bugs fixed (don't reintroduce)
- Black screen on exit ship → `_cam.make_current()` in player_body._ready()
- G key only at PLANET → removed loc_type check in ship_controller
- Economy resets on restart → GameState autoload + save on dock
- PlanetLOD stuck on ship → `_set_planet_observer()` switches on exit/reboard
- Scan gave woolongs immediately → deferred to CLERK desk via pending_aliens
