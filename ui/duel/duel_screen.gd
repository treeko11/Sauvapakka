class_name DuelScreen
extends Control
## Plays a duel back in real time from the deterministic sim: the arena shows
## what happened, the wand strips show why. Caster 0 is the player (bottom),
## caster 1 the enemy (top).

signal finished(winner: int)

const SPEEDS := [0.5, 1.0, 2.0]

var duel: Duel
var db: SpellDB
var dummy := false
var continue_text := "Continue"
var enemy_robe := Palette.ENEMY_ROBE
## When set, the speed setting is read from and saved to it.
var profile: Profile

var _speed := 1.0
var _paused := false
var _acc := 0.0
var _now := 0.0
var _event_index := 0
var _ended := false
var _builds: Array[WandBuild] = []
var _seed := 0
var _boss := false
var _factory := Callable()

var _strips: Array[WandStrip] = []
var _wizards: Array[WizardPanel] = []
var _overlay: ArenaOverlay
var _time_label: Label
var _amp_label: Label
var _pause_button: Button
## Lets the player leave a dummy session before it ends.
var _back_button: Button
var _speed_buttons: Array[Button] = []
var _inspect: PanelContainer
var _inspect_label: Label
var _end_panel: PanelContainer


## Call before adding to the tree. With `p_dummy`, the enemy is a passive target
## with bottomless HP and the fight runs 30 s without escalation.
func setup(player: WandBuild, enemy: WandBuild, p_db: SpellDB, p_seed := 0, boss := false, p_dummy := false) -> void:
	_builds = [player, enemy]
	db = p_db
	_seed = p_seed
	_boss = boss
	dummy = p_dummy


## Call before adding to the tree. `factory` returns a fresh Duel, so the run
## can set enemy HP and Watch again replays the same seed.
func setup_factory(factory: Callable, p_db: SpellDB) -> void:
	_factory = factory
	db = p_db


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	UiKit.background(self)
	var ground := ColorRect.new()
	ground.color = Palette.NIGHT.darkened(0.25)
	ground.position = Vector2(0, 206)
	ground.size = Vector2(720, 856)
	ground.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(ground)

	for i in 2:
		var wiz := WizardPanel.new()
		wiz.caster_index = i
		wiz.facing = 1.0 if i == 0 else -1.0
		wiz.robe = Palette.PLAYER_ROBE if i == 0 else enemy_robe
		wiz.position = Vector2(0, 790) if i == 0 else Vector2(0, 210)
		wiz.size = Vector2(720, 270)
		wiz.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(wiz)
		_wizards.append(wiz)
		var strip := WandStrip.new()
		strip.caster_index = i
		strip.position = Vector2(20, 1062) if i == 0 else Vector2(20, 68)
		strip.size = Vector2(680, 136)
		strip.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(strip)
		_strips.append(strip)

	_build_top_bar()
	_build_speed_bar()
	_overlay = ArenaOverlay.new()
	_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_build_inspect_panel()
	_restart()


func _build_top_bar() -> void:
	_time_label = UiKit.label("0.0 s", 26, Palette.PARCHMENT, false)
	_time_label.position = Vector2(20, 14)
	add_child(_time_label)
	_amp_label = UiKit.label("", 22, Palette.BURN, false)
	_amp_label.position = Vector2(150, 18)
	add_child(_amp_label)
	_pause_button = UiKit.button("Pause", _toggle_pause, Vector2(140, 56))
	_pause_button.position = Vector2(560, 8)
	add_child(_pause_button)
	if dummy:
		_back_button = UiKit.button("Back", func() -> void: finished.emit(Duel.RUNNING), Vector2(140, 56))
		_back_button.position = Vector2(408, 8)
		add_child(_back_button)


func _build_speed_bar() -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(20, 1206)
	row.size = Vector2(680, 64)
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	for s in SPEEDS:
		var b := UiKit.button("%s×" % ("0.5" if s == 0.5 else str(int(s))), _set_speed.bind(s))
		b.toggle_mode = true
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(b)
		_speed_buttons.append(b)
	_set_speed(float(profile.settings.get("duel_speed", 1.0)) if profile else 1.0, false)


func _build_inspect_panel() -> void:
	_inspect = PanelContainer.new()
	_inspect.position = Vector2(110, 520)
	_inspect.custom_minimum_size = Vector2(500, 0)
	_inspect.mouse_filter = MOUSE_FILTER_IGNORE
	_inspect_label = UiKit.label("", 22)
	_inspect.add_child(_inspect_label)
	_inspect.visible = false
	add_child(_inspect)


