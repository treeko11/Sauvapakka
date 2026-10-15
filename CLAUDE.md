# Sauvapakka

Godot 4.7 project: a deterministic wand-duel simulation and a playable run with placeholder
art for a wand building card game. See README.md for the layout and the rule interpretations.

## Commands

`godot` is the Godot 4.7 console executable.

```bash
godot --headless --path . --import                                   # after cloning or adding a class_name
godot --headless --path . --script res://tests/test_rules.gd         # rule tests
godot --headless --path . --script res://tests/test_run.gd           # run, rewards, save file
godot --headless --path . --script res://tests/test_ui.gd            # screen smoke tests
godot --headless --path . --export-release "Web" build/web/index.html
godot --headless --path . --script res://tools/run_duel.gd -- burn turtle --trace
godot --headless --path . --script res://tools/run_duel.gd -- --matrix --seeds 3
```

Runner flags: `--seed N`, `--boss`, `--dps`, `--matrix`, `--seeds N`, `--trace`.

## Conventions

- Run the rule tests after any change to `sim/`; run all three suites after changes to `game/` or `ui/`.
- Every push to `main` deploys the web build to https://treeko11.github.io/Sauvapakka/ (`.github/workflows/pages.yml`).
- Spells, frames and builds are `.tres` Resources under `data/`; add content there, not in code.
- Keep the simulation deterministic: any randomness goes through the seeded RNG.
- When a change settles a rule the scope left open, update the rules list in README.md.
- Commit and push straight to `main`; no branches or PRs unless asked.
