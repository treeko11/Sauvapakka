class_name RunEndScreen
extends Control
## The end of a run, won or lost, with its highlights.

var flow: RunFlow


func _init(p_flow: RunFlow) -> void:
	flow = p_flow


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	UiKit.background(self)
	var run := flow.run
	var box := VBoxContainer.new()
	box.position = Vector2(60, 160)
	box.custom_minimum_size = Vector2(600, 0)
	box.add_theme_constant_override("separation", 18)
	add_child(box)
	var won := run.phase == RunState.Phase.WON
	box.add_child(UiKit.label("The Archmage falls!" if won else "Defeated", 52, Palette.PARCHMENT))
	if not won:
		box.add_child(UiKit.label("%s beat you in fight %d of %d." % [run.current_fight()["def"].display_name,
			run.fight_index + 1, run.fights.size()], 24, Palette.BIRCH))
	var wins := run.results.filter(func(r: Dictionary) -> bool: return r["winner"] == 0).size()
	var biggest := 0.0
	var biggest_spell := ""
	var total := 0.0
	for r in run.results:
		total += r["seconds"]
		if r["biggest"] > biggest:
			biggest = r["biggest"]
			biggest_spell = String(r["biggest_spell"])
	box.add_child(UiKit.label("Fights won: %d" % wins, 26))
	box.add_child(UiKit.label("Time in duels: %d:%02d" % [int(total) / 60, int(total) % 60], 26))
	if biggest > 0.0:
		box.add_child(UiKit.label("Biggest hit: %d (%s)" % [roundi(biggest), run.db.get_spell(biggest_spell).display_name], 26))
	box.add_child(UiKit.label("Spell book: %d spells" % run.book_size(), 26))
	if not run.discoveries.is_empty():
		box.add_child(UiKit.label("Interactions found:", 26, Palette.BIRCH))
		for k in run.discoveries:
			box.add_child(UiKit.label("  " + DuelSummary.INTERACTIONS[k], 22))
	var back := UiKit.button("Main menu", flow.app.show_menu, Vector2(600, 80))
	back.position = Vector2(60, 1280 - 120)
	add_child(back)
