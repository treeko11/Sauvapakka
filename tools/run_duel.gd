extends SceneTree
## Headless duel runner. Build names are files in res://data/builds, without ".tres".
##
##   One duel with a full event trace:
##     godot --headless --script res://tools/run_duel.gd -- burn turtle --trace
##   Every build against every other, over several seeds:
##     godot --headless --script res://tools/run_duel.gd -- --matrix --seeds 5
##   Each themed archetype against its counter build and the sample builds:
##     godot --headless --script res://tools/run_duel.gd -- --archetypes --depth 3 --seeds 10
##   Each sample build against the Archmage:
##     godot --headless --script res://tools/run_duel.gd -- --archmage --seeds 5
##
## Other flags: --seed N, --boss (60-second fight).

const BUILD_DIR := "res://data/builds"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var db := SpellDB.load_default()
	var p_seed := int(_flag_value(args, "--seed", "0"))
	var boss := "--boss" in args
	if "--matrix" in args:
		_matrix(db, int(_flag_value(args, "--seeds", "3")), boss)
	elif "--archetypes" in args:
		_archetypes(db, int(_flag_value(args, "--depth", "3")), int(_flag_value(args, "--seeds", "10")))
	elif "--archmage" in args:
		_archmage(db, int(_flag_value(args, "--seeds", "5")))
	elif "--dps" in args:
		_dps(db, p_seed)
	else:
		var names := PackedStringArray()
		for a in args:
			if not a.begins_with("--") and not a.is_valid_int():
				names.append(a)
		if names.size() < 2:
			printerr("Usage: run_duel.gd -- <build_a> <build_b> [--trace] [--seed N] [--boss] | --matrix [--seeds N]")
			printerr("Builds: %s" % ", ".join(_build_names()))
			quit(1)
			return
		var d := Duel.new(_load_build(names[0]), _load_build(names[1]), db, p_seed, boss)
		d.run()
		if "--trace" in args:
			DuelTrace.print_duel(d)
		_print_result(d)
	quit()


func _matrix(db: SpellDB, seeds: int, boss: bool) -> void:
	var names := _build_names()
	var builds: Array[WandBuild] = []
	for n in names:
		builds.append(_load_build(n))
	var width := 15
	var header := "%-*s" % [width, "row wins vs"]
	for n in names:
		header += "%*s" % [width, n.left(width - 1)]
	print(header + "%*s" % [width, "matchups won"])
	var total_seconds := 0.0
	var duels := 0
	var timeouts := 0
	var stats: Array[Dictionary] = []
	for n in names:
		stats.append({"duels": 0, "seconds": 0.0, "won": 0.0, "taken": 0.0, "dealt": {"hit": 0.0, "burn": 0.0, "steam": 0.0}})
	for i in builds.size():
		var line := "%-*s" % [width, names[i].left(width - 1)]
		var won := 0.0
		for j in builds.size():
			if i == j:
				line += "%*s" % [width, "-"]
				continue
			var wins := 0.0
			# Row's HP% minus column's HP% at the end, so close matchups stand out.
			var margin := 0.0
			for s in seeds:
				var d := Duel.new(builds[i], builds[j], db, s, boss)
				var w := d.run()
				total_seconds += d.seconds()
				if d.seconds() >= d.hard_cap_seconds:
					timeouts += 1
				duels += 1
				if w == 0:
					wins += 1.0
				elif w == Duel.DRAW:
					wins += 0.5
				var c := d.casters
				margin += 100.0 * (maxf(0.0, c[0].hp) / c[0].max_hp - maxf(0.0, c[1].hp) / c[1].max_hp)
				_tally(d, stats[i], stats[j])
			won += wins / seeds
			stats[i]["won"] += wins
			stats[j]["won"] += seeds - wins
			line += "%*s" % [width, "%d%% %+d" % [roundi(100.0 * wins / seeds), roundi(margin / seeds)]]
		print(line + "%*s" % [width, "%.1f" % won])
	print("\n%d duels, average length %.1fs, %d decided by HP at the cap" % [duels, total_seconds / duels, timeouts])
	print("Cells: win rate, then row's HP% minus column's HP% at the end.\n")
	_print_build_stats(names, stats)


