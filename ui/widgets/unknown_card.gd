class_name UnknownCard
extends Control
## A spell not found yet: the card's outline and a question mark.


func _init(card_size: Vector2) -> void:
	custom_minimum_size = card_size


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Palette.NIGHT.darkened(0.35))
	draw_rect(r, Palette.BARK, false, 3.0)
	Palette.draw_text_centered(self, r.get_center(), "?", int(size.y * 0.3), Palette.BARK.lightened(0.2))
