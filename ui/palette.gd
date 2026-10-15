class_name Palette
extends RefCounted
## Colours from the art style guide, plus placeholder drawing helpers shared by
## every screen until real art replaces them.

const INK := Color("1b1a24")
const NIGHT := Color("2a2d45")
const PARCHMENT := Color("f2e8d5")
const BIRCH := Color("d9d4c7")
const BARK := Color("5a4636")

const TYPE_COLORS := {
	"Projectile": Color("7c8ba6"),
	"Modifier": Color("8a63c9"),
	"Multicast": Color("3fa37a"),
	"Defence": Color("c7ced6"),
	"Disruption": Color("c2457e"),
	"Utility": Color("a8814b"),
}

const BURN := Color("f2662b")
const CHILL := Color("8fe3f5")
const FROZEN := Color("e6f7ff")
const WET := Color("2f6fd6")
const SHOCK := Color("f5d63b")
const STEAM := Color("d9d9d9")
const ARCANE := Color("b98cff")
const DISRUPT_TEXT := Color("e889b8")
const WARD := Color("c7ced6")
const HP := Color("d94a4a")
const MANA := Color("4f8fe0")

const RARITY_COLORS := [Color("8c8c8c"), Color("4fa86b"), Color("3d7fe0"), Color("e0a93d")]
const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Legendary"]

const PLAYER_ROBE := Color("3b3f8f")
const ENEMY_ROBE := Color("6b6b73")


static func type_color(spell: SpellDef) -> Color:
	return TYPE_COLORS.get(spell.type_label, TYPE_COLORS["Projectile"])


## The element a spell shows: the first status it carries, else arcane.
static func element_color(burn: int, chill: int, wet: int, shock: int) -> Color:
	if burn > 0:
		return BURN
	if chill > 0:
		return CHILL
	if wet > 0:
		return WET
	if shock > 0:
		return SHOCK
	return ARCANE


static func spell_color(spell: SpellDef) -> Color:
	return element_color(spell.burn, spell.chill, spell.wet, spell.shock)


## Two or three letters standing in for spell art.
static func abbrev(spell: SpellDef) -> String:
	var words := spell.display_name.split(" ")
	if words.size() == 1:
		return spell.display_name.left(2)
	var out := ""
	for w in words:
		out += w.left(1)
	return out.left(3)


static func font() -> Font:
	return ThemeDB.fallback_font