func _restart() -> void:
	duel = _factory.call() if _factory.is_valid() else Duel.new(_builds[0], _builds[1], db, _seed, _boss)
	if dummy:
		duel.amp_at_end = 1.0
		duel.hard_cap_seconds = 30.0
		duel.casters[1].max_hp = 1e6
		duel.casters[1].hp = 1e6
	_acc = 0.0
	_now = 0.0
	_event_index = 0
	_ended = false
	for i in 2:
		_strips[i].duel = duel
		_wizards[i].duel = duel
		_wizards[i].dummy = dummy and i == 1
	_overlay.duel = duel
	_overlay.selected_uid = -1
	_inspect.visible = false
	if _end_panel != null:
		_end_panel.queue_free()
		_end_panel = null
	_pause_button.disabled = false
	_set_paused(false)


func _set_speed(s: float, remember := true) -> void:
	_speed = s
	if profile != null and remember and profile.settings.get("duel_speed") != s:
		profile.settings["duel_speed"] = s
		profile.save()
	for i in _speed_buttons.size():
		_speed_buttons[i].set_pressed_no_signal(SPEEDS[i] == s)


func _toggle_pause() -> void:
	_set_paused(not _paused)


func _set_paused(p: bool) -> void:
	_paused = p
	_pause_button.text = "Play" if p else "Pause"
	if not p:
		_overlay.selected_uid = -1
		_inspect.visible = false


func _process(delta: float) -> void:
	if not _paused and not _ended:
		var dt := delta * _speed
		_acc += dt
		_now += dt
		while _acc >= Duel.TICK and not _ended:
			_acc -= Duel.TICK
			duel.step()
			_consume_events()
			_ended = duel.winner != Duel.RUNNING
	elif _ended:
		_now += delta

	var tick_f := duel.tick + (0.0 if _ended else _acc / Duel.TICK)
	_overlay.tick_f = tick_f
	_overlay.now = _now
	for i in 2:
		_strips[i].now = _now
		_wizards[i].now = _now
		_overlay.tips[i] = _wizards[i].wand_tip_global()
		_overlay.bodies[i] = _wizards[i].body_center_global()
	_time_label.text = "%.1f s" % (tick_f * Duel.TICK)
	var amp := duel._amp()
	_amp_label.text = "Escalation ×%.1f" % amp if amp > 1.0 else ""


func _unhandled_input(event: InputEvent) -> void:
	if not _paused or _ended:
		return
	var pos := Vector2.INF
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
	if pos == Vector2.INF:
		return
	pos = get_global_transform_with_canvas().affine_inverse() * pos
	var s := _overlay.shot_at(pos)
	_overlay.selected_uid = s.uid if s != null else -1
	_inspect.visible = s != null
	if s != null:
		_inspect_label.text = describe_shot(s)
		_inspect.position.y = clampf(pos.y + 40.0, 420.0, 760.0)


func describe_shot(s: Shot) -> String:
	var lines := PackedStringArray()
	var who := duel.casters[s.source].name
	lines.append("%s  (from %s%s)" % [s.spell.display_name, who, ", reflected" if s.bounces > 0 else ""])
	if not s.mod_ids.is_empty():
		var names := PackedStringArray()
		for m in s.mod_ids:
			names.append(db.get_spell(m).display_name)
		lines.append("Modifiers: " + ", ".join(names))
	var dmg := s.damage * s.damage_mult
	var hit_text := "Damage %.1f" % dmg
	if s.hits > 1:
		hit_text += " × %d hits" % s.hits
	if s.chain > 0:
		hit_text += ", chains %d" % s.chain
	lines.append(hit_text)
	var st := PackedStringArray()
	for pair in [["Burn", s.burn], ["Chill", s.chill], ["Wet", s.wet], ["Shock", s.shock], ["Pierce", s.pierce],
			["Mana drain", s.mana_drain], ["Silence", s.silence]]:
		if pair[1] > 0:
			st.append("%s %d" % pair)
	if not st.is_empty():
		lines.append(", ".join(st))
	if not s.payload.is_empty():
		var names := PackedStringArray()
		for p in s.payload:
			names.append(p.spell.display_name)
		lines.append("Payload on contact: " + ", ".join(names))
	lines.append("Lands in %.2f s" % maxf(0.0, (s.arrive_tick - duel.tick) * Duel.TICK))
	return "\n".join(lines)


func _consume_events() -> void:
	while _event_index < duel.events.size():
		_on_event(duel.events[_event_index])
		_event_index += 1


