class_name WandBuild
extends Resource
## A frame plus the spells slotted into it. Spells are referenced by id so a build
## can be saved, shared and replayed (async multiplayer) without embedding spell data.

@export var display_name: String
@export var frame: FrameDef
## One entry per slot in order; "" is an empty slot.
@export var spell_ids: PackedStringArray


func resolve(db: SpellDB) -> Array[SpellDef]:
	if spell_ids.size() > frame.capacity:
		push_warning("%s has %d spells but %s only has %d slots; extras ignored" % [
			display_name, spell_ids.size(), frame.display_name, frame.capacity])
	var out: Array[SpellDef] = []
	for i in frame.capacity:
		var sid := spell_ids[i] if i < spell_ids.size() else ""
		out.append(db.get_spell(sid) if sid != "" else null)
	return out
