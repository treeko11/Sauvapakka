class_name Chips
extends HFlowContainer
## A wrapping row of tag chips, for traits.


func _init(tags: PackedStringArray, color := Palette.BARK) -> void:
	add_theme_constant_override("h_separation", 8)
	add_theme_constant_override("v_separation", 8)
	for t in tags:
		var p := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = color
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		p.add_theme_stylebox_override("panel", sb)
		p.add_child(UiKit.label(t, 20, Palette.PARCHMENT, false))
		add_child(p)
