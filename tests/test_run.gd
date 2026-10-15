extends SceneTree
## Run rules: the spell book, hands, wand editing, enemy generation and rewards.
##   godot --headless --script res://tests/test_run.gd

var db: SpellDB
var checks := 0
var failures := 0
var _current := ""


func _initialize() -> void:
	db = SpellDB.load_default()
	for m in get_script().get_script_method_list():
		if m.name.begins_with("test_"):
			_current = m.name
			call(m.name)
	print("%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL %s: %s" % [_current, what])


func _eq(actual: Variant, expected: Variant, what: String) -> void:
	_check(actual == expected, "%s (expected %s, got %s)" % [what, expected, actual])


func _run(p_seed := 1) -> RunState:
	return RunState.create(db, p_seed)


func test_new_run_shape() -> void:
	var r := _run()
	_eq(r.wands.size(), 2, "two starting wands")
	_eq(r.fights.size(), 7, "six fights and a boss")
	_check(r.fights[6]["boss"], "boss is last")
	for i in 6:
		_eq(r.fights[i]["def"].themed, RunState.FIGHT_PLAN[i] == "themed", "fight %d type" % i)
	var themed := {}
	for f in r.fights:
		if f["def"].themed and not f["boss"]:
			themed[f["def"].id] = true
	_eq(themed.size(), 3, "themed enemies don't repeat")
	_eq(r.book_size(), RunState.STARTER_WAND.size() + RunState.STARTER_LIBRARY.size(), "book counts wands and library")


func test_same_seed_same_run() -> void:
	var a := _run(42)
	var b := _run(42)
	for i in a.fights.size():
		_eq(a.fights[i]["def"].id, b.fights[i]["def"].id, "fight %d enemy" % i)
		_eq(a.fights[i]["build"].spell_ids, b.fights[i]["build"].spell_ids, "fight %d wand" % i)


func test_deal_hand_respects_pins_and_wands() -> void:
	var r := _run()
	_check(r.pin_spell("arc"), "pin arc")
	var slotted := r.wands[0].spell_ids.duplicate()
	r.deal_hand()
	_eq(r.hand.size(), RunState.HAND_SIZE, "hand of five")
	_check(r.hand.has("arc"), "pinned spell dealt")
	_eq(r.wands[0].spell_ids, slotted, "slotted spells stay in the wand")
	_eq(r.book_size(), RunState.STARTER_WAND.size() + RunState.STARTER_LIBRARY.size(), "dealing doesn't change the book")
	r.return_hand()
	_eq(r.hand.size(), 0, "hand returned")


func test_place_and_unslot() -> void:
	var r := _run()
	r.deal_hand()
	var first := r.hand[0]
	_check(r.place_from_hand(0, 1, 0), "place into empty slot")
	_eq(r.wands[1].spell_ids[0], first, "slotted")
	_eq(r.hand.size(), RunState.HAND_SIZE - 1, "left the hand")
	var second := r.hand[0]
	_check(r.place_from_hand(0, 1, 0), "replace a slotted spell")
	_eq(r.wands[1].spell_ids[0], second, "new spell slotted")
	_check(r.hand.has(first), "replaced spell back in hand")
	_check(r.unslot(1, 0), "unslot")
	_check(r.hand.has(second), "unslotted spell in hand")
	_check(not r.unslot(1, 0), "can't unslot an empty slot")
	_check(not r.place_from_hand(0, 1, 99), "slot out of range")


func test_move_slot_across_wands() -> void:
	var r := _run()
	var a := r.wands[0].spell_ids[2]
	_check(r.move_slot(0, 2, 1, 3), "move")
	_eq(r.wands[1].spell_ids[3], a, "moved across")
	_eq(r.wands[0].spell_ids[2], "", "old slot empty")


func test_stash_pin_remove() -> void:
	var r := _run()
	_check(r.stash_spell("ward"), "stash")
	_check(not r.library.has("ward"), "out of draw pool")
	r.deal_hand()
	_check(not r.hand.has("ward"), "stashed spell not dealt")
	r.return_hand()
	_check(r.unstash_spell("ward"), "unstash")
	_check(r.pin_spell("ward"), "pin")
	_check(not r.pin_spell("arc"), "pin slots are limited")
	_check(r.remove_spell("ward"), "remove")
	_check(not r.pinned.has("ward"), "removing unpins")
	_check(r.remove_spell("arc"), "second removal")
	_check(not r.remove_spell("ember"), "out of removal charges")


