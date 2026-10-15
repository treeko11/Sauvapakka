extends SceneTree
## Checks the wand execution rules and status interactions from the design scope.
##   godot --headless --script res://tests/test_rules.gd
## Exits with code 1 if any check fails.

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


# --- Helpers ----------------------------------------------------------------

func _check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL %s: %s" % [_current, what])


func _eq(actual: Variant, expected: Variant, what: String) -> void:
	var ok: bool
	if typeof(actual) == TYPE_FLOAT or typeof(expected) == TYPE_FLOAT:
		ok = is_equal_approx(float(actual), float(expected))
	else:
		ok = actual == expected
	_check(ok, "%s (expected %s, got %s)" % [what, expected, actual])


## A build whose frame has exactly one slot per spell, with optional stat overrides.
func _build(frame_id: String, ids: Array, overrides: Dictionary = {}) -> WandBuild:
	var b := WandBuild.new()
	b.display_name = frame_id
	b.frame = (load("res://data/frames/%s.tres" % frame_id) as FrameDef).duplicate()
	b.frame.capacity = ids.size()
	for k in overrides:
		b.frame.set(k, overrides[k])
	b.spell_ids = PackedStringArray(ids)
	return b


## Caster 0 uses the given wand; caster 1 holds an empty wand as a target.
func _duel(ids: Array, frame_id := "apprentice_rod", overrides: Dictionary = {}) -> Duel:
	return Duel.new(_build(frame_id, ids, overrides), _build("apprentice_rod", []), db)


func _spell(id: String) -> SpellDef:
	return db.get_spell(id)


func _has_event(d: Duel, type: String, who := -99) -> bool:
	for e in d.events:
		if e["type"] == type and (who == -99 or e["who"] == who):
			return true
	return false


func _count_events(d: Duel, type: String) -> int:
	var n := 0
	for e in d.events:
		if e["type"] == type:
			n += 1
	return n


# --- Data -------------------------------------------------------------------

func test_all_starter_spells_load() -> void:
	_eq(db.size(), 25, "spell count")
	for s in db.all():
		_check(s.display_name != "", "%s has a name" % s.id)
		_check(s.description != "", "%s has a description" % s.id)


func test_all_builds_resolve() -> void:
	for f in DirAccess.get_files_at("res://data/builds"):
		var b := load("res://data/builds/" + f.trim_suffix(".remap")) as WandBuild
		_check(b != null and b.frame != null, "%s loads with a frame" % f)
		for sid in b.spell_ids:
			_check(db.has(sid), "%s: spell '%s' exists" % [f, sid])
		_check(b.spell_ids.size() <= b.frame.capacity, "%s fits its frame" % f)


# --- Wand execution rules ----------------------------------------------------

func test_modifier_attaches_and_draws_replacement() -> void:
	var d := _duel(["damage_plus", "flicker", "flicker"])
	var shots := d.cast_now(0)
	_eq(shots.size(), 1, "one projectile per cast")
	_eq(shots[0].damage, _spell("flicker").damage + _spell("damage_plus").add_damage, "Damage Plus adds damage")
	_eq(d.casters[0].wand.pointer, 2, "modifier didn't use up the cast")


func test_multicast_fires_together() -> void:
	var d := _duel(["double_spell", "flicker", "ember", "flicker"])
	_eq(d.cast_now(0).size(), 2, "Double Spell fires 2")


func test_triple_spell_penalty() -> void:
	var d := _duel(["triple_spell", "flicker", "flicker", "flicker"])
	var shots := d.cast_now(0)
	_eq(shots.size(), 3, "Triple Spell fires 3")
	_eq(shots[2].damage_mult, _spell("triple_spell").damage_mult, "damage penalty applies")


func test_recharge_after_last_slot() -> void:
	var d := _duel(["flicker", "flicker"])
	d.cast_now(0)
	_check(not _has_event(d, "recharge"), "no recharge mid-wand")
	d.cast_now(0)
	_check(_has_event(d, "recharge"), "recharges after the last slot")
	_eq(d.casters[0].wand.pointer, 0, "back to the first slot")


