# FRONTIER — Controls
_Last updated: 2026-03-27_

---

## Space Flight  (main.tscn / ship_controller.gd)

| Key | What it does |
|-----|-------------|
| **W** | Throttle up |
| **S** | Throttle down / reverse |
| **A / D** | Strafe left / right |
| **SHIFT / CTRL** | Strafe up / down |
| **Q / E** | Roll left / right |
| **Mouse** | Pitch + yaw (mouse captured) |
| **SPACE** | Boost (4.5s burn, 11s cooldown) |
| **TAB** | Toggle Flight Assist (FA ON = auto-damp velocity) |
| **V** | Toggle cockpit / external camera |
| **T** | Cycle targets (BooBies → alien signals) |
| **R** | Scan nearest alien (500m range) — stores to pending_aliens, no woolongs yet |
| **L** | Dock when near location / Depart when docked |
| **G** | Exit ship on foot — works at PLANET (surface walk) and STATION (SpacePort interior) |
| **ESC** | Quit |

## Docked at market

| Key | What it does |
|-----|-------------|
| **1–9** | Buy one unit of that good |
| **Shift + 1–9** | Sell one unit |
| **G** | Exit ship on foot |
| **L** | Depart (undock) |

---

## SpacePort — BooBies Interior  (demo_spaceport.tscn / space_port.gd)

| Key | What it does |
|-----|-------------|
| **W / A / S / D** | Walk |
| **Mouse** | Look |
| **SPACE** | Jetpack hover |
| **F** (near booth counter) | Buy one unit |
| **Shift + F** (near booth) | Sell one unit |
| **F** (near CLERK desk) | Collect pending alien bounties → woolongs |
| **G** (near launch pad) | Launch → back to main.tscn |

---

## On Foot — Planet Surface  (player_body.gd)

| Key | What it does |
|-----|-------------|
| **W / A / S / D** | Walk |
| **Mouse** | Look (captured) |
| **SPACE** | Jump / jetpack hover |
| **F** | Pick up / throw GravityBody objects |
| **E** | Interact (charge rippable doors) |
| **G** (within 22m of ship) | Board ship |
| **ESC** | Quit |

---

## Notes

- **Flight Assist ON**: auto-brakes on all axes. Good for precision docking.
- **Flight Assist OFF**: pure Newtonian. Velocity never damps.
- **Boost**: ×3 max speed. Timer shown in HUD.
- **Scan**: R within 500m → alien added to pending_aliens. Fly to BooBies, walk to CLERK desk, F to collect woolongs.
- **Dock ranges**: BooBies 250m · Betelgeuse 550m · Planet X 800m
- **Gravity**: multi-well system. You can be under two wells simultaneously (planet + ship).
- **PlanetLOD observer**: switches from ship to player automatically when you exit on foot.
