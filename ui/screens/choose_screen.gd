class_name ChooseScreen
extends Control
## Tap the wand to take into the fight.

var flow: RunFlow


func _init(p_flow: RunFlow) -> void:
	flow = p_flow


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	UiKit.background(self)
	var run := flow.run
	var box := VBoxContainer.new()
	box.position = Vector2(40, 40)
	box.custom_minimum_size = Vector2(640, 0)
	box.add_theme_constant_override("separation", 16)
	add_child(box)
	box.add_child(UiKit.label("Choose a wand", 44, Palette.PARCHMENT, false))
	box.add_child(UiKit.label("vs %s" % run.current_fight()["def"].display_name, 24, Palette.BIRCH, false))
	box.add_child(Chips.new(run.enemy_traits(), Palette.HP.darkened(0.3)))
	for wi in run.wands.size():
		box.add_child(_wand_card(wi))
	var back := UiKit.button("Back to workshop", flow.show_workshop, Vector2(640, 72))
	back.position = Vector2(40, 1280 - 100)
	add_child(back)


func _wand_card(wi: int) -> Control:
	var run := flow.run
	var w := run.wands[wi]
	var panel := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(UiKit.label("%s: %s" % [w.display_name, w.frame.display_name], 24, Palette.PARCHMENT, false))
	var icons := HBoxContainer.new()
	icons.add_theme_constant_override("separation", 4)
	for s in w.spell_ids.size():
		var sid := w.spell_ids[s]
		var sv := SlotView.new(run.db.get_spell(sid) if sid != "" else null, 52)
		sv.index = s
		icons.add_child(sv)
	v.add_child(icons)
	var empty := run.wand_is_empty(wi)
	if not empty:
		v.add_child(Chips.new(EnemyGen.traits(w, run.db)))
	var take := UiKit.button("Empty wand" if empty else "Take this wand", flow.fight.bind(wi), Vector2(0, 60))
	take.disabled = empty
	v.add_child(take)
	return panel
