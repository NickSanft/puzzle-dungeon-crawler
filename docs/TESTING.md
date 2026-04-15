# Testing

A lightweight headless test harness lives in [`tests/`](../tests). No external framework — just GDScript with a small `TestFramework` helper.

## Running locally

From the project root:

```bash
godot --headless res://tests/test_runner.tscn
```

The scene runs every suite in `_ready()`, prints `OK`/`FAIL` per assertion, then calls `get_tree().quit()` with exit code `0` on success and `1` on any failure.

## In CI

The `Run unit tests` step in [`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml) executes the same command. A non-zero exit code fails the job and prevents the web deploy.

## What's covered

- `RNG` — seeded determinism, date-key format
- `NonogramPuzzle` — clue derivation for both B&W and color grids
- `NonogramSolver` — counts solutions, recognises unique boards
- `NonogramGenerator` — shape and clue self-consistency for random + color
- `SaveSystem` — glimbo add/spend, unlock dedup, daily best-score rules
- `UnlockTree` — prerequisite gating
- `BossPatterns` — hand-authored grids are 10x10

## Writing new tests

Add a new `_test_*(t)` method in [`tests/test_runner.gd`](../tests/test_runner.gd) and call it from `_ready()`. Use `t.assert_eq / assert_true / assert_false`. Call `SaveSystem.reset_for_test("user://test_save.json")` at the start of any suite that touches save state so tests don't pollute the real save.
