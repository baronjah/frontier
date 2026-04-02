# FRONTIER — Vision & Design Notes

Raw brain dumps. These are goals, not current state.

---

## Physics

The game needs a real physics layer underneath everything:
- Gasses, liquids, masses — chunks with pressure values
- Voids as data: where nothing is, pressure differs
- Movement of ships through atmosphere = pressure simulation
- Bends and twists in structure affect stress / breaks
- Room pressure, exchanges, stabilization between chambers
- Gravity as a field, not a flag — everything is a well

Goal: build the physics engine yourself, for movement, shape changes, and the chunk system.

## Layers of Simulation

Ships are 2D layers of simulation and emulation stacked:
- Points of cuts where impact happens
- Calculate movement in physics (gasses, liquids, rooms)
- When bridges break → understand where cuts happen
- Bends, twists, all elements of the whole structure
- Each layer evolves to the next possible step

## Ship Modes

Same ship = piloting, landing, hovering, walking interior:
- Auto-landing mode (ship handles approach + touchdown)
- Hovering over planet (partial gravity, attitude hold)
- Cargo bay big enough for a mecha, few rooms, possibly too big
- Ships have their own gravity bends and field shapes

## Camera Modes

- 1st person
- 3rd person (follows)
- Freecam
- Gravity-locked (ground is always down, Q/E = horizontal rotation)
- Piloting cam, walking cam, flying cam — all seamless transitions

## Scale

- Planet big enough to walk on properly (current test: r=420m, too small)
- Ship on landing pad is same ship you fly
- Cargo visible in world as actual crates, not just inventory numbers

## 0x10c Inspiration (see 0x10c.txt)

- Hard science fiction tone
- Engineering as gameplay (fix things, build things)
- Space→planet transition seamless
- Economy that persists
- "Extremely nerdy" space trading simulator
- C418 ambient music feeling (sparse, cold, beautiful)
- Universe where everyone else has been asleep for 281 trillion years

## Current Gap

What Frontier has → what it needs:
- Trade ✓ → Trade goods that exist physically in world
- Scan aliens ✓ → Aliens that react, flee, or attack
- Land on planet ✓ → Land with same ship, not teleport
- Walk surface ✓ → Surface has geology, resources to mine
- BooBies interior ✓ → More interiors (shipyard, living quarters)
- Woolongs ✓ → Spend them on something real (upgrades)
