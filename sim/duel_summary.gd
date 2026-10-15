class_name DuelSummary
extends RefCounted
## Reads a finished duel's event log for the Result screen: highlights for the
## player (caster 0) and the hidden interactions they triggered.

## Hidden interactions and the event that reveals each.
const INTERACTIONS := {
	"steam": "Steam: Burn on a frozen target",
	"instant_freeze": "Instant freeze: Chill on a wet target",
	"wet_shock": "Charged water: Shock on a wet target",
	"douse": "Douse: Wet puts out Burn",
	"reflect": "Reflect: a ward sends a hit back",
}


static func stats(d: Duel, who := 0) -> Dictionary:
	var out := {
		"dealt": 0.0, "taken": 0.0, "biggest": 0.0, "biggest_spell": &"",
		"by_cause": {}, "interactions": {}, "casts": 0, "freezes": 0,
	}
	for e in d.events:
		match e["type"]:
			"cast":
				if e["who"] == who:
					out["casts"] += 1
			"damage":
				if e["who"] == who:
					out["taken"] += e["amount"]
					continue
				out["dealt"] += e["amount"]
				out["by_cause"][e["cause"]] = out["by_cause"].get(e["cause"], 0.0) + e["amount"]
				if e["cause"] == "steam":
					out["interactions"]["steam"] = true
				if e["cause"] == "hit" and e["amount"] > out["biggest"]:
					out["biggest"] = e["amount"]
					out["biggest_spell"] = e["spell"]
			"frozen":
				if e["who"] != who:
					out["freezes"] += 1
					if e["cause"] == "wet":
						out["interactions"]["instant_freeze"] = true
			"shock_burst":
				if e["who"] != who and e["wet"]:
					out["interactions"]["wet_shock"] = true
			"doused":
				if e["who"] != who:
					out["interactions"]["douse"] = true
			"reflect":
				if e["who"] == who:
					out["interactions"]["reflect"] = true
	return out


static func highlights(d: Duel, dummy := false) -> PackedStringArray:
	var s := stats(d)
	var lines := PackedStringArray()
	lines.append("%.1f s" % d.seconds())
	if dummy:
		lines.append("Damage dealt: %d   DPS: %.1f" % [roundi(s["dealt"]), s["dealt"] / maxf(d.seconds(), 0.05)])
	else:
		lines.append("Damage dealt: %d   taken: %d" % [roundi(s["dealt"]), roundi(s["taken"])])
	if s["biggest"] > 0.0:
		var spell: String = s["biggest_spell"]
		lines.append("Biggest hit: %d (%s)" % [roundi(s["biggest"]), spell.capitalize()])
	if s["by_cause"].get("burn", 0.0) > 0.0:
		lines.append("Burn damage: %d" % roundi(s["by_cause"]["burn"]))
	if s["freezes"] > 0:
		lines.append("Freezes: %d" % s["freezes"])
	for k in s["interactions"]:
		lines.append(INTERACTIONS[k])
	return lines
