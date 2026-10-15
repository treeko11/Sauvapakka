class_name SlotView
extends Control
## One wand slot in the Workshop: a socket, or the icon of the spell in it.

var spell: SpellDef
var selected := false
var index := 0


func _init(p_spell: SpellDef, side: float) -> void:
	spell = p_spell
	custom_minimum_size = Vector2(side, side)
	size = custom_minimum_size
	mouse_filter = MOUSE_FILTER_STOP


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if selected:
		draw_rect(r.grow(4), Palette.PARCHMENT)
	if spell == null:
		draw_rect(r, Palette.INK.lightened(0.1))
		draw_rect(r.grow(-6), Palette.BARK, false, 2.0)
		Palette.draw_text_centered(self, r.get_center(), str(index + 1), int(size.y * 0.3), Palette.BARK.lightened(0.3))
	else:
		Palette.draw_spell_icon(self, r, spell)
