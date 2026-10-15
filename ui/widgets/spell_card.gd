class_name SpellCard
extends Control
## A 2:3 spell card laid out as the art guide's card anatomy, drawn with
## placeholder shapes until card art exists.

signal tapped(card: SpellCard)

var spell: SpellDef
var selected := false
var badge := ""


func _init(p_spell: SpellDef = null, card_size := Vector2(128, 192)) -> void:
	spell = p_spell
	custom_minimum_size = card_size
	size = card_size
	mouse_filter = MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if Rect2(Vector2.ZERO, size).has_point(event.position):
			tapped.emit(self)


func _draw() -> void:
	if spell == null:
		return
	var s := size
	var r := Rect2(Vector2.ZERO, s)
	if selected:
		draw_rect(r.grow(5), Palette.PARCHMENT)
	draw_rect(r, Palette.type_color(spell))
	var inner := r.grow(-s.x * 0.05)
	draw_rect(inner, Palette.PARCHMENT)
	var art := Rect2(inner.position + Vector2(inner.size.x * 0.12, inner.size.y * 0.04), Vector2(inner.size.x * 0.76, inner.size.x * 0.76))
	Palette.draw_spell_icon(self, art, spell)

	var name_y := art.end.y + s.y * 0.07
	draw_rect(Rect2(Vector2(inner.position.x, art.end.y + s.y * 0.015), Vector2(inner.size.x, s.y * 0.11)), Palette.BARK)
	var fs := maxi(10, int(s.y * 0.07))
	draw_string(Palette.font(), Vector2(inner.position.x, name_y), spell.display_name, HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, fs, Palette.PARCHMENT)
	var body := maxi(9, int(s.y * 0.058))
	draw_multiline_string(Palette.font(), Vector2(inner.position.x + 4, name_y + s.y * 0.1), spell.description,
		HORIZONTAL_ALIGNMENT_LEFT, inner.size.x - 8, body, 4, Palette.INK)

	var gem := Vector2(s.x * 0.13, s.x * 0.13)
	draw_circle(gem, s.x * 0.12, Palette.INK)
	draw_circle(gem, s.x * 0.1, Palette.MANA)
	Palette.draw_text_centered(self, gem, str(spell.mana_cost), maxi(10, int(s.x * 0.12)), Palette.PARCHMENT)
	var rg := Vector2(s.x * 0.5, s.y - s.x * 0.06)
	draw_circle(rg, s.x * 0.06, Palette.INK)
	draw_circle(rg, s.x * 0.045, Palette.RARITY_COLORS[spell.rarity])
	draw_rect(r, Palette.INK, false, 3.0)
	if badge != "":
		var b := Vector2(s.x - s.x * 0.13, s.x * 0.13)
		draw_circle(b, s.x * 0.12, Palette.INK)
		Palette.draw_text_centered(self, b, badge, maxi(10, int(s.x * 0.11)), Palette.PARCHMENT)
