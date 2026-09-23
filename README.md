# Traveler

Open `project.godot` in Godot 4 and press **F5**. The scene displays only the world and player, without a HUD.

## Controls

- **W / A / S / D**: move exactly one 10-pixel tile per press. Holding a key does not repeat; additional moves during a step are ignored.
- **F**: burn the tile beneath the stationary player. The supplied eight-frame fire sheet plays once, then the tile becomes grayscale.
- **X**: regenerate all unburned terrain without moving the player.
- **R**: reconstruct the current seed, preserving burned terrain.

The world is **5000 × 5000 pixels**, or **500 × 500 cells**. The camera follows the player and stops at the world edges. All terrain is walkable so every cell can be reached and burned; the world boundary blocks movement. The existing Godot icon remains the placeholder player sprite.

Burning captures the cell's terrain, decoration, and detail before the animation starts. Its position and grayscale appearance survive every subsequent regeneration, including regeneration during the fire animation. Burning an already burned cell does nothing. Once every cell is burned, regeneration does nothing. Burned cells persist for the current play session; stopping/restarting the scene resets them.

## Structure

- `Src/main.tscn`: world, `Player Node`, sprite, and following camera.
- `Src/player.gd`: grid movement, step tween, and F interaction. **Step Duration** is adjustable in the Inspector.
- `Src/map_generator.gd`: world seed, visible-cell rendering, bounded region cache, immutable burned snapshots, and fire playback.
- `Src/region_generator.gd`: repeatable local woodland, ruin, river, bridge, and trail generation using the original 10 × 10 atlas. Regions generate on demand; only the visible cells are drawn. Independent regions may have different terrain at their boundaries.

**Starting Seed** on the world root reproduces a world; zero chooses a time-based seed. **Layout Variation** (0–1) controls large-scale differences between regions and seeds. Atlas coordinates are zero-based `(column, row)` in `Full-no-bg.png`. The original source images remain unchanged.

## Validation

With Godot on your PATH:

```sh
godot --headless --path . --script res://Tests/test_generation.gd
godot --headless --path . --script res://Tests/test_world.gd
```

The region suite checks 200 seeds for bounds, local trail connectivity, decoration clearance, deterministic replay, and variation. The world suite checks single-step movement, input repeat, boundaries, burning, fire completion, snapshot persistence during regeneration, unburned changes, bounded region caching, and the fully burned no-op.
