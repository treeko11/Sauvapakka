class_name WizardPanel
extends Control
## One wizard: body, HP bar, and status counters read live from the duel.

var duel: Duel
var caster_index := 0
var facing := 1.0
var robe := Palette.PLAYER_ROBE
var now := 0.0
## Wizards drawn as a target dummy hide HP and show damage taken instead.
var dummy := false

var _hit_at := -99.0
var _hit_color := Color.WHITE
var _shield_at := -99.0


func hit(color: Color) -> void:
	_hit_at = now
	_hit_color = color


func shield() -> void:
	_shield_at = now


func body_center_global() -> Vector2:
	return global_position + Vector2(_feet().x, _feet().y - _height() * 0.45)


func wand_tip_global() -> Vector2:
	var f := _feet()
	var h := _height()
	return global_position + Vector2(f.x + facing * (h * 0.42 * 0.35 + h * 0.22), f.y - h * 0.52)


func _height() -> float:
	return size.y * 0.8


func _feet() -> Vector2:
	return Vector2(size.x * (0.3 if facing > 0 else 0.7), size.y * 0.92)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if duel == null:
		return
	var c := duel.casters[caster_index]
	var feet := _feet()
	var h := _height()
	var body := Vector2(feet.x, feet.y - h * 0.45)

	var st := now - _shield_at
	if c.wards > 0 or c.reflects > 0 or st < 0.4:
		var a := 0.35 + (0.5 * (1.0 - st / 0.4) if st < 0.4 else 0.0)
		draw_arc(body, h * 0.55, 0, TAU, 40, Color(Palette.WARD, a), 4.0)

	var robe_col := robe
	if c.frozen:
		robe_col = robe.lerp(Palette.FROZEN, 0.6)
	if dummy:
		_draw_dummy(feet, h)
	else:
		Palette.draw_wizard(self, feet, h, robe_col, facing, robe_col.darkened(0.3))
	if c.frozen:
		draw_rect(Rect2(feet - Vector2(h * 0.3, h * 0.95), Vector2(h * 0.6, h * 0.95)), Color(Palette.FROZEN, 0.35))
		draw_rect(Rect2(feet - Vector2(h * 0.3, h * 0.95), Vector2(h * 0.6, h * 0.95)), Palette.CHILL, false, 3.0)

	var ht := now - _hit_at
	if ht < 0.25:
		draw_circle(body, h * 0.3 * (1.0 + ht * 2.0), Color(_hit_color, 0.5 * (1.0 - ht / 0.25)))

	var info_x := size.x * (0.55 if facing > 0 else 0.05)
	var info_w := size.x * 0.4
	draw_string(Palette.font(), Vector2(info_x, 24), c.name, HORIZONTAL_ALIGNMENT_LEFT, info_w, 20, Palette.PARCHMENT)
	if dummy:
		var taken := c.max_hp - c.hp
		var secs := maxf(duel.seconds(), 0.05)
		draw_string(Palette.font(), Vector2(info_x, 54), "Damage %d   DPS %.1f" % [roundi(taken), taken / secs],
			HORIZONTAL_ALIGNMENT_LEFT, info_w, 18, Palette.PARCHMENT)
	else:
		var bar := Rect2(Vector2(info_x, 34), Vector2(info_w, 18))
		draw_rect(bar, Palette.INK)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(c.hp / c.max_hp, 0.0, 1.0), bar.size.y)), Palette.HP)
		Palette.draw_text_outlined(self, bar.get_center(), "%d / %d" % [maxi(0, ceili(c.hp)), roundi(c.max_hp)], 14, Palette.PARCHMENT)

	var tokens: Array = []
	if c.burn > 0:
		tokens.append(["burn", c.burn])
	if c.frozen:
		tokens.append(["frozen", 1])
	elif c.chill > 0:
		tokens.append(["chill", c.chill])
	if c.wet > 0:
		tokens.append(["wet", c.wet])
	if c.shock > 0:
		tokens.append(["shock", c.shock])
	if c.wards > 0:
		tokens.append(["ward", c.wards])
	if c.reflects > 0:
		tokens.append(["reflect", c.reflects])
	if c.silence > 0:
		tokens.append(["silence", c.silence])
	for i in tokens.size():
		var p := Vector2(info_x + 20 + i * 44, 82)
		Palette.draw_token(self, tokens[i][0], p, 18, tokens[i][1])


func _draw_dummy(feet: Vector2, h: float) -> void:
	draw_rect(Rect2(feet + Vector2(-6, -h * 0.9), Vector2(12, h * 0.9)), Palette.BARK)
	draw_rect(Rect2(feet + Vector2(-h * 0.25, -h * 0.75), Vector2(h * 0.5, 12)), Palette.BARK)
	draw_circle(feet + Vector2(0, -h * 0.5), h * 0.22, Palette.PARCHMENT)
	draw_circle(feet + Vector2(0, -h * 0.5), h * 0.14, Palette.HP)
	draw_circle(feet + Vector2(0, -h * 0.5), h * 0.06, Palette.PARCHMENT)
