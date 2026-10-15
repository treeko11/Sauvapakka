class_name Shot
extends RefCounted
## A projectile or self-cast effect produced by a cast. Plain data; the duel moves it.

var uid := 0
var spell: SpellDef
var slot := -1
var mod_ids: PackedStringArray = []
var source := 0
var target := 1
var self_target := false

var damage := 0.0
var damage_mult := 1.0
var hits := 1
var chain := 0
var travel_time := 0.5
var launch_tick := 0
var arrive_tick := 0
var bounces := 0

var burn := 0
var chill := 0
var wet := 0
var shock := 0
var permanent_chill := false

var pierce := 0
var split := 0
var ward_hits := 0
var reflect_hits := 0
var mana_drain := 0
var silence := 0
var delay_target := 0.0
var condition: SpellDef.Condition = SpellDef.Condition.NONE
var condition_mult := 1.0

## Shots carried by a trigger, fired on first contact.
var payload: Array[Shot] = []


## Deep copy, including the payload, so every copy carries its own.
func copy() -> Shot:
	var s := Shot.new()
	for p in get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			s.set(p.name, get(p.name))
	s.mod_ids = mod_ids.duplicate()
	s.payload = []
	for child in payload:
		s.payload.append(child.copy())
	return s
