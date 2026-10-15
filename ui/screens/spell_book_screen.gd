class_name SpellBookScreen
extends Control
## The whole spell book: stash spells out of the draw pool, pin spells to the
## opening hand, and spend Removal charges.

var flow: RunFlow
var _list: VBoxContainer
var _header: Label


func _init(p_flow: RunFlow) -> void:
	flow = p_flow


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	UiKit.background(self)
	var title := UiKit.label("Spell book", 44, Palette.PARCHMENT, false)
	title.position = Vector2(24, 20)
	add_child(title)
	_header = UiKit.label("", 20, Palette.BIRCH)
	_header.position = Vector2(24, 80)
	_header.size = Vector2(672, 60)
	add_child(_header)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(16, 150)
	scroll.size = Vector2(688, 1280 - 150 - 110)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(672, 0)
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	var back := UiKit.button("Back to workshop", flow.show_workshop, Vector2(672, 72))
	back.position = Vector2(24, 1280 - 96)
	add_child(back)
	refresh()


func refresh() -> void:
	var run := flow.run
	_header.text = "%d spells. Removal charges: %d. Pinned: %d of %d (always in your opening hand)." % [
		run.book_size(), run.removals, run.pinned.size(), run.pin_slots]
	for c in _list.get_children():
		c.queue_free()
	_section("Draw pool", run.library, "library")
	_section("In hand", run.hand, "hand")
	_section("Stash", run.stash, "stash")
	var slotted: Array[String] = []
	for w in run.wands:
		for sid in w.spell_ids:
			if sid != "":
				slotted.append(sid)
	_section("In wands", slotted, "wand")


func _section(title: String, ids: Array[String], where: String) -> void:
	if ids.is_empty():
		return
	_list.add_child(UiKit.label("%s (%d)" % [title, ids.size()], 24, Palette.BIRCH, false))
	var counts := {}
	for sid in ids:
		counts[sid] = counts.get(sid, 0) + 1
	var keys := counts.keys()
	keys.sort()
	for sid in keys:
		_list.add_child(_row(sid, counts[sid], where))


func _row(sid: String, count: int, where: String) -> Control:
	var run := flow.run
	var sp := run.db.get_spell(sid)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(SlotView.new(sp, 56))
	var name := UiKit.label("%s%s\n%s" % [sp.display_name, " ×%d" % count if count > 1 else "", sp.description], 17, Palette.PARCHMENT)
	name.custom_minimum_size = Vector2(300, 0)
	name.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(name)
	var small := Vector2(0, 52)
	match where:
		"library":
			var pinned := run.pinned.has(sid)
			var pin := UiKit.button("Unpin" if pinned else "Pin", _do.bind(run.unpin_spell if pinned else run.pin_spell, sid), small)
			pin.disabled = not pinned and run.pinned.size() >= run.pin_slots
			row.add_child(pin)
			row.add_child(UiKit.button("Stash", _do.bind(run.stash_spell, sid), small))
			row.add_child(_remove_button(sid))
		"stash":
			row.add_child(UiKit.button("Return", _do.bind(run.unstash_spell, sid), small))
			row.add_child(_remove_button(sid))
	return row


func _remove_button(sid: String) -> Button:
	var b := UiKit.button("Remove", _do.bind(flow.run.remove_spell, sid), Vector2(0, 52))
	b.disabled = flow.run.removals <= 0
	return b


func _do(action: Callable, sid: String) -> void:
	action.call(sid)
	refresh.call_deferred()
