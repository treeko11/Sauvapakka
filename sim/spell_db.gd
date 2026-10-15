class_name SpellDB
extends RefCounted
## Every SpellDef found in the spell data folder, looked up by id.

const SPELL_DIR := "res://data/spells"

var _spells: Dictionary = {} # String id -> SpellDef


static func load_default() -> SpellDB:
	var db := SpellDB.new()
	db.load_dir(SPELL_DIR)
	return db


func load_dir(path: String) -> void:
	for file in DirAccess.get_files_at(path):
		# Exported builds list resources as "name.tres.remap".
		var name := file.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var spell := load(path.path_join(name)) as SpellDef
		if spell == null:
			push_error("Not a SpellDef: %s" % name)
			continue
		var key := String(spell.id)
		if _spells.has(key):
			push_error("Duplicate spell id '%s' in %s" % [key, name])
			continue
		_spells[key] = spell


func get_spell(id: String) -> SpellDef:
	var spell: SpellDef = _spells.get(id)
	if spell == null:
		push_error("Unknown spell id: %s" % id)
	return spell


func has(id: String) -> bool:
	return _spells.has(id)


func all() -> Array[SpellDef]:
	var out: Array[SpellDef] = []
	var keys := _spells.keys()
	keys.sort()
	for k in keys:
		out.append(_spells[k])
	return out


func size() -> int:
	return _spells.size()
