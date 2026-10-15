class_name RewardScreen
extends Control
## Pick 1 of 3 spells; the enemy's drop and any frame come too.

var flow: RunFlow
var _pick := ""
var _frame_target := -2
var _cards: Array[SpellCard] = []
var _frame_buttons: Array[Button] = []
var _take: Button


func _init(p_flow: RunFlow) -> void:
	flow = p_flow


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	UiKit.background(self)
	var run := flow.run
	var box := VBoxContainer.new()
	box.position = Vector2(30, 30)
	box.custom_minimum_size = Vector2(660, 0)
	box.add_theme_constant_override("separation", 16)
	add_child(box)
	box.add_child(UiKit.label("Victory! Pick a spell", 40, Palette.PARCHMENT, false))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	for sid in run.reward_options:
		var card := SpellCard.new(run.db.get_spell(sid), Vector2(208, 312))
		card.size_flags_vertical = SIZE_SHRINK_BEGIN
		card.tapped.connect(_on_pick.bind(sid))
		row.add_child(card)
		_cards.append(card)
	box.add_child(row)
	if run.enemy_drop != "":
		var drop := HBoxContainer.new()
		drop.add_theme_constant_override("separation", 14)
		var card := SpellCard.new(run.db.get_spell(run.enemy_drop), Vector2(112, 168))
		card.size_flags_vertical = SIZE_SHRINK_BEGIN
		drop.add_child(card)
		var note := UiKit.label("Dropped by %s.\nIt goes into your spell book." % run.current_fight()["def"].display_name, 22, Palette.BIRCH)
		note.size_flags_horizontal = SIZE_EXPAND_FILL
		drop.add_child(note)
		box.add_child(drop)
	if run.frame_drop != null:
		box.add_child(_frame_section())
	_take = UiKit.button("Skip the pick", _confirm, Vector2(660, 80))
	_take.position = Vector2(30, 1280 - 110)
	add_child(_take)


func _frame_section() -> Control:
	var run := flow.run
	var f := run.frame_drop
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(UiKit.label("Frame found: %s" % f.display_name, 26, Palette.PARCHMENT, false))
	v.add_child(UiKit.label(FrameGen.describe(f) + RuleText.frame_rule(f, ". "), 18, Palette.BIRCH))
	var options: Array = [[-2, "Leave it"]]
	if run.wands.size() < RunState.MAX_WANDS:
		options.append([-1, "New wand"])
	for wi in run.wands.size():
		options.append([wi, "Replace %s" % run.wands[wi].frame.display_name])
	var flow_box := HFlowContainer.new()
	flow_box.add_theme_constant_override("h_separation", 8)
	flow_box.add_theme_constant_override("v_separation", 8)
	for o in options:
		var b := UiKit.button(o[1], _on_frame.bind(o[0]), Vector2(0, 56))
		b.toggle_mode = true
		b.button_pressed = o[0] == _frame_target
		flow_box.add_child(b)
		_frame_buttons.append(b)
	v.add_child(flow_box)
	v.add_child(UiKit.label("Replacing keeps the spells that fit; the rest go back to your spell book.", 16, Palette.BIRCH))
	return v


func _on_pick(_card: SpellCard, sid: String) -> void:
	_pick = "" if _pick == sid else sid
	for c in _cards:
		c.selected = String(c.spell.id) == _pick
		c.queue_redraw()
	_take.text = "Take %s" % flow.run.db.get_spell(_pick).display_name if _pick != "" else "Skip the pick"


func _on_frame(target: int) -> void:
	_frame_target = target
	var options := [-2]
	if flow.run.wands.size() < RunState.MAX_WANDS:
		options.append(-1)
	for wi in flow.run.wands.size():
		options.append(wi)
	for i in _frame_buttons.size():
		_frame_buttons[i].set_pressed_no_signal(options[i] == target)


func _confirm() -> void:
	flow.take_rewards(_pick, _frame_target)
