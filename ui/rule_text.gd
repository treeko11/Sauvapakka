class_name RuleText
extends RefCounted
## Player-facing text for frame rules.

const FRAME_RULES := {
	FrameDef.Rule.TWIN_FORK: "First cast of each cycle is doubled",
	FrameDef.Rule.EMBER_STAFF: "Burn you apply lasts longer",
	FrameDef.Rule.GLACIER_WAND: "Chill stops decaying until the target freezes",
	FrameDef.Rule.LEYLINE_ROD: "The spell in the first slot costs no mana",
}


static func frame_rule(f: FrameDef, prefix := "\n") -> String:
	return prefix + FRAME_RULES[f.rule] if FRAME_RULES.has(f.rule) else ""
