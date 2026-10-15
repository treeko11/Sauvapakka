class_name Portrait
extends Control
## Placeholder enemy portrait: the wizard silhouette in the archetype's colour.

var robe := Palette.ENEMY_ROBE
var facing := -1.0
var boss := false


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.NIGHT.darkened(0.3))
	var h := size.y * (0.95 if boss else 0.8)
	Palette.draw_wizard(self, Vector2(size.x * 0.5, size.y * 0.97), h, robe, facing, robe.darkened(0.35))
	draw_rect(Rect2(Vector2.ZERO, size), Palette.INK, false, 4.0)
