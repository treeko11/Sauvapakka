class_name WandStrip
extends Control
## One wizard's wand during a duel: slots in order, the draw pointer, drawn spells
## lifting and glowing, skipped spells flashing, mana and recharge bars.

const LIFT_SECONDS := 0.45
const LIFT_PX := 14.0

var duel: Duel
var caster_index := 0
## Seconds of duel time, as the screen shows it (fractional ticks included).
var now := 0.0

var _lift_at := {} # slot -> time drawn
var _flash := {} # slot -> [time, color]
var _recharge_from := -1.0
var _recharge_to := -1.0


func _wand() -> WandState:
	return duel.casters[caster_index].wand


func lift(slots: Array) -> void:
	for s in slots:
		_lift_at[s] = now


func flash(slot: int, color: Color) -> void:
	_flash[slot] = [now, color]


func recharge(until_tick: int) -> void:
	_recharge_from = now
	_recharge_to = until_tick * Duel.TICK


func slot_rect(i: int) -> Rect2:
	var n := maxi(1, _wand().slots.size())
	var gap := 6.0
	var side := minf(84.0, (size.x - gap * (n - 1)) / n)
	var total := side * n + gap * (n - 1)
	var x0 := (size.x - total) * 0.5
	return Rect2(Vector2(x0 + i * (side + gap), 26.0), Vector2(side, side))


func slot_center_global(i: int) -> Vector2:
	return global_position + slot_rect(i).get_center()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if duel == null:
		return
	var w := _wand()
	draw_rect(Rect2(Vector2.ZERO, size), Palette.BIRCH.darkened(0.55))
	draw_string(Palette.font(), Vector2(8, 18), w.frame.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.PARCHMENT)

	var mana_frac := w.mana / maxf(1.0, w.frame.mana_max)
	var bar := Rect2(Vector2(size.x * 0.45, 8), Vector2(size.x * 0.5, 10))
	draw_rect(bar, Palette.INK)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * mana_frac, bar.size.y)), Palette.MANA)

	var next_slot := w.order[w.pointer] if w.pointer < w.order.size() else -1
	for i in w.slots.size():
		var r := slot_rect(i)
		var t: float = now - _lift_at.get(i, -99.0)
		var k := 0.0
		if t >= 0.0 and t < LIFT_SECONDS:
			k = sin(PI * t / LIFT_SECONDS)
		r.position.y -= LIFT_PX * k
		var sp := w.slots[i]
		if sp == null:
			draw_rect(r, Palette.INK.lightened(0.1))
			draw_rect(r, Palette.BARK, false, 2.0)
		else:
			if k > 0.0:
				draw_rect(r.grow(5.0 * k + 2.0), Palette.spell_color(sp) * Color(1, 1, 1, k))
			Palette.draw_spell_icon(self, r, sp)
		if _flash.has(i):
			var ft: float = now - _flash[i][0]
			if ft < 0.6:
				var col: Color = _flash[i][1]
				col.a = 0.7 * (1.0 - ft / 0.6)
				draw_rect(r, col)
		if i == next_slot:
			var p := Vector2(r.get_center().x, r.end.y + 10)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -8), p + Vector2(-9, 6), p + Vector2(9, 6)]), Palette.PARCHMENT)

	if _recharge_to > now and _recharge_to > _recharge_from:
		var f := (now - _recharge_from) / (_recharge_to - _recharge_from)
		var rb := Rect2(Vector2(size.x * 0.05, size.y - 8), Vector2(size.x * 0.9, 5))
		draw_rect(rb, Palette.INK)
		draw_rect(Rect2(rb.position, Vector2(rb.size.x * f, rb.size.y)), Palette.PARCHMENT)
		Palette.draw_text_outlined(self, Vector2(size.x * 0.5, size.y - 20), "Recharging", 14, Palette.PARCHMENT)
