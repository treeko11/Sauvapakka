# Sauvapakka

Godot 4.7 project: a headless, deterministic wand-duel simulation for a wand building
card game. No rendering yet. See README.md for the layout and the rule interpretations.

## Commands

`godot` is the Godot 4.7 console executable.

```bash
godot --headless --path . --import                                   # after cloning or adding a class_name
godot --headless --path . --script res://tests/test_rules.gd         # rule tests
godot --headless --path . --script res://tools/run_duel.gd -- burn turtle --trace
godot --headless --path . --script res://tools/run_duel.gd -- --matrix --seeds 3
```

Runner flags: `--seed N`, `--boss`, `--dps`, `--matrix`, `--seeds N`, `--trace`.

## Conventions

- Run the rule tests after any change to `sim/`.
- Spells, frames and builds are `.tres` Resources under `data/`; add content there, not in code.
- Keep the simulation deterministic: any randomness goes through the seeded RNG.
- When a change settles a rule the scope left open, update the rules list in README.md.
- Commit and push straight to `main`; no branches or PRs unless asked.
