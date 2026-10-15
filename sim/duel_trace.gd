class_name DuelTrace
extends RefCounted
## Turns duel events into readable text lines.


static func format_event(e: Dictionary, names: PackedStringArray) -> String:
	var who: int = e["who"]
	var who_name := "draw" if who == Duel.DRAW else names[who]
	var rest := PackedStringArray()
	for k in e.keys():
		if k in ["tick", "type", "who"]:
			continue
		rest.append("%s=%s" % [k, e[k]])
	return "%6.2fs  %-16s %-12s %s" % [e["tick"] * Duel.TICK, who_name, e["type"], " ".join(rest)]


static func print_duel(d: Duel) -> void:
	var names := PackedStringArray([d.casters[0].name, d.casters[1].name])
	for e in d.events:
		print(format_event(e, names))