func test_wrapping_fires_then_recharges() -> void:
	var d := _duel(["flicker", "ember", "frost_shard"], "apprentice_rod", {"spells_per_cast": 2})
	d.cast_now(0)
	var shots := d.cast_now(0)
	_eq(shots.size(), 2, "wrapped draw still fires")
	_eq(shots[1].spell.id, &"flicker", "wrapped to slot 0")
	_check(_has_event(d, "wrap"), "wrap logged")
	_check(_has_event(d, "recharge"), "wrap still recharges")


func test_unaffordable_spell_is_skipped() -> void:
	var d := _duel(["magic_missile", "flicker"])
	d.casters[0].wand.mana = 5.0
	var shots := d.cast_now(0)
	_eq(shots.size(), 1, "still fires something")
	_eq(shots[0].spell.id, &"flicker", "fires what it can afford")
	_check(_has_event(d, "no_mana"), "skip logged")


func test_leyline_first_slot_is_free() -> void:
	var d := _duel(["magic_missile", "flicker"], "leyline_rod")
	d.casters[0].wand.mana = 0.0
	var shots := d.cast_now(0)
	_eq(shots[0].spell.id, &"magic_missile", "slot 0 costs nothing")


func test_twin_fork_doubles_first_cast() -> void:
	var d := _duel(["flicker", "flicker", "flicker", "flicker", "flicker", "flicker"], "twin_fork")
	_eq(d.cast_now(0).size(), 4, "first cast doubled")
	_eq(d.cast_now(0).size(), 2, "second cast normal")


func test_divide_by_2() -> void:
	var d := _duel(["divide_by_2", "magic_missile"])
	var shots := d.cast_now(0)
	_eq(shots.size(), 2, "cast twice")
	_eq(shots[0].damage_mult, _spell("divide_by_2").damage_mult, "reduced damage each")


func test_split() -> void:
	var d := _duel(["split", "flicker"])
	var shots := d.cast_now(0)
	_eq(shots.size(), 3, "becomes 3")
	_eq(shots[0].damage_mult, _spell("split").damage_mult, "weaker")


func test_trigger_carries_payload() -> void:
	var d := _duel(["flicker_trigger", "ember", "flicker"])
	var shots := d.cast_now(0)
	_eq(shots.size(), 1, "payload isn't fired at cast time")
	_eq(shots[0].payload.size(), 1, "carries one payload")
	_eq(shots[0].payload[0].spell.id, &"ember", "payload is the next draw")


func test_silence_skips_next_spell() -> void:
	var d := _duel(["ember", "flicker"])
	d.casters[0].silence = 1
	var shots := d.cast_now(0)
	_eq(shots[0].spell.id, &"flicker", "Ember skipped")


func test_ward_counts_toward_cast() -> void:
	var d := _duel(["ward", "flicker"])
	var shots := d.cast_now(0)
	_eq(shots.size(), 1, "Ward used the cast")
	_eq(d.casters[0].wards, 2, "Ward applied to caster")


func test_draw_cap_prevents_hangs() -> void:
	var b := _build("twin_fork", ["triple_spell", "double_spell", "flicker_trigger", "flicker_trigger", "triple_spell", "flicker_trigger"])
	var d := Duel.new(b, b, db)
	d.run()
	_check(d.winner != Duel.RUNNING, "duel finishes")


func test_deterministic() -> void:
	var a := load("res://data/builds/steam_trigger.tres") as WandBuild
	var b := load("res://data/builds/wide_multicast.tres") as WandBuild
	var d1 := Duel.new(a, b, db, 7)
	var d2 := Duel.new(a, b, db, 7)
	d1.run()
	d2.run()
	_eq(var_to_str(d1.events).hash(), var_to_str(d2.events).hash(), "same seed, same log")


# --- Hits, wards and statuses -------------------------------------------------

func test_ward_blocks_per_hit() -> void:
	var d := _duel(["ricochet_orb"])
	d.casters[1].wards = 1
	var s := d.cast_now(0)[0]
	d.arrive_now(s)
	_eq(d.casters[1].wards, 0, "ward used")
	_eq(d.casters[1].hp, d.casters[1].max_hp - _spell("ricochet_orb").damage, "second hit lands")


func test_piercing_ignores_ward() -> void:
	var d := _duel(["piercing", "flicker"])
	d.casters[1].wards = 1
	d.arrive_now(d.cast_now(0)[0])
	_eq(d.casters[1].wards, 1, "ward untouched")
	_eq(d.casters[1].hp, d.casters[1].max_hp - _spell("flicker").damage, "damage lands")


