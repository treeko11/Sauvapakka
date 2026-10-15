extends SceneTree
## Headless duel runner. Build names are files in res://data/builds, without ".tres".
##
##   One duel with a full event trace:
##     godot --headless --script res://tools/run_duel.gd -- burn turtle --trace
##   Every build against every other, over several seeds:
##     godot --headless --script res://tools/run_duel.gd -- --matrix --seeds 5
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
	print(header)
	var total_seconds := 0.0
	var duels := 0
	for i in builds.size():
		var line := "%-*s" % [width, names[i].left(width - 1)]
		for j in builds.size():
			if i == j:
				line += "%*s" % [width, "-"]
				continue
			var wins := 0.0
			for s in seeds:
				var d := Duel.new(builds[i], builds[j], db, s, boss)
				var w := d.run()
				total_seconds += d.seconds()
				duels += 1
				if w == 0:
					wins += 1.0
				elif w == Duel.DRAW:
					wins += 0.5
			line += "%*s" % [width, "%d%%" % roundi(100.0 * wins / seeds)]
		print(line)
	print("\n%d duels, average length %.1fs" % [duels, total_seconds / duels])


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