static func draw_text_centered(ci: CanvasItem, center: Vector2, text: String, size: int, color: Color) -> void:
	var f := font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(f, center + Vector2(-w * 0.5, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func draw_text_outlined(ci: CanvasItem, center: Vector2, text: String, size: int, color: Color) -> void:
	var f := font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := center + Vector2(-w * 0.5, size * 0.35)
	ci.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, INK)
	ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## A square slot icon: type colour, element glyph or letters, ink outline.
static func draw_spell_icon(ci: CanvasItem, rect: Rect2, spell: SpellDef, dim := false) -> void:
	var base := type_color(spell)
	if dim:
		base = base.darkened(0.5)
	ci.draw_rect(rect, base)
	var c := rect.get_center()
	var r := rect.size.x * 0.22
	if spell.kind == SpellDef.Kind.PROJECTILE:
		ci.draw_circle(c + Vector2(0, -r * 0.4), r, spell_color(spell))
	else:
		var glyph := _status_glyph(spell)
		if glyph != "":
			draw_glyph(ci, glyph, c + Vector2(0, -r * 0.4), r)
	var text_col := INK if base.get_luminance() > 0.6 else PARCHMENT
	var f := font()
	var fs := int(rect.size.y * 0.26)
	var label := abbrev(spell)
	var tp := c + Vector2(-f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5, rect.size.y * 0.27 + fs * 0.35)
	if text_col == PARCHMENT:
		ci.draw_string_outline(f, tp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, INK)
	ci.draw_string(f, tp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_col)
	ci.draw_rect(rect, INK, false, 3.0)


static func _status_glyph(spell: SpellDef) -> String:
	if spell.burn > 0:
		return "burn"
	if spell.chill > 0:
		return "chill"
	if spell.wet > 0:
		return "wet"
	if spell.shock > 0:
		return "shock"
	if spell.ward_hits > 0:
		return "ward"
	if spell.reflect_hits > 0:
		return "reflect"
	return ""


## Placeholder status glyphs, distinct by outline alone as the art guide asks.
static func draw_glyph(ci: CanvasItem, kind: String, c: Vector2, r: float) -> void:
	match kind:
		"burn":
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -r), c + Vector2(r * 0.35, -r * 0.2), c + Vector2(r * 0.7, -r * 0.6),
				c + Vector2(r * 0.8, r * 0.3), c + Vector2(0, r), c + Vector2(-r * 0.8, r * 0.3),
				c + Vector2(-r * 0.7, -r * 0.6), c + Vector2(-r * 0.35, -r * 0.2)]), BURN)
		"chill", "frozen":
			if kind == "frozen":
				ci.draw_rect(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), FROZEN)
			for i in 3:
				var a := Vector2.from_angle(PI / 3.0 * i) * r * 0.9
				ci.draw_line(c - a, c + a, CHILL if kind == "chill" else WET, maxf(2.0, r * 0.22))
		"wet":
			ci.draw_circle(c + Vector2(0, r * 0.25), r * 0.6, WET)
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -r), c + Vector2(r * 0.55, r * 0.05), c + Vector2(-r * 0.55, r * 0.05)]), WET)
		"shock":
			ci.draw_polyline(PackedVector2Array([
				c + Vector2(r * 0.3, -r), c + Vector2(-r * 0.4, 0), c + Vector2(r * 0.4, 0),
				c + Vector2(-r * 0.3, r)]), SHOCK, maxf(2.0, r * 0.3))
		"ward":
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 0.8, -r * 0.8), c + Vector2(r * 0.8, -r * 0.8),
				c + Vector2(r * 0.8, 0), c + Vector2(0, r), c + Vector2(-r * 0.8, 0)]), WARD)
		"reflect":
			ci.draw_arc(c, r * 0.8, -PI * 0.8, PI * 0.8, 16, WARD, maxf(2.0, r * 0.3))
			ci.draw_line(c + Vector2(r * 0.2, 0), c + Vector2(-r * 0.6, 0), WARD, maxf(2.0, r * 0.25))
		"silence":
			ci.draw_arc(c, r * 0.75, 0, TAU, 20, Color("c2457e"), maxf(2.0, r * 0.25))
			ci.draw_line(c + Vector2(-r * 0.55, -r * 0.55), c + Vector2(r * 0.55, r * 0.55), Color("c2457e"), maxf(2.0, r * 0.25))


## A circular status token with a stack count, as on the wizards.
static func draw_token(ci: CanvasItem, kind: String, c: Vector2, r: float, count: int) -> void:
	ci.draw_circle(c, r, INK)
	draw_glyph(ci, kind, c, r * 0.62)
	if count > 1 or kind in ["ward", "reflect", "silence"]:
		draw_text_outlined(ci, c + Vector2(r * 0.7, r * 0.7), str(count), int(r * 0.9), PARCHMENT)


## A chunky placeholder wizard: robe, head, pointed hat, and a wand.
static func draw_wizard(ci: CanvasItem, feet: Vector2, height: float, robe: Color, facing: float, hat: Color) -> void:
	var w := height * 0.42
	var body_top := feet.y - height * 0.62
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(feet.x - w * 0.5, feet.y), Vector2(feet.x + w * 0.5, feet.y),
		Vector2(feet.x + w * 0.25, body_top), Vector2(feet.x - w * 0.25, body_top)]), robe)
	var head := Vector2(feet.x, body_top - height * 0.08)
	ci.draw_circle(head, height * 0.1, Color("e8c9a0"))
	ci.draw_colored_polygon(PackedVector2Array([
		head + Vector2(-height * 0.17, -height * 0.04), head + Vector2(height * 0.17, -height * 0.04),
		head + Vector2(facing * height * 0.08, -height * 0.4)]), hat)
	var hand := Vector2(feet.x + facing * w * 0.35, feet.y - height * 0.4)
	ci.draw_line(hand, hand + Vector2(facing * height * 0.22, -height * 0.12), BARK, 6.0)
