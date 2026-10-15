class_name EnemyGen
extends RefCounted
## Builds regular enemy wands from an archetype's spell pool, scaled by depth
## through better frames, rarer spells and smarter ordering.

const FRAME_DIR := "res://data/frames"
## From this depth on, spells are ordered so modifiers and multicasts feed projectiles.
const SMART_ORDER_DEPTH := 2


static func max_rarity(depth: int) -> int:
	if depth <= 1:
		return SpellDef.Rarity.COMMON
	if depth <= 3:
		return SpellDef.Rarity.UNCOMMON
	return SpellDef.Rarity.RARE


static func slots_to_fill(def: EnemyDef, depth: int, capacity: int) -> int:
	return mini(capacity, (4 if def.themed else 3) + depth)


static func generate(def: EnemyDef, depth: int, rng: RandomNumberGenerator, db: SpellDB) -> WandBuild:
	if def.fixed_build != null:
		return def.fixed_build
	var b := WandBuild.new()
	b.display_name = def.display_name
	if not def.frames.is_empty() and depth >= def.rule_frame_depth:
		b.frame = load(FRAME_DIR.path_join(def.frames[rng.randi_range(0, def.frames.size() - 1)] + ".tres"))
	else:
		b.frame = FrameGen.standard(rng, depth)
	var pool: Array[SpellDef] = []
	for sid in def.spell_pool:
		var sp := db.get_spell(sid)
		if sp != null and sp.rarity <= max_rarity(depth):
			pool.append(sp)
	var picks: Array[SpellDef] = []
	for i in slots_to_fill(def, depth, b.frame.capacity):
		picks.append(pool[rng.randi_range(0, pool.size() - 1)])
	if not picks.any(_is_attack):
		var attacks := pool.filter(_is_attack)
		if attacks.is_empty():
			attacks = [db.get_spell("flicker")]
		picks[rng.randi_range(0, picks.size() - 1)] = attacks[rng.randi_range(0, attacks.size() - 1)]
	if depth >= SMART_ORDER_DEPTH:
		picks = smart_order(picks)
	else:
		_shuffle(picks, rng)
	var ids := PackedStringArray()
	for sp in picks:
		ids.append(sp.id)
	b.spell_ids = ids
	return b


static func _is_attack(sp: SpellDef) -> bool:
	return sp.kind == SpellDef.Kind.PROJECTILE and sp.damage > 0.0


## Wards first, then each multicast, modifier and trigger placed in front of the
## projectiles it needs, then utilities last.
static func smart_order(spells: Array[SpellDef]) -> Array[SpellDef]:
	var defs: Array[SpellDef] = []
	var mods: Array[SpellDef] = []
	var multis: Array[SpellDef] = []
	var triggers: Array[SpellDef] = []
	var shots: Array[SpellDef] = []
	var utils: Array[SpellDef] = []
	for sp in spells:
		match sp.kind:
			SpellDef.Kind.SELF:
				defs.append(sp)
			SpellDef.Kind.MODIFIER:
				mods.append(sp)
			SpellDef.Kind.MULTICAST:
				multis.append(sp)
			SpellDef.Kind.UTILITY:
				utils.append(sp)
			_:
				if sp.trigger:
					triggers.append(sp)
				else:
					shots.append(sp)
	var out: Array[SpellDef] = []
	out.append_array(defs)
	while not shots.is_empty() or not triggers.is_empty():
		var need := 1
		if not multis.is_empty():
			var m: SpellDef = multis.pop_front()
			out.append(m)
			need = maxi(1, m.draw)
		for i in need:
			if not triggers.is_empty() and shots.size() >= 1:
				out.append(triggers.pop_front())
				out.append(shots.pop_front())
				continue
			if not mods.is_empty():
				out.append(mods.pop_front())
			if not shots.is_empty():
				out.append(shots.pop_front())
			elif not triggers.is_empty():
				out.append(triggers.pop_front())
	out.append_array(multis)
	out.append_array(mods)
	out.append_array(utils)
	return out


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## Trait tags a wand shows on the Preview screen.
static func traits(b: WandBuild, db: SpellDB) -> PackedStringArray:
	var counts := {}
	var dmg := 0.0
	for sp in b.resolve(db):
		if sp == null:
			continue
		for pair in [["Burns", sp.burn], ["Chills", sp.chill], ["Wet", sp.wet], ["Shocks", sp.shock],
				["Shielded", sp.ward_hits], ["Reflects", sp.reflect_hits], ["Drains mana", sp.mana_drain],
				["Silences", sp.silence], ["Multicast", sp.draw if sp.kind == SpellDef.Kind.MULTICAST else 0],
				["Triggers", 1 if sp.trigger else 0], ["Splits", sp.split_into]]:
			if pair[1] > 0:
				counts[pair[0]] = counts.get(pair[0], 0) + 1
		dmg = maxf(dmg, sp.damage + sp.add_damage)
	var out := PackedStringArray()
	for k in counts:
		out.append(k)
	if dmg >= 12.0:
		out.append("Heavy hits")
	if b.frame.cast_delay <= 0.2:
		out.append("Fast")
	elif b.frame.cast_delay >= 0.35:
		out.append("Slow")
	if b.frame.shuffle:
		out.append("Shuffles")
	return out