func _on_event(e: Dictionary) -> void:
	var who: int = e["who"]
	var o := _overlay
	match e["type"]:
		"cast":
			_strips[who].lift(e["slots"])
		"launch":
			o.burst(o.tips[who], Palette.spell_color(db.get_spell(e["spell"])), 18.0)
		"self":
			_wizards[who].shield()
			o.float_text(o.bodies[who], "+Reflect" if db.get_spell(e["spell"]).reflect_hits > 0 else "+Ward", Palette.WARD)
		"damage":
			_on_damage(e)
		"shock_burst":
			o.burst(o.bodies[who], Palette.SHOCK, 80.0)
			o.float_text(o.bodies[who] + Vector2(0, -40), "SHOCK ×2!" if e["wet"] else "SHOCK!", Palette.SHOCK, 30)
		"frozen":
			o.burst(o.bodies[who], Palette.CHILL, 90.0)
			o.float_text(o.bodies[who] + Vector2(0, -40), "INSTANT FREEZE!" if e["cause"] == "wet" else "FROZEN!", Palette.CHILL, 30)
		"frozen_skip":
			o.float_text(o.bodies[who], "Frozen: cast skipped", Palette.CHILL)
		"doused":
			o.burst(o.bodies[who], Palette.WET, 50.0)
			o.float_text(o.bodies[who], "Doused", Palette.WET)
		"blocked":
			_wizards[who].shield()
			o.burst(o.bodies[who], Palette.WARD, 70.0)
			o.float_text(o.bodies[who], "Blocked", Palette.WARD)
		"pierce":
			o.float_text(o.bodies[who], "Pierced ward", Palette.PARCHMENT)
		"reflect":
			_wizards[who].shield()
			o.burst(o.bodies[who], Palette.WARD, 90.0)
			o.float_text(o.bodies[who] + Vector2(0, -40), "REFLECT!", Palette.WARD, 28)
		"mana_drain":
			o.float_text(o.bodies[who], "-%d mana" % roundi(e["amount"]), Palette.DISRUPT_TEXT)
		"silence":
			o.float_text(o.bodies[who], "Silenced", Palette.DISRUPT_TEXT)
		"silenced":
			_strips[who].flash(e["slot"], Palette.DISRUPT_TEXT)
			o.float_text(_strips[who].slot_center_global(e["slot"]) + Vector2(0, -50), "Silenced", Palette.DISRUPT_TEXT, 18)
		"no_mana":
			_strips[who].flash(e["slot"], Palette.HP)
			o.float_text(_strips[who].slot_center_global(e["slot"]) + Vector2(0, -50), "No mana", Palette.MANA, 18)
		"fizzle":
			o.float_text(o.tips[who], "Fizzle", Palette.BIRCH, 18)
		"wrap":
			o.float_text(_strips[who].slot_center_global(0) + Vector2(0, -50), "Wrap", Palette.PARCHMENT, 18)
		"recharge":
			_strips[who].recharge(duel.casters[who].wand.next_cast_tick)
		"end":
			_show_end(who)


func _on_damage(e: Dictionary) -> void:
	var who: int = e["who"]
	var o := _overlay
	var amount: float = e["amount"]
	match e["cause"]:
		"burn":
			_wizards[who].hit(Palette.BURN)
			o.add_damage("burn%d" % who, o.bodies[who] + Vector2(50, 20), amount, Palette.BURN, 20)
		"steam":
			_wizards[who].hit(Palette.STEAM)
			o.burst(o.bodies[who], Palette.STEAM, 110.0)
			o.float_text(o.bodies[who] + Vector2(0, -40), "STEAM -%d" % roundi(amount), Palette.STEAM, 32)
		_:
			_wizards[who].hit(Palette.PARCHMENT)
			o.add_damage("hit%d" % who, o.bodies[who], amount, Palette.PARCHMENT, 24)


func _show_end(winner: int) -> void:
	_ended = true
	_pause_button.disabled = true
	_inspect.visible = false
	_end_panel = PanelContainer.new()
	_end_panel.position = Vector2(80, 470)
	_end_panel.custom_minimum_size = Vector2(560, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_end_panel.add_child(box)
	var title := ""
	if dummy:
		title = "Training complete"
	elif winner == 0:
		title = "Victory"
	elif winner == 1:
		title = "Defeat"
	else:
		title = "Draw"
	box.add_child(UiKit.label(title, 40))
	for line in DuelSummary.highlights(duel, dummy):
		box.add_child(UiKit.label(line, 22))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var again := UiKit.button("Watch again", _restart)
	again.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(again)
	var go := UiKit.button(continue_text, func() -> void: finished.emit(winner))
	go.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(go)
	add_child(_end_panel)
