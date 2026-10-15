# Sauvapakka — headless simulation prototype
nThe wand building card game.

Godot 4.7 project containing the deterministic wand-duel simulation and the first
25 spells as data. There is no rendering yet: duels run on fixed ticks and write an
event log that a duel screen can replay later.

## Layout

| Path | What it is |
| --- | --- |
| `sim/spell_def.gd` | `SpellDef` Resource. One export group per effect primitive |
| `sim/frame_def.gd` | `FrameDef` Resource: frame stats and special rule |
| `sim/wand_build.gd` | `WandBuild` Resource: a frame plus spell ids per slot |
| `sim/duel.gd` | The simulation: casting, hits, statuses, escalation, event log |
| `sim/shot.gd`, `caster.gd`, `wand_state.gd` | Runtime state used by the duel |
| `sim/spell_db.gd` | Loads every spell in `data/spells` by id |
| `sim/duel_trace.gd` | Formats events as text |
| `data/spells/` | The 25 starter spells |
| `data/frames/` | The six named frames |
| `data/builds/` | Sample builds, one or more per archetype |
| `tools/run_duel.gd` | Headless runner |
| `tests/test_rules.gd` | Rule tests |

## Running

The commands assume `godot` is the Godot 4.7 console executable. Import once after cloning, or after adding a `class_name`:

```bash
godot --headless --path . --import
```

```bash
godot --headless --path . --script res://tests/test_rules.gd
```

```bash
godot --headless --path . --script res://tools/run_duel.gd -- burn turtle --trace
```

```bash
godot --headless --path . --script res://tools/run_duel.gd -- --matrix --seeds 3
```

The runner also takes `--seed N` and `--boss` (a 60-second fight). `--dps` runs each build against an empty wand with bottomless HP and no escalation, and reports raw damage output and mana starvation.

Matrix cells show the win rate, then the row build's HP% minus the column build's HP% at the end. Duels are deterministic apart from shuffled frames, so the margin shows a close matchup better than the win rate does.

## Rules the scope left open (current interpretation)

- **Multicast:** replaces itself with N projectiles. Its `damage_mult` and `copies` apply to each projectile it draws.
- **Leftover modifiers:** modifiers left over at the end of a cast fizzle.
- **Utility spells:** Mana Spring and Recharge Plus draw a replacement, like modifiers. Ward and Reflect Ward use up one of the cast's spells-per-cast.
- **Wrapping:** a cast wraps past the last slot at most once. A wand also stops drawing after 64 draws per cast, and payloads nest at most 4 deep.
- **Recharge:** the wand waits for the longer of its cast delay and its recharge time.
- **Triggers:** the payload fires on first contact, whether the projectile hits, is blocked by a Ward, or is reflected. A reflected projectile bounces back without its payload, and can bounce at most 4 times.
- **Piercing:** each point of pierce ignores one Ward or Reflect Ward.
- **Arc's chain:** an extra hit at half damage that applies no statuses, so it consumes the Shock Arc just applied.
- **Status order on a hit:** Wet, then Burn, then Chill, then Shock. One projectile can't freeze a target and steam it.
- **Wet:** applying Wet to a burning target removes the Burn and uses up the Wet. Shock bonus damage doubles on a Wet target and uses up the Wet.
- **Burn cap:** a target holds at most 4 Burn stacks. Burn only loses one stack per tick, so without a cap the stacks grew without limit.
- **Ember Staff:** adds +1 Burn stack to every Burn it applies.
- **Freeze:** a frozen caster skips its next cast and waits at least 0.7 s before the one after.
- **Glacier Wand:** its Chill stops decaying until the target freezes.
- **Escalation:** damage amplification starts halfway through the fight and reaches ×3 at the fight length (30 s, or 60 s for the boss). If nobody has died by twice the fight length, the higher HP fraction wins.

The tuning numbers are constants at the top of `sim/duel.gd`, caster HP (250) in `sim/caster.gd`, and fields on the `.tres` files.
