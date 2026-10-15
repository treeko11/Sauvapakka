class_name Profile
extends RefCounted
## Everything kept between runs: the compendium, run records and settings,
## saved as JSON in user://.

const PATH := "user://profile.json"
const VERSION := 1

var spells_found := {}
var interactions := {}
var runs := 0
var wins := 0
## Furthest fight reached, 1-based; 7 means the Archmage.
var best_fight := 0
var settings := {"duel_speed": 1.0}
var path := PATH


static func load_or_new(p_path := PATH) -> Profile:
	var p := Profile.new()
	p.path = p_path
	if not FileAccess.file_exists(p_path):
		return p
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(p_path))
	if not data is Dictionary:
		push_warning("Profile at %s is unreadable; starting fresh" % p_path)
		return p
	p.spells_found = _as_set(data.get("spells_found", []))
	p.interactions = _as_set(data.get("interactions", []))
	p.runs = int(data.get("runs", 0))
	p.wins = int(data.get("wins", 0))
	p.best_fight = int(data.get("best_fight", 0))
	var s: Variant = data.get("settings", {})
	if s is Dictionary:
		p.settings.merge(s, true)
	return p


static func _as_set(list: Variant) -> Dictionary:
	var out := {}
	if list is Array:
		for k in list:
			out[str(k)] = true
	return out


func save() -> void:
	var data := {
		"version": VERSION,
		"spells_found": spells_found.keys(),
		"interactions": interactions.keys(),
		"runs": runs,
		"wins": wins,
		"best_fight": best_fight,
		"settings": settings,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Can't save profile to %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return
	f.store_string(JSON.stringify(data, "\t"))


## Folds a run's discoveries in; `finished` also counts the run itself.
func record_run(run: RunState, finished: bool) -> void:
	spells_found.merge(run.found)
	interactions.merge(run.discoveries)
	best_fight = maxi(best_fight, run.fight_index + 1)
	if finished:
		runs += 1
		if run.phase == RunState.Phase.WON:
			wins += 1
	save()
