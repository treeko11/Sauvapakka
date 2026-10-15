class_name FrameGen
extends RefCounted
## Standard frames: stats only, from three materials, improving with depth.

const MATERIALS := {
	"birch": {"name": "Birch Wand", "capacity": 5, "cast_delay": 0.25, "recharge_time": 0.6, "mana_max": 100.0, "mana_regen": 30.0},
	"pine": {"name": "Pine Wand", "capacity": 4, "cast_delay": 0.18, "recharge_time": 0.45, "mana_max": 80.0, "mana_regen": 32.0},
	"oak": {"name": "Oak Staff", "capacity": 7, "cast_delay": 0.32, "recharge_time": 0.85, "mana_max": 140.0, "mana_regen": 30.0},
}


static func standard(rng: RandomNumberGenerator, depth: int, material := "") -> FrameDef:
	if material == "":
		material = MATERIALS.keys()[rng.randi_range(0, MATERIALS.size() - 1)]
	var m: Dictionary = MATERIALS[material]
	var f := FrameDef.new()
	var q := 0.04 * depth + rng.randf_range(0.0, 0.08)
	f.id = StringName("%s_%d" % [material, rng.randi()])
	f.display_name = ("Fine " if q >= 0.2 else "") + m["name"]
	f.capacity = m["capacity"] + (1 if rng.randf() < 0.1 * depth else 0)
	f.cast_delay = snappedf(m["cast_delay"] * (1.0 - q), 0.01)
	f.recharge_time = snappedf(m["recharge_time"] * (1.0 - q), 0.01)
	f.mana_max = roundf(m["mana_max"] * (1.0 + q))
	f.mana_regen = roundf(m["mana_regen"] * (1.0 + q))
	f.shuffle = material == "birch" and rng.randf() < 0.3
	if depth >= 3 and rng.randf() < 0.15:
		f.spells_per_cast = 2
		f.cast_delay = snappedf(f.cast_delay * 1.3, 0.01)
		f.recharge_time = snappedf(f.recharge_time * 1.4, 0.01)
	return f


## One line of stats for cards and tooltips.
static func describe(f: FrameDef) -> String:
	var parts := PackedStringArray([
		"%d slots" % f.capacity,
		"cast %.2fs" % f.cast_delay,
		"recharge %.2fs" % f.recharge_time,
		"mana %d (+%d/s)" % [roundi(f.mana_max), roundi(f.mana_regen)],
	])
	if f.spells_per_cast > 1:
		parts.insert(1, "%d per cast" % f.spells_per_cast)
	if f.shuffle:
		parts.append("shuffles")
	return ", ".join(parts)
