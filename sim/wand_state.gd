class_name WandState
extends RefCounted
## A wand in use: its slots, draw position and mana.

var frame: FrameDef
var slots: Array[SpellDef] = []
## Slot indices in draw order; a permutation when the frame shuffles.
var order: Array[int] = []
var pointer := 0
var mana := 0.0
var next_cast_tick := 0
var cast_in_cycle := 0
## Recharge change built up by spells this cycle, applied at the next recharge.
var recharge_mod := 0.0


func _init(p_frame: FrameDef, p_slots: Array[SpellDef], rng: RandomNumberGenerator) -> void:
	frame = p_frame
	slots = p_slots
	mana = frame.mana_max
	order.assign(range(slots.size()))
	if frame.shuffle:
		reshuffle(rng)


## Fisher-Yates with the duel's seeded RNG, so shuffled wands stay deterministic.
func reshuffle(rng: RandomNumberGenerator) -> void:
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := order[i]
		order[i] = order[j]
		order[j] = tmp
