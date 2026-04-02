# FRONTIER — Session Notes 2026-03-31
# What Claude Code was doing, what's done, what's broken, what's next.

## WHAT HAPPENED IN THE LAST SESSION

Claude Code ran for ~14m on frontier. Six tasks completed before rate limit cut it off:

1. **ship_controller.gd**: added add_well / remove_well / _accumulate_gravity / disable_cameras / enable_cameras
2. **space_world.gd**: added planet StaticBody3D collision, GravityWell nodes for both planets, request_exit_ship / try_enter_ship
3. **player_body.gd**: _cam.far = 200000.0, clampf fix, G key to board ship
4. **HUD scan hint**: "[R] SCAN ALIEN SIGNAL" when unregistered alien within 500m
5. **Key fix**: E→G for exit/board. E = interact on foot. Q/E = barrel rolls in flight. G = board/exit ALWAYS.
6. **HUD color refactor**: PINK consts → hue-driven vars (MAIN, MAIN_DIM, MAIN_BRIGHT + _hue_h float). CUT OFF HERE.

## OPEN BUG: Camera black screen on exit ship

**Symptom**: After G (exit ship), player spawns on foot but camera may be black.
**Root cause**: `_cam.make_current()` must be called AFTER the player Camera3D node enters the scene tree.
**Location**: space_world.gd → request_exit_ship() — camera is added but make_current() may not fire.
**Fix**: After `add_child(player)`, call `player.get_node("Camera3D").make_current()` OR defer it one frame.
**From ARCHITECTURE.md**: "_cam.make_current() must be called after player camera added — or black screen on exit"

## OPEN: HUD color refactor incomplete

Session cut off mid-task. `_hue_h` and MAIN/MAIN_DIM/MAIN_BRIGHT vars are added but:
- H key handler not yet wired to update the 3 color vars from hue
- Existing PINK references in the HUD build functions not yet replaced with MAIN

**Pattern to apply**:
```gdscript
func _update_hue_colors() -> void:
    MAIN       = Color.from_hsv(_hue_h / 360.0, 0.90, 1.00)
    MAIN_DIM   = Color.from_hsv(_hue_h / 360.0, 0.90, 0.40)
    MAIN_BRIGHT = Color.from_hsv(_hue_h / 360.0, 0.50, 1.00)
```
Call on init and whenever H pressed.

## CONTROLS (final, locked)

| Key | Context | Action |
|-----|---------|--------|
| Q/E | Flight | Barrel roll — NEVER reassign |
| G | Flight/Foot | Board / exit ship |
| L | Flight/Docked | Dock / depart |
| R | Flight | Scan alien (500m) |
| T | Flight | Cycle targets |
| V | Flight | Toggle cockpit/external camera |
| E | On foot | Interact (rippable doors) |
| F | On foot | Grab/throw / buy at booth |
| SPACE | On foot | Jump / jetpack hover |

## MONEY

Two separate currencies — keep both, display together:
- `_credits` = trade currency (buy/sell cargo at market)
- `_woolongs` = alien bounty (scan alien → dock at BooBies → CLERK desk → collect)

Both should show in HUD. Do not merge into one var.

## NEXT STEPS

1. Fix camera black screen: add `_cam.make_current()` call in request_exit_ship after player added
2. Complete H-key hue slider: wire KEY_H in _unhandled_key_input, call _update_hue_colors()
3. Replace remaining PINK refs in HUD build functions with MAIN/MAIN_DIM/MAIN_BRIGHT
4. Shipyard panel at BooBies (upgrade Engine, Scanner, Cargo)
