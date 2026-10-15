class_name CompendiumScreen
extends Control
## Every spell found and every interaction discovered, across all runs.

var app: App


func _init(p_app: App) -> void:
	app = p_app


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	UiKit.background(self)
	var p := app.profile
	var all := app.db.all()
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 20)
	scroll.size = Vector2(680, 1280 - 20 - 110)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(664, 0)
	box.add_theme_constant_override("separation", 14)
	scroll.add_child(box)
	box.add_child(UiKit.label("Compendium", 44, Palette.PARCHMENT, false))
	var found := all.filter(func(s: SpellDef) -> bool: return p.spells_found.has(String(s.id))).size()
	box.add_child(UiKit.label("Runs %d · Wins %d · Furthest fight %d of 7 · Spells found %d of %d" % [
		p.runs, p.wins, p.best_fight, found, all.size()], 20, Palette.BIRCH))
	box.add_child(UiKit.label("Interactions", 28, Palette.PARCHMENT, false))
	for k in DuelSummary.INTERACTIONS:
		var known: bool = p.interactions.has(k)
		box.add_child(UiKit.label(DuelSummary.INTERACTIONS[k] if known else "??? (not discovered yet)", 20,
			Palette.PARCHMENT if known else Palette.BARK.lightened(0.3)))
	box.add_child(UiKit.label("Spells", 28, Palette.PARCHMENT, false))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	var card := Vector2(156, 234)
	for s in all:
		var c: Control = SpellCard.new(s, card) if p.spells_found.has(String(s.id)) else UnknownCard.new(card)
		c.mouse_filter = MOUSE_FILTER_PASS
		grid.add_child(c)
	var back := UiKit.button("Back", app.show_menu, Vector2(680, 72))
	back.position = Vector2(20, 1280 - 92)
	add_child(back)
