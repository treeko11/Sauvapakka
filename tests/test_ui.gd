extends SceneTree
## Smoke tests for the screens: they build, run to completion and don't error.
##   godot --headless --script res://tests/test_ui.gd

var db: SpellDB
var checks := 0
var failures := 0
var _current := ""


func _initialize() -> void:
	db = SpellDB.load_default()
	for m in get_script().get_script_method_list():
		if m.name.begins_with("test_"):
			_current = m.name
			await call(m.name)
	print("%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL %s: %s" % [_current, what])


func _build(name: String) -> WandBuild:
	return load("res://data/builds/%s.tres" % name)


## Runs a duel screen to its end panel by feeding large frame deltas.
func _run_to_end(screen: DuelScreen) -> void:
	for i in 2000:
		screen._process(0.25)
		if screen._ended:
			break


func test_duel_screen_plays_to_end() -> void:
	var screen := DuelScreen.new()
	screen.setup(_build("steam_trigger"), _build("turtle"), db, 1)
	root.add_child(screen)
	await process_frame
	var winner := [-99]
	screen.finished.connect(func(w: int) -> void: winner[0] = w)
	screen._process(1.0)
	_check(not screen.duel.in_flight.is_empty() or screen.duel.tick > 0, "duel advances")
	screen._set_paused(true)
	var before := screen.duel.tick
	screen._process(1.0)
	_check(screen.duel.tick == before, "pause stops the sim")
	screen._set_paused(false)
	_run_to_end(screen)
	_check(screen._ended, "duel ends")
	_check(screen._end_panel != null, "end panel shown")
	screen._restart()
	_check(screen.duel.tick == 0 and not screen._ended, "watch again restarts")
	screen.queue_free()


func test_inspect_describes_every_spell() -> void:
	var screen := DuelScreen.new()
	screen.setup(_build("steam_trigger"), _build("wide_multicast"), db)
	root.add_child(screen)
	await process_frame
	var seen := {}
	for i in 400:
		screen._process(0.05)
		for s in screen.duel.in_flight:
			if not seen.has(s.spell.id):
				seen[s.spell.id] = true
				_check(screen.describe_shot(s).begins_with(s.spell.display_name), "describes %s" % s.spell.id)
	_check(seen.size() >= 4, "saw several spells in flight")
	screen.queue_free()


func test_training_dummy() -> void:
	var dummy := WandBuild.new()
	dummy.display_name = "Training Dummy"
	dummy.frame = load("res://data/frames/apprentice_rod.tres")
	var screen := DuelScreen.new()
	screen.setup(_build("burn"), dummy, db, 0, false, true)
	root.add_child(screen)
	await process_frame
	_run_to_end(screen)
	_check(screen._ended, "dummy session ends")
	_check(is_equal_approx(screen.duel.seconds(), 30.0), "runs 30 s")
	_check(screen.duel.casters[1].hp > 0.0, "dummy survives")
	screen.queue_free()


func test_app_menu_and_viewer() -> void:
	var app := (load("res://ui/app.tscn") as PackedScene).instantiate() as App
	root.add_child(app)
	await process_frame
	_check(app.current is MainMenu, "starts on the menu")
	app.show_screen(DuelViewer.new(app))
	await process_frame
	(app.current as DuelViewer)._watch(false)
	await process_frame
	_check(app.current is DuelScreen, "viewer opens a duel")
	app.queue_free()