## Adds one duel to both builds' totals. Damage is credited to the side that
## didn't take it, so reflected hits count for the reflector.
func _tally(d: Duel, a: Dictionary, b: Dictionary) -> void:
	var sides: Array[Dictionary] = [a, b]
	for side in sides:
		side["duels"] += 1
		side["seconds"] += d.seconds()
	for e in d.events:
		if e["type"] != "damage":
			continue
		var cause: String = e["cause"]
		sides[e["who"]]["taken"] += e["amount"]
		sides[1 - e["who"]]["dealt"][cause] = sides[1 - e["who"]]["dealt"].get(cause, 0.0) + e["amount"]


func _print_build_stats(names: PackedStringArray, stats: Array[Dictionary]) -> void:
	print("%-15s%8s%8s%8s%8s%8s%8s%8s" % ["build", "win %", "length", "dealt", "taken", "hit %", "burn %", "steam %"])
	var in_band := 0
	for i in names.size():
		var s := stats[i]
		var n: int = s["duels"]
		var dealt: Dictionary = s["dealt"]
		var total := 0.0
		for v in dealt.values():
			total += v
		var win_rate: float = 100.0 * s["won"] / n
		if win_rate >= 30.0 and win_rate <= 70.0:
			in_band += 1
		print("%-15s%7.0f%%%7.1fs%8.0f%8.0f%7.0f%%%7.0f%%%7.0f%%" % [names[i].left(14), win_rate,
			s["seconds"] / n, total / n, s["taken"] / n,
			_pct(dealt["hit"], total), _pct(dealt["burn"], total), _pct(dealt["steam"], total)])
	print("\n%d of %d builds win 30-70%% of their duels. Dealt and taken are per duel." % [in_band, names.size()])


func _pct(part: float, whole: float) -> float:
	return 0.0 if whole <= 0.0 else 100.0 * part / whole


## Each build against an empty wand with bottomless HP and no escalation, so the
## numbers are raw output: time to deal 100 damage, damage over 30 s by cause,
## and how many draws failed for lack of mana.
func _dps(db: SpellDB, p_seed: int) -> void:
	var dummy := WandBuild.new()
	dummy.display_name = "Dummy"
	dummy.frame = load("res://data/frames/apprentice_rod.tres")
	print("%-15s%8s%8s%8s%8s%8s%8s%8s" % ["build", "to 100", "30s dmg", "hit", "burn", "steam", "dps", "no_mana"])
	for n in _build_names():
		var d := Duel.new(_load_build(n), dummy, db, p_seed)
		d.amp_at_end = 1.0
		d.hard_cap_seconds = 30.0
		d.casters[1].max_hp = 1e9
		d.casters[1].hp = 1e9
		d.run()
		var by_cause := {"hit": 0.0, "burn": 0.0, "steam": 0.0}
		var total := 0.0
		var to_100 := -1.0
		var no_mana := 0
		for e in d.events:
			if e["type"] == "no_mana" and e["who"] == 0:
				no_mana += 1
			if e["type"] != "damage" or e["who"] != 1:
				continue
			total += e["amount"]
			by_cause[e["cause"]] += e["amount"]
			if to_100 < 0.0 and total >= 100.0:
				to_100 = e["tick"] * Duel.TICK
		print("%-15s%8s%8.0f%8.0f%8.0f%8.0f%8.1f%8d" % [n.left(14),
			"never" if to_100 < 0.0 else "%.1fs" % to_100, total,
			by_cause["hit"], by_cause["burn"], by_cause["steam"], total / 30.0, no_mana])