func test_enemy_generation_scales() -> void:
	var rng := RandomNumberGenerator.new()
	var pyro := load("res://data/enemies/pyromancer.tres") as EnemyDef
	for depth in 6:
		for n in 5:
			rng.seed = depth * 100 + n
			var b := EnemyGen.generate(pyro, depth, rng, db)
			var filled := 0
			for sp in b.resolve(db):
				if sp != null:
					filled += 1
					_check(sp.rarity <= EnemyGen.max_rarity(depth), "rarity fits depth %d" % depth)
			_eq(filled, EnemyGen.slots_to_fill(pyro, depth, b.frame.capacity), "slot count at depth %d" % depth)
	rng.seed = 5
	_eq(EnemyGen.generate(pyro, 4, rng, db).frame.id, &"ember_staff", "themed frame deeper in")


func test_smart_order_feeds_projectiles() -> void:
	var spells: Array[SpellDef] = []
	for sid in ["flicker", "damage_plus", "ward", "double_spell", "ember", "flicker_trigger", "frost_shard"]:
		spells.append(db.get_spell(sid))
	var ids := EnemyGen.smart_order(spells).map(func(s: SpellDef) -> String: return s.id)
	_eq(ids[0], "ward", "wards first")
	_eq(ids[1], "double_spell", "multicast before its projectiles")
	_check(ids.find("damage_plus") < ids.find("ember") or ids.find("damage_plus") < ids.find("flicker"), "modifier before a projectile")
	var t: int = ids.find("flicker_trigger")
	_check(t >= 0 and t + 1 < ids.size() and db.get_spell(ids[t + 1]).kind == SpellDef.Kind.PROJECTILE, "trigger carries a projectile")


func test_traits_from_wand() -> void:
	var b := load("res://data/builds/turtle.tres") as WandBuild
	var t := EnemyGen.traits(b, db)
	_check(t.has("Shielded") and t.has("Reflects") and t.has("Burns"), "turtle traits %s" % t)


func test_win_gives_rewards_then_next_fight() -> void:
	var r := _run(3)
	r.deal_hand()
	var d := r.make_duel(0)
	_eq(d.casters[1].max_hp, r.current_fight()["def"].max_hp, "enemy HP from its archetype")
	d.winner = 0
	r.finish_fight(d)
	_eq(r.phase, RunState.Phase.REWARD, "reward after a win")
	_eq(r.reward_options.size(), 3, "three choices")
	_eq(r.hand.size(), 0, "hand returned after the fight")
	var before := r.book_size()
	var drops := 1 if r.enemy_drop != "" else 0
	var pick := r.reward_options[0]
	r.take_rewards(pick)
	_eq(r.book_size(), before + 1 + drops, "choice and drop added")
	_check(r.found.has(pick), "found records the pick")
	_eq(r.fight_index, 1, "next fight")
	_eq(r.phase, RunState.Phase.PREVIEW, "preview next")


func test_frame_drop_adds_wand() -> void:
	var r := _run(4)
	r.fight_index = RunState.FRAME_DROP_AFTER[0]
	var d := r.make_duel(0)
	d.winner = 0
	r.finish_fight(d)
	_check(r.frame_drop != null, "frame drops")
	r.take_rewards("", -1)
	_eq(r.wands.size(), 3, "third wand")
	_eq(r.wands[2].spell_ids.size(), r.wands[2].frame.capacity, "padded")


func test_replace_frame_returns_overflow() -> void:
	var r := _run(4)
	var small := FrameDef.new()
	small.capacity = 2
	var before := r.book_size()
	r._take_frame(small, 0)
	_eq(r.wands[0].spell_ids.size(), 2, "fits the new frame")
	_eq(r.book_size(), before, "no spells lost")


func test_loss_ends_run_and_boss_win_ends_it() -> void:
	var r := _run(5)
	var d := r.make_duel(0)
	d.winner = 1
	r.finish_fight(d)
	_eq(r.phase, RunState.Phase.LOST, "loss ends the run")
	var r2 := _run(5)
	r2.fight_index = 6
	var d2 := r2.make_duel(0)
	_eq(d2.fight_seconds, 60.0, "boss fight is 60 s")
	d2.winner = 0
	r2.finish_fight(d2)
	_eq(r2.phase, RunState.Phase.WON, "boss win ends the run")


func test_profile_round_trip() -> void:
	var path := "user://test_run_profile.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var p := Profile.load_or_new(path)
	_eq(p.runs, 0, "fresh profile")
	var r := _run(9)
	r.discoveries["steam"] = true
	r.fight_index = 3
	r.phase = RunState.Phase.LOST
	p.settings["duel_speed"] = 2.0
	p.record_run(r, true)
	var q := Profile.load_or_new(path)
	_eq(q.runs, 1, "run counted")
	_eq(q.wins, 0, "loss isn't a win")
	_eq(q.best_fight, 4, "furthest fight")
	_check(q.interactions.has("steam"), "interaction saved")
	_check(q.spells_found.has("ember"), "spells saved")
	_eq(q.settings["duel_speed"], 2.0, "settings saved")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("not json")
	f.close()
	_eq(Profile.load_or_new(path).runs, 0, "corrupt save starts fresh")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
