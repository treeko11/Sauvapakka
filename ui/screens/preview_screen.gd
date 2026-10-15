class_name PreviewScreen
extends Control
## The next enemy: portrait and trait tags, not its wand.

var flow: RunFlow


func _init(p_flow: RunFlow) -> void:
	flow = p_flow


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	UiKit.background(self)
	var run := flow.run
	var f := run.current_fight()
	var def: EnemyDef = f["def"]
	var box := VBoxContainer.new()
	box.position = Vector2(60, 70)
	box.custom_minimum_size = Vector2(600, 0)
	box.add_theme_constant_override("separation", 18)
	add_child(box)
	box.add_child(_progress(run))
	var kind := "Boss" if f["boss"] else ("Themed" if def.themed else "Wizard")
	box.add_child(UiKit.label("%s  ·  Fight %d of %d" % [kind, run.fight_index + 1, run.fights.size()], 22, Palette.BIRCH, false))
	box.add_child(UiKit.label(def.display_name, 52, Palette.PARCHMENT, false))
	var portrait := Portrait.new()
	portrait.custom_minimum_size = Vector2(600, 520)
	portrait.robe = def.robe
	portrait.boss = f["boss"]
	box.add_child(portrait)
	box.add_child(UiKit.label("Traits", 22, Palette.BIRCH, false))
	box.add_child(Chips.new(run.enemy_traits()))
	if f["boss"]:
		box.add_child(UiKit.label("A 60-second fight that keeps escalating. You bring one wand.", 20, Palette.BIRCH))
	var go := UiKit.button("Draw hand", flow.start_workshop, Vector2(600, 80))
	go.position = Vector2(60, 1280 - 120)
	add_child(go)


func _progress(run: RunState) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for i in run.fights.size():
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(70 if i == run.fights.size() - 1 else 56, 14)
		if i < run.fight_index:
			dot.color = Palette.PARCHMENT
		elif i == run.fight_index:
			dot.color = Palette.BURN
		else:
			dot.color = Palette.BARK
		row.add_child(dot)
	return row
