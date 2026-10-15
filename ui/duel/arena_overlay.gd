class_name ArenaOverlay
extends Control
## Draws everything that moves between the wizards: projectiles in flight,
## floating text, and bursts for hits, freezes, Steam, Shock and reflects.

const TEXT_SECONDS := 1.1
const BURST_SECONDS := 0.5

var duel: Duel
## Global positions: wand tip each caster fires from, and body each is hit at.
var tips: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var bodies: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var now := 0.0
## Fractional tick, for smooth flight between sim steps.
var tick_f := 0.0
var selected_uid := -1

var _texts: Array[Dictionary] = []
var _bursts: Array[Dictionary] = []


func float_text(at: Vector2, text: String, color: Color, size := 22) -> void:
	var stacked := 0
	for t in _texts:
		if now - t["t"] < 0.6 and t.get("anchor", t["at"]).distance_to(at) < 90.0:
			stacked += 1
	_texts.append({"at": at + Vector2(0, -34 * stacked), "anchor": at, "text": text, "color": color, "size": size, "t": now})


## Hits on the same target within a moment merge into one growing number.
func add_damage(key: String, at: Vector2, amount: float, color: Color, size := 22) -> void:
	for t in _texts:
		if t.get("key", "") == key and now - t["t"] < 0.3:
			t["amount"] += amount
			t["text"] = _damage_text(t["amount"])
			t["size"] = size + mini(18, roundi(t["amount"] * 0.4))
			return
	_texts.append({"at": at, "text": _damage_text(amount), "color": color, "size": size + mini(18, roundi(amount * 0.4)),
		"t": now, "key": key, "amount": amount})


func _damage_text(amount: float) -> String:
	return "-%d" % roundi(amount) if amount >= 1.0 else "-%.1f" % amount


func burst(at: Vector2, color: Color, radius := 50.0) -> void:
	_bursts.append({"at": at, "color": color, "r": radius, "t": now})


func shot_position(s: Shot) -> Vector2:
	var span := maxf(1.0, float(s.arrive_tick - s.launch_tick))
	var k := clampf((tick_f - s.launch_tick) / span, 0.0, 1.0)
	var from := tips[s.source]
	var to := bodies[s.target]
	var lateral := float((s.uid * 7) % 5 - 2) * 22.0
	var normal := (to - from).orthogonal().normalized()
	return from.lerp(to, k) + normal * lateral * sin(PI * k)


func shot_at(global_point: Vector2) -> Shot:
	var best: Shot = null
	var best_d := 40.0
	for s in duel.in_flight:
		var d := (shot_position(s) - global_position).distance_to(global_point - global_position)
		if d < best_d:
			best_d = d
			best = s
	return best


func _process(_delta: float) -> void:
	_texts = _texts.filter(func(t: Dictionary) -> bool: return now - t["t"] < TEXT_SECONDS)
	_bursts = _bursts.filter(func(b: Dictionary) -> bool: return now - b["t"] < BURST_SECONDS)
	queue_redraw()


func _draw() -> void:
	if duel == null:
		return
	for b in _bursts:
		var k: float = (now - b["t"]) / BURST_SECONDS
		var col: Color = b["color"]
		col.a = 0.8 * (1.0 - k)
		draw_arc(b["at"] - global_position, b["r"] * (0.4 + k), 0, TAU, 32, col, 6.0 * (1.0 - k) + 1.0)
	for s in duel.in_flight:
		_draw_shot(s)
	for t in _texts:
		var k: float = (now - t["t"]) / TEXT_SECONDS
		var col: Color = t["color"]
		col.a = 1.0 - k * k
		Palette.draw_text_outlined(self, t["at"] - global_position + Vector2(0, -40.0 * k), t["text"], t["size"], col)


func _draw_shot(s: Shot) -> void:
	var p := shot_position(s) - global_position
	var col := Palette.element_color(s.burn, s.chill, s.wet, s.shock)
	if s.mana_drain > 0 or s.silence > 0:
		col = Palette.TYPE_COLORS["Disruption"]
	var r := 6.0 + clampf(s.damage * s.damage_mult, 0.0, 30.0) * 0.4
	var dir := (bodies[s.target] - tips[s.source]).normalized()
	for i in range(1, 4):
		draw_circle(p - dir * r * 1.1 * i, r * (1.0 - 0.22 * i), Color(col, 0.5 - 0.12 * i))
	if s.pierce > 0:
		draw_colored_polygon(PackedVector2Array([p + dir * r * 2.2, p + dir.orthogonal() * r, p - dir.orthogonal() * r]), Palette.PARCHMENT)
	draw_circle(p, r + 2.0, Palette.INK)
	draw_circle(p, r, col)
	if s.bounces > 0:
		draw_arc(p, r + 5.0, 0, TAU, 16, Palette.WARD, 2.0)
	if not s.payload.is_empty():
		draw_circle(p, r * 0.45, Palette.element_color(s.payload[0].burn, s.payload[0].chill, s.payload[0].wet, s.payload[0].shock))
		draw_arc(p, r * 0.6, 0, TAU, 12, Palette.INK, 2.0)
	var n := s.mod_ids.size()
	for i in n:
		var a := now * 6.0 + TAU * i / n
		draw_circle(p + Vector2.from_angle(a) * (r + 7.0), 4.0, Palette.TYPE_COLORS["Modifier"])
	if s.uid == selected_uid:
		draw_arc(p, r + 12.0, 0, TAU, 24, Palette.PARCHMENT, 3.0)
