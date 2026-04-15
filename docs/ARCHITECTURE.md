# Architecture

## Folder layout

```
scenes/
  dungeon/   Map, rooms, tile-based overworld
  puzzles/   Nonogram + variant scenes
  ui/        HUD, meta menu, shop, title
  entities/  Player, NPCs (e.g. Glimbo shopkeeper)

scripts/
  core/      GameState, RunManager, RNG, SaveSystem (autoloads)
  puzzles/   NonogramGenerator, NonogramSolver, ColorNonogram
  meta/      GlimboEconomy, UnlockTree, DailySeed

assets/
  sprites/   Art (tiles, characters, icons)
  fonts/     UI + display fonts
  sfx/       Audio

docs/        Design notes (this folder)
```

## Autoloads (planned)

| Name        | Script                          | Purpose |
|-------------|---------------------------------|---------|
| GameState   | scripts/core/game_state.gd      | Current run state, HP, inventory |
| SaveSystem  | scripts/core/save_system.gd     | Persist Glimbos + unlocks to `user://save.json` |
| RNG         | scripts/core/rng.gd             | Seeded RNG wrapper for reproducibility |
| RunManager  | scripts/core/run_manager.gd     | Room sequencing, transitions |

## Data flow

1. `RunManager` asks `RNG` for a room → generates dungeon layout
2. On entering a puzzle room, `NonogramGenerator` uses `RNG` to produce a puzzle
3. On solve/fail, `GameState` applies HP + Glimbo reward, `SaveSystem` persists Glimbos
4. Between floors, the **Glimbo shop** reads from `UnlockTree` to offer options

## Web export notes

Godot 4 web export requires SharedArrayBuffer (COOP/COEP headers). GitHub Pages does not set these. Workaround: ship `coi-serviceworker` in the export folder.
