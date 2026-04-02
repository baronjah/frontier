# frontier — therapy notes

## what it was supposed to be

Elite: Frontier with Space Dandy soul.
You fly. You find things. You trade. You register aliens at a neon diner.
Small, absurd, alive.

## what it actually is

A working game loop.
Ship flies with gravity wells. You scan aliens. You dock at BooBies (a space diner).
You walk out of your ship on a planet. The SpacePort has NPCs that patrol.
Woolongs are a currency. Credits are a different currency. That's intentional.

The procedural being builder exists and can make humanoids, mechas, scout ships from blueprints.
It does not yet spawn anything in the main game.

## what's in reverse

The game was supposed to grow outward from the ship.
Instead, it grew inward — the ship works perfectly, the world around it is thin.

Planet LOD exists but planets have no real content yet.
The shipyard code exists but is not wired to any scene.
The galaxy seed idea exists as one line in a TODO comment.

Mechas were supposed to be the endgame — you earn enough, you build a robot companion.
Right now they're blueprints that produce meshes in a demo scene.

## what hurts

The HUD color refactor was cut off mid-session.
PINK constants still in some places. H key not wired.
It's like a sentence that ends in the middle of

## what to fix first (on feature/hud-hue-refactor)

1. `_update_hue_colors()` exists in ship_controller.gd — call it on ready and on H key
2. Replace remaining PINK references with MAIN/MAIN_DIM/MAIN_BRIGHT
3. Add `_credits` + `_woolongs` both visible in HUD at once

## the real direction

The game is Space Dandy's universe engine.
Every planet has a feel. Every station has a personality.
You don't follow a map — you follow signals.

Aliens are registered like taxi fares. The diner is the hub.
The mecha is what you build when you've seen everything.

## branch plan

- `feature/hud-hue-refactor` — finish H key, color system, dual currency HUD
- `feature/shipyard` — BooBies upgrade panel, engine/scanner/cargo
- `feature/galaxy-seed` — connect to `D:\galaxies\` procedural universe gen
