extends SceneTree
## Coordinate-descent search over spell and frame numbers, scored against the
## balance gate (sample builds win 30-70%, fights 25-35 s). Changes live only in
## memory; copy the printed values into the .tres files you agree with.
##   godot --headless --script res://tools/tune.gd -- --seeds 6 --passes 2
## With --enemy-hp, instead fits each enemy archetype's HP so the sample builds
## win at the rate TARGET_BY_DEPTH sets for the depths it appears at.

const BUILD_DIR := "res://data/builds"
## Starter is meant to be outgrown, so it only counts if it climbs above 50%.
const EXEMPT := ["starter"]

## Sample builds' target win rate against enemies at each depth (6 is the boss),
## so fights get harder relative to a fixed wand as the run goes on.
const TARGET_BY_DEPTH := [0.85, 0.75, 0.65, 0.55, 0.5, 0.45, 0.35]

## [resource path, property, candidate values]
var params := [
	["res://data/spells/ward.tres", "mana_cost", [16, 18, 20, 22, 24]],
	["res://data/spells/ward.tres", "cast_delay", [0.1, 0.15, 0.2, 0.25]],
	["res://data/spells/reflect_ward.tres", "mana_cost", [20, 24, 28]],
	["res://data/spells/ricochet_orb.tres", "damage", [3.0, 3.5, 4.0, 4.5]],
	["res://data/spells/magic_missile.tres", "damage", [13.0, 14.0, 15.0, 16.0]],
	["res://data/spells/flicker_trigger.tres", "mana_cost", [10, 12, 14]],
	["res://data/frames/twin_fork.tres", "cast_delay", [0.4, 0.45, 0.5]],
	["res://data/frames/twin_fork.tres", "recharge_time", [1.2, 1.4, 1.6]],
	["res://data/frames/leyline_rod.tres", "recharge_time", [1.6, 1.8, 2.0]],
	["res://data/frames/ouroboros.tres", "cast_delay", [0.15, 0.18, 0.21]],
	["res://data/frames/glacier_wand.tres", "cast_delay", [0.28, 0.3, 0.32]],
	["res://data/frames/apprentice_rod.tres", "cast_delay", [0.22, 0.25, 0.28]],
]

var db: SpellDB
var builds: Array[WandBuild] = []
var names := PackedStringArray()
var seeds := 6


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--seeds")
	if i >= 0:
		seeds = int(args[i + 1])
	var passes := 2
	i = args.find("--passes")
	if i >= 0:
		passes = int(args[i + 1])
	db = SpellDB.load_default()
	for f in DirAccess.get_files_at(BUILD_DIR):
		f = f.trim_suffix(".remap")
		if f.ends_with(".tres"):
			names.append(f.get_basename())
			builds.append(load(BUILD_DIR.path_join(f)))
	if "--enemy-hp" in args:
		_fit_enemy_hp()
		quit()
		return
	var best := _score()
	print("start: %s" % _report())
	for p in passes:
		for param in params:
			var res: Resource = load(param[0])
			var keep: Variant = res.get(param[1])
			for v in param[2]:
				res.set(param[1], v)
				var s := _score()
				if s < best - 1e-6:
					best = s
					keep = v
			res.set(param[1], keep)
		print("pass %d: score %.3f  %s" % [p + 1, best, _report()])
	print("\nValues:")
	for param in params:
		print("  %s %s = %s" % [param[0].get_file(), param[1], load(param[0]).get(param[1])])
	quit()


## Lower is better: builds outside the band, then spread from 50%, then length.
func _score() -> float:
	var r := _matrix()
	var s := 0.0
	for k in r["rates"]:
		var rate: float = r["rates"][k]
		if k in EXEMPT:
			s += 2.0 * maxf(0.0, rate - 0.5)
			continue
		if rate < 0.3 or rate > 0.7:
			s += 1.0
		s += 2.0 * (rate - 0.5) * (rate - 0.5)
	var len_s: float = r["length"]
	s += 0.2 * maxf(0.0, 26.0 - len_s) + 0.2 * maxf(0.0, len_s - 34.0)
	return s


func _matrix() -> Dictionary:
	var won := {}
	var total := 0.0
	var duels := 0
	for n in names:
		won[n] = 0.0
	for i in builds.size():
		for j in builds.size():
			if i == j:
				continue
			for s in seeds:
				var d := Duel.new(builds[i], builds[j], db, s)
				var w := d.run()
				total += d.seconds()
				duels += 1
				var score := 1.0 if w == 0 else (0.5 if w == Duel.DRAW else 0.0)
				won[names[i]] += score
				won[names[j]] += 1.0 - score
	var rates := {}
	for n in names:
		rates[n] = won[n] / (2.0 * seeds * (builds.size() - 1))
	return {"rates": rates, "length": total / duels}


func _report() -> String:
	var r := _matrix()
	var parts := PackedStringArray()
	for n in names:
		parts.append("%s %.0f%%" % [n.left(8), 100.0 * r["rates"][n]])
	return "%s | %.1fs" % [", ".join(parts), r["length"]]


func _fit_enemy_hp() -> void:
	var defs: Array[EnemyDef] = []
	for f in DirAccess.get_files_at(RunState.ENEMY_DIR):
		defs.append(load(RunState.ENEMY_DIR.path_join(f.trim_suffix(".remap"))))
	defs.append(load(RunState.BOSS_PATH))
	for def in defs:
		var depths := _depths_for(def)
		var target := 0.0
		for dpt in depths:
			target += TARGET_BY_DEPTH[dpt]
		target /= depths.size()
		var lo := 80.0
		var hi := 1200.0
		for it in 9:
			var mid := (lo + hi) * 0.5
			if _sample_rate(def, depths, mid) > target:
				lo = mid
			else:
				hi = mid
		var hp := snappedf((lo + hi) * 0.5, 10.0)
		print("%-14s depths %-10s target %3.0f%%  HP %4.0f -> %3.0f%%  (was %d)" % [def.id, str(depths), 100.0 * target, hp,
			100.0 * _sample_rate(def, depths, hp), roundi(def.max_hp)])


func _depths_for(def: EnemyDef) -> Array[int]:
	var out: Array[int] = []
	if def.fixed_build != null:
		out.append(RunState.FIGHT_PLAN.size())
		return out
	for dpt in RunState.FIGHT_PLAN.size():
		if (RunState.FIGHT_PLAN[dpt] == "themed") == def.themed and def.min_depth <= dpt and dpt <= def.max_depth:
			out.append(dpt)
	return out


func _sample_rate(def: EnemyDef, depths: Array[int], hp: float) -> float:
	var won := 0.0
	var n := 0
	var rng := RandomNumberGenerator.new()
	for dpt in depths:
		for s in seeds:
			rng.seed = hash([def.id, dpt, s])
			var enemy := EnemyGen.generate(def, dpt, rng, db)
			for b in builds:
				var d := Duel.new(b, enemy, db, s, def.fixed_build != null)
				d.casters[1].max_hp = hp
				d.casters[1].hp = hp
				var w := d.run()
				won += 1.0 if w == 0 else (0.5 if w == Duel.DRAW else 0.0)
				n += 1
	return won / n