func test_reflect_fires_payload_at_reflector() -> void:
	var d := _duel(["flicker_trigger", "ember"])
	d.casters[1].reflects = 1
	d.arrive_now(d.cast_now(0)[0])
	_eq(d.casters[1].reflects, 0, "reflect used")
	var to_reflector := 0
	var bounced := 0
	for s in d.in_flight:
		if s.target == 1 and s.spell.id == &"ember":
			to_reflector += 1
		if s.target == 0 and s.spell.id == &"flicker_trigger":
			bounced += 1
			_eq(s.payload.size(), 0, "bounced shot has no payload")
	_eq(to_reflector, 1, "payload heads for the reflector")
	_eq(bounced, 1, "projectile bounces back")


func test_wet_removes_burn() -> void:
	var d := _duel(["water_orb"])
	d.casters[1].burn = 3
	d.arrive_now(d.cast_now(0)[0])
	_eq(d.casters[1].burn, 0, "burn removed")
	_eq(d.casters[1].wet, 0, "wet used up")


func test_wet_doubles_shock() -> void:
	var d := _duel(["flicker"])
	d.casters[1].shock = 1
	d.casters[1].wet = 1
	d.arrive_now(d.cast_now(0)[0])
	_eq(d.casters[1].hp, d.casters[1].max_hp - _spell("flicker").damage - 2.0 * Duel.SHOCK_BONUS_PER_STACK, "double shock bonus")
	_eq(d.casters[1].shock, 0, "shock consumed")


func test_chill_on_wet_freezes_instantly() -> void:
	var d := _duel(["frost_shard"])
	d.casters[1].wet = 1
	d.arrive_now(d.cast_now(0)[0])
	_check(d.casters[1].frozen, "frozen")


func test_chill_stacks_freeze_at_five() -> void:
	var d := _duel(["frost_shard"])
	d.casters[1].chill = 3
	d.arrive_now(d.cast_now(0)[0])
	_check(d.casters[1].frozen, "frozen at 5 stacks")
	_eq(d.casters[1].chill, 0, "chill reset")


func test_frozen_skips_next_cast() -> void:
	var d := _duel(["flicker"])
	d.casters[0].frozen = true
	_eq(d.cast_now(0).size(), 0, "cast skipped")
	_check(not d.casters[0].frozen, "thawed")


func test_frozen_waits_before_next_cast() -> void:
	var d := _duel(["flicker"])
	d.casters[0].frozen = true
	d.cast_now(0)
	_eq(d.casters[0].wand.next_cast_tick, d.tick + roundi(Duel.FROZEN_SECONDS * Duel.TICKS_PER_SECOND), "frozen wait")


func test_burn_stacks_cap() -> void:
	var d := _duel(["ember"])
	d.casters[1].burn = Duel.MAX_BURN_STACKS - 1
	d.arrive_now(d.cast_now(0)[0])
	_eq(d.casters[1].burn, Duel.MAX_BURN_STACKS, "capped")


func test_burn_on_frozen_steams() -> void:
	var d := _duel(["ember"])
	d.casters[1].frozen = true
	d.arrive_now(d.cast_now(0)[0])
	_check(not d.casters[1].frozen, "thawed")
	_eq(d.casters[1].hp, d.casters[1].max_hp - _spell("ember").damage - Duel.STEAM_DAMAGE, "steam burst")


func test_glacier_chill_does_not_decay() -> void:
	var d := _duel(["frost_shard"], "glacier_wand")
	d.arrive_now(d.cast_now(0)[0])
	_check(d.casters[1].chill_permanent, "marked permanent")


func test_ember_staff_burn_lasts_longer() -> void:
	var d := _duel(["ember"], "ember_staff")
	_eq(d.cast_now(0)[0].burn, _spell("ember").burn + 1, "extra burn stack")


func test_mana_leech_steals() -> void:
	var d := _duel(["mana_leech"])
	d.casters[0].wand.mana = 50.0
	d.arrive_now(d.cast_now(0)[0])
	_eq(d.casters[1].wand.mana, 100.0 - _spell("mana_leech").mana_drain, "target lost mana")
	_eq(d.casters[0].wand.mana, 50.0 - _spell("mana_leech").mana_cost + _spell("mana_leech").mana_drain, "caster gained it")