## The Milestone 4 gate: each themed archetype should lose to its listed counter
## more often than not. Sample builds give a baseline for comparison.
func _archetypes(db: SpellDB, depth: int, seeds: int) -> void:
	var samples: Array[WandBuild] = []
	for n in _build_names():
		samples.append(_load_build(n))
	print("Depth %d, %d generated wands per archetype. Win rates are the player's.\n" % [depth, seeds])
	print("%-14s%-28s%10s%10s%8s" % ["archetype", "counter", "counter", "samples", "length"])
	var passed := 0
	var themed := 0
	for f in DirAccess.get_files_at(RunState.ENEMY_DIR):
		var def := load(RunState.ENEMY_DIR.path_join(f.trim_suffix(".remap"))) as EnemyDef
		if def.min_depth > depth or def.max_depth < depth:
			continue
		var counter_path := "%s/counters/%s.tres" % [BUILD_DIR, def.id]
		var counter := load(counter_path) as WandBuild if ResourceLoader.exists(counter_path) else null
		if def.themed:
			themed += 1
		var counter_wins := 0.0
		var sample_wins := 0.0
		var secs := 0.0
		var rng := RandomNumberGenerator.new()
		for s in seeds:
			rng.seed = hash([def.id, depth, s])
			var enemy := EnemyGen.generate(def, depth, rng, db)
			if counter != null:
				counter_wins += _score(Duel.new(counter, enemy, db, s).run())
			for b in samples:
				var d := Duel.new(b, enemy, db, s)
				sample_wins += _score(d.run())
				secs += d.seconds()
		var rate := counter_wins / seeds
		if counter != null and rate > 0.5:
			passed += 1
		print("%-14s%-28s%10s%9.0f%%%7.1fs" % [def.id.left(13), counter.display_name.left(27) if counter else "(generic)",
			"%.0f%%" % (100.0 * rate) if counter else "-", 100.0 * sample_wins / (seeds * samples.size()), secs / (seeds * samples.size())])
	print("\n%d of %d archetypes lose to their counter more often than not." % [passed, themed])


func _archmage(db: SpellDB, seeds: int) -> void:
	var boss := load(RunState.BOSS_PATH) as EnemyDef
	print("%-15s%8s%9s%9s" % ["build", "win %", "length", "boss HP"])
	for n in _build_names():
		var wins := 0.0
		var secs := 0.0
		var boss_hp := 0.0
		for s in seeds:
			var d := Duel.new(_load_build(n), boss.fixed_build, db, s, true)
			d.casters[1].max_hp = boss.max_hp
			d.casters[1].hp = boss.max_hp
			wins += _score(d.run())
			secs += d.seconds()
			boss_hp += maxf(0.0, d.casters[1].hp) / boss.max_hp
		print("%-15s%7.0f%%%8.1fs%8.0f%%" % [n.left(14), 100.0 * wins / seeds, secs / seeds, 100.0 * boss_hp / seeds])


func _score(winner: int) -> float:
	return 1.0 if winner == 0 else (0.5 if winner == Duel.DRAW else 0.0)


func _print_result(d: Duel) -> void:
	var r := d.result()
	var who := "Draw" if r.winner == Duel.DRAW else "%s wins" % d.casters[r.winner].name
	print("%s after %.2fs  (HP %s %.1f, %s %.1f)" % [
		who, r.seconds, d.casters[0].name, r.hp[0], d.casters[1].name, r.hp[1]])


func _load_build(name: String) -> WandBuild:
	var b := load("%s/%s.tres" % [BUILD_DIR, name]) as WandBuild
	if b == null:
		printerr("Unknown build '%s'. Builds: %s" % [name, ", ".join(_build_names())])
		quit(1)
	return b


func _build_names() -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(BUILD_DIR):
		f = f.trim_suffix(".remap")
		if f.ends_with(".tres"):
			out.append(f.get_basename())
	out.sort()
	return out


func _flag_value(args: PackedStringArray, flag: String, fallback: String) -> String:
	var i := args.find(flag)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else fallback
