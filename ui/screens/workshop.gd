class_name Workshop
extends Control
## Build wands from the hand: wands stacked above, the hand below. Drag spells
## between hand and slots, or tap a spell and then tap where it goes.

var flow: RunFlow
var run: RunState

var _selected := {} # {"from": "hand", "i": int} or {"from": "slot", "w": int, "s": int}
var _content: Control
var _info: Label


func _init(p_flow: RunFlow) -> void:
	flow = p_flow
	run = p_flow.run


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	UiKit.background(self)
	_content = Control.new()
	_content.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_content.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_content)
	refresh()


func refresh() -> void:
	for c in _content.get_children():
		c.queue_free()
	var f := run.current_fight()
	var head := UiKit.label("Fight %d of %d: %s" % [run.fight_index + 1, run.fights.size(), f["def"].display_name], 28, Palette.PARCHMENT, false)
	head.position = Vector2(24, 16)
	_content.add_child(head)
	var tags := UiKit.label(" · ".join(run.enemy_traits()), 20, Palette.BIRCH, false)
	tags.position = Vector2(24, 54)
	_content.add_child(tags)

	var y := 96.0
	for wi in run.wands.size():
		y = _add_wand(wi, y) + 14.0
	_info = UiKit.label(_info_text(), 20, Palette.BIRCH)
	_info.position = Vector2(24, y)
	_info.size = Vector2(672, 60)
	_content.add_child(_info)

	var hand_y := 1280.0 - 96.0 - 200.0
	var hand_area := ColorRect.new()
	hand_area.color = Palette.NIGHT.darkened(0.3)
	hand_area.position = Vector2(0, hand_y - 40)
	hand_area.size = Vector2(720, 236)
	hand_area.set_drag_forwarding(Callable(), _can_drop_hand, _drop_hand)
	hand_area.gui_input.connect(_on_hand_area_input)
	_content.add_child(hand_area)
	var hl := UiKit.label("Hand (%d in draw pool, %d stashed)" % [run.library.size(), run.stash.size()], 20, Palette.BIRCH, false)
	hl.position = Vector2(24, hand_y - 36)
	_content.add_child(hl)
	var n := run.hand.size()
	var card_w := 128.0
	var gap := 10.0
	var x0 := (720.0 - (n * card_w + maxi(0, n - 1) * gap)) * 0.5
	for i in n:
		var card := SpellCard.new(run.db.get_spell(run.hand[i]))
		card.position = Vector2(x0 + i * (card_w + gap), hand_y)
		card.selected = _selected.get("from") == "hand" and _selected.get("i") == i
		card.set_drag_forwarding(_drag_hand.bind(i), _can_drop_hand, _drop_hand)
		card.tapped.connect(func(_c: SpellCard) -> void: _tap_hand(i))
		_content.add_child(card)

	var row := HBoxContainer.new()
	row.position = Vector2(24, 1280 - 84)
	row.size = Vector2(672, 72)
	row.add_theme_constant_override("separation", 12)
	_content.add_child(row)
	for b in [UiKit.button("Spell book", flow.show_book), UiKit.button("Ready", flow.show_choose)]:
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(b)


func _add_wand(wi: int, y: float) -> float:
	var w := run.wands[wi]
	var title := UiKit.label("%s: %s" % [w.display_name, w.frame.display_name], 22, Palette.PARCHMENT, false)
	title.position = Vector2(24, y)
	_content.add_child(title)
	var test := UiKit.button("Test", flow.test_wand.bind(wi), Vector2(110, 44))
	test.position = Vector2(586, y - 4)
	test.disabled = run.wand_is_empty(wi)
	_content.add_child(test)
	var stats := UiKit.label(FrameGen.describe(w.frame) + RuleText.frame_rule(w.frame, ". "), 15, Palette.BIRCH)
	stats.position = Vector2(24, y + 30)
	stats.size = Vector2(560, 40)
	_content.add_child(stats)
	var cap := w.frame.capacity
	var gap := 6.0
	var side := minf(80.0, (672.0 - gap * (cap - 1)) / cap)
	for s in cap:
		var sid := w.spell_ids[s] if s < w.spell_ids.size() else ""
		var sv := SlotView.new(run.db.get_spell(sid) if sid != "" else null, side)
		sv.index = s
		sv.position = Vector2(24 + s * (side + gap), y + 72)
		sv.selected = _selected.get("from") == "slot" and _selected.get("w") == wi and _selected.get("s") == s
		sv.set_drag_forwarding(_drag_slot.bind(wi, s), _can_drop_slot, _drop_slot.bind(wi, s))
		sv.gui_input.connect(_on_slot_input.bind(wi, s))
		_content.add_child(sv)
	return y + 72 + side


func _info_text() -> String:
	var sid := ""
	match _selected.get("from", ""):
		"hand":
			sid = run.hand[_selected["i"]]
		"slot":
			sid = run.wands[_selected["w"]].spell_ids[_selected["s"]]
	if sid == "":
		return "Drag spells into slots, or tap a spell and then a slot. Spells in wands stay there between fights."
	var sp := run.db.get_spell(sid)
	return "%s (%s, %d mana): %s" % [sp.display_name, sp.type_label, sp.mana_cost, sp.description]


# --- Drag and drop -------------------------------------------------------------

func _drag_hand(_at: Vector2, i: int) -> Variant:
	var preview := SpellCard.new(run.db.get_spell(run.hand[i]), Vector2(96, 144))
	set_drag_preview(preview)
	return {"from": "hand", "i": i}


func _drag_slot(_at: Vector2, wi: int, s: int) -> Variant:
	var sid := run.wands[wi].spell_ids[s]
	if sid == "":
		return null
	var preview := SlotView.new(run.db.get_spell(sid), 72)
	set_drag_preview(preview)
	return {"from": "slot", "w": wi, "s": s}


func _can_drop_slot(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("from")


func _drop_slot(_at: Vector2, data: Variant, wi: int, s: int) -> void:
	_apply(data, {"to": "slot", "w": wi, "s": s})


func _can_drop_hand(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("from") == "slot"


func _drop_hand(_at: Vector2, data: Variant) -> void:
	_apply(data, {"to": "hand"})


func _apply(from: Dictionary, to: Dictionary) -> void:
	if to["to"] == "hand":
		if from["from"] == "slot":
			run.unslot(from["w"], from["s"])
	elif from["from"] == "hand":
		run.place_from_hand(from["i"], to["w"], to["s"])
	else:
		run.move_slot(from["w"], from["s"], to["w"], to["s"])
	_selected = {}
	refresh.call_deferred()


# --- Tap to select ---------------------------------------------------------------

func _tap_hand(i: int) -> void:
	if _selected.get("from") == "hand" and _selected.get("i") == i:
		_selected = {}
	elif _selected.get("from") == "slot":
		_apply(_selected, {"to": "hand"})
		return
	else:
		_selected = {"from": "hand", "i": i}
	refresh()


func _on_slot_input(event: InputEvent, wi: int, s: int) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed):
		return
	if _selected.is_empty():
		if run.wands[wi].spell_ids[s] != "":
			_selected = {"from": "slot", "w": wi, "s": s}
			refresh.call_deferred()
		return
	if _selected.get("from") == "slot" and _selected["w"] == wi and _selected["s"] == s:
		_selected = {}
		refresh.call_deferred()
		return
	_apply(_selected, {"to": "slot", "w": wi, "s": s})


func _on_hand_area_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if _selected.get("from") == "slot":
			_apply(_selected, {"to": "hand"})
