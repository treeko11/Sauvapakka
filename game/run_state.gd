class_name RunState
extends RefCounted
## One run: the spell book, the hand, the player's wands and the fight ladder.
## Pure data and rules, so the screens and the tests drive it the same way.

enum Phase { PREVIEW, WORKSHOP, REWARD, WON, LOST }

const HAND_SIZE := 5
const MAX_WANDS := 3
const START_REMOVALS := 2
const START_PIN_SLOTS := 1
## Fight types for the six regular fights, in order; the boss is seventh.
const FIGHT_PLAN := ["generic", "generic", "themed", "generic", "themed", "themed"]
const ENEMY_DIR := "res://data/enemies"
const BOSS_PATH := "res://data/bosses/archmage.tres"
const STARTER_FRAME := "res://data/frames/apprentice_rod.tres"
const STARTER_WAND := ["flicker", "flicker", "damage_plus", "flicker", "ember"]
const STARTER_LIBRARY := ["ember", "frost_shard", "water_orb", "arc", "ward", "add_burn", "double_spell", "flicker"]
## Reward rarity weights by depth: common, uncommon, rare, legendary.
const REWARD_WEIGHTS := [[100, 0, 0, 0], [75, 25, 0, 0], [60, 32, 8, 0], [50, 35, 15, 0],
	[42, 36, 20, 2], [36, 36, 24, 4], [30, 36, 28, 6]]
## Wins after which a frame drops, by fight index.
const FRAME_DROP_AFTER := [1, 3]

var db: SpellDB
var rng := RandomNumberGenerator.new()
var run_seed := 0

## Unslotted spells that can be drawn.
var library: Array[String] = []
var stash: Array[String] = []
var hand: Array[String] = []
var pinned: Array[String] = []
var wands: Array[WandBuild] = []
var removals := START_REMOVALS
var pin_slots := START_PIN_SLOTS

## Each fight: {"def": EnemyDef, "depth": int, "build": WandBuild, "boss": bool}
var fights: Array[Dictionary] = []
var fight_index := 0
var phase := Phase.PREVIEW
var reward_options: PackedStringArray = []
var enemy_drop := ""
var frame_drop: FrameDef
## Spell ids that entered the spell book this run.
var found := {}
var discoveries := {}
var results: Array[Dictionary] = []


static func create(p_db: SpellDB, p_seed: int) -> RunState:
	var r := RunState.new()
	r.db = p_db
	r.run_seed = p_seed
	r.rng.seed = p_seed
	var starter := WandBuild.new()
	starter.display_name = "Wand 1"
	starter.frame = load(STARTER_FRAME)
	starter.spell_ids = PackedStringArray(STARTER_WAND)
	r.wands.append(starter)
	var second := WandBuild.new()
	second.display_name = "Wand 2"
	second.frame = FrameGen.standard(r.rng, 0, "birch")
	second.frame.shuffle = false
	r.wands.append(second)
	for w in r.wands:
		r._pad(w)
		for sid in w.spell_ids:
			if sid != "":
				r.found[sid] = true
	for sid in STARTER_LIBRARY:
		r._add_spell(sid)
	r._plan_fights()
	return r


func _plan_fights() -> void:
	var generic: Array[EnemyDef] = []
	var themed: Array[EnemyDef] = []
	for f in DirAccess.get_files_at(ENEMY_DIR):
		f = f.trim_suffix(".remap")
		if not f.ends_with(".tres"):
			continue
		var def := load(ENEMY_DIR.path_join(f)) as EnemyDef
		(themed if def.themed else generic).append(def)
	generic.sort_custom(func(a: EnemyDef, b: EnemyDef) -> bool: return a.id < b.id)
	themed.sort_custom(func(a: EnemyDef, b: EnemyDef) -> bool: return a.id < b.id)
	EnemyGen._shuffle(themed, rng)
	for depth in FIGHT_PLAN.size():
		var def: EnemyDef
		if FIGHT_PLAN[depth] == "themed":
			def = themed.pop_front()
		else:
			var fits := generic.filter(func(g: EnemyDef) -> bool: return g.min_depth <= depth and depth <= g.max_depth)
			def = fits[rng.randi_range(0, fits.size() - 1)]
		var gen_rng := RandomNumberGenerator.new()
		gen_rng.seed = hash([run_seed, depth])
		fights.append({"def": def, "depth": depth, "build": EnemyGen.generate(def, depth, gen_rng, db), "boss": false})
	var boss := load(BOSS_PATH) as EnemyDef
	fights.append({"def": boss, "depth": FIGHT_PLAN.size(), "build": boss.fixed_build, "boss": true})


func current_fight() -> Dictionary:
	return fights[mini(fight_index, fights.size() - 1)]


func enemy_traits() -> PackedStringArray:
	var f := current_fight()
	var def: EnemyDef = f["def"]
	return def.traits if def.themed else EnemyGen.traits(f["build"], db)


# --- Hand and wands -----------------------------------------------------------

func deal_hand() -> void:
	return_hand()
	for p in pinned:
		if hand.size() < HAND_SIZE and library.has(p):
			library.erase(p)
			hand.append(p)
	while hand.size() < HAND_SIZE and not library.is_empty():
		hand.append(library.pop_at(rng.randi_range(0, library.size() - 1)))
	phase = Phase.WORKSHOP


func return_hand() -> void:
	library.append_array(hand)
	hand.clear()


## Puts a hand spell into a slot; whatever was there goes back to the hand.
func place_from_hand(hand_i: int, wand_i: int, slot: int) -> bool:
	if hand_i < 0 or hand_i >= hand.size() or not _valid_slot(wand_i, slot):
		return false
	var w := wands[wand_i]
	var old := w.spell_ids[slot]
	w.spell_ids[slot] = hand[hand_i]
	hand.remove_at(hand_i)
	if old != "":
		hand.insert(hand_i, old)
	return true


func unslot(wand_i: int, slot: int) -> bool:
	if not _valid_slot(wand_i, slot) or wands[wand_i].spell_ids[slot] == "":
		return false
	hand.append(wands[wand_i].spell_ids[slot])
	wands[wand_i].spell_ids[slot] = ""
	return true


## Swaps two slots, within a wand or across wands.
func move_slot(wand_a: int, slot_a: int, wand_b: int, slot_b: int) -> bool:
	if not _valid_slot(wand_a, slot_a) or not _valid_slot(wand_b, slot_b):
		return false
	var tmp := wands[wand_a].spell_ids[slot_a]
	wands[wand_a].spell_ids[slot_a] = wands[wand_b].spell_ids[slot_b]
	wands[wand_b].spell_ids[slot_b] = tmp
	return true


func _valid_slot(wand_i: int, slot: int) -> bool:
	return wand_i >= 0 and wand_i < wands.size() and slot >= 0 and slot < wands[wand_i].frame.capacity


func _pad(w: WandBuild) -> void:
	var ids := w.spell_ids
	ids.resize(w.frame.capacity)
	w.spell_ids = ids


func wand_is_empty(wand_i: int) -> bool:
	for sid in wands[wand_i].spell_ids:
		if sid != "":
			return false
	return true


# --- Spell book ---------------------------------------------------------------

func book_size() -> int:
	var n := library.size() + stash.size() + hand.size()
	for w in wands:
		for sid in w.spell_ids:
			if sid != "":
				n += 1
	return n


func stash_spell(sid: String) -> bool:
	if not library.has(sid):
		return false
	library.erase(sid)
	stash.append(sid)
	if library.count(sid) < pinned.count(sid):
		pinned.erase(sid)
	return true


func unstash_spell(sid: String) -> bool:
	if not stash.has(sid):
		return false
	stash.erase(sid)
	library.append(sid)
	return true


func remove_spell(sid: String) -> bool:
	if removals <= 0:
		return false
	if library.has(sid):
		library.erase(sid)
		if library.count(sid) < pinned.count(sid):
			pinned.erase(sid)
	elif stash.has(sid):
		stash.erase(sid)
	else:
		return false
	removals -= 1
	return true


func pin_spell(sid: String) -> bool:
	if pinned.size() >= pin_slots or library.count(sid) <= pinned.count(sid):
		return false
	pinned.append(sid)
	return true


func unpin_spell(sid: String) -> bool:
	if not pinned.has(sid):
		return false
	pinned.erase(sid)
	return true


func _add_spell(sid: String) -> void:
	library.append(sid)
	found[sid] = true


# --- Fights and rewards -------------------------------------------------------

func make_duel(wand_i: int, attempt := 0) -> Duel:
	var f := current_fight()
	var d := Duel.new(wands[wand_i], f["build"], db, hash([run_seed, fight_index, attempt]), f["boss"])
	var def: EnemyDef = f["def"]
	d.casters[0].name = "You"
	d.casters[1].name = def.display_name
	d.casters[1].max_hp = def.max_hp
	d.casters[1].hp = def.max_hp
	return d


## Records a finished duel and moves to the reward, the next fight, or the end.
func finish_fight(d: Duel) -> void:
	var stats := DuelSummary.stats(d)
	for k in stats["interactions"]:
		discoveries[k] = true
	results.append({"fight": fight_index, "winner": d.winner, "seconds": d.seconds(),
		"biggest": stats["biggest"], "biggest_spell": stats["biggest_spell"], "dealt": stats["dealt"]})
	return_hand()
	if d.winner != 0:
		phase = Phase.LOST
		return
	if current_fight()["boss"]:
		phase = Phase.WON
		return
	_roll_rewards()
	phase = Phase.REWARD


func _roll_rewards() -> void:
	var depth := mini(fight_index + 1, REWARD_WEIGHTS.size() - 1)
	reward_options = PackedStringArray()
	var all := db.all()
	for i in 3:
		for attempt in 20:
			var rarity := _weighted(REWARD_WEIGHTS[depth])
			var options := all.filter(func(s: SpellDef) -> bool: return s.rarity == rarity and not reward_options.has(String(s.id)))
			if options.is_empty():
				continue
			reward_options.append(String(options[rng.randi_range(0, options.size() - 1)].id))
			break
	var enemy_ids := Array(current_fight()["build"].spell_ids).filter(func(s: String) -> bool: return s != "")
	enemy_drop = enemy_ids[rng.randi_range(0, enemy_ids.size() - 1)] if not enemy_ids.is_empty() else ""
	frame_drop = null
	if fight_index in FRAME_DROP_AFTER:
		frame_drop = FrameGen.standard(rng, fight_index + 1)


func _weighted(weights: Array) -> int:
	var total := 0
	for w in weights:
		total += w
	var roll := rng.randi_range(0, total - 1)
	for i in weights.size():
		roll -= weights[i]
		if roll < 0:
			return i
	return 0


## Takes the chosen reward (or none with ""), the enemy drop, and optionally the
## frame drop: as a new wand (`frame_target` -1) or replacing a wand's frame.
func take_rewards(choice: String, frame_target := -2) -> void:
	if choice != "" and reward_options.has(choice):
		_add_spell(choice)
	if enemy_drop != "":
		_add_spell(enemy_drop)
	if frame_drop != null and frame_target > -2:
		_take_frame(frame_drop, frame_target)
	reward_options = PackedStringArray()
	enemy_drop = ""
	frame_drop = null
	fight_index += 1
	phase = Phase.PREVIEW


func _take_frame(f: FrameDef, target: int) -> void:
	if target == -1 and wands.size() < MAX_WANDS:
		var w := WandBuild.new()
		w.display_name = "Wand %d" % (wands.size() + 1)
		w.frame = f
		_pad(w)
		wands.append(w)
		return
	if target < 0 or target >= wands.size():
		return
	var w := wands[target]
	var kept := PackedStringArray()
	for sid in w.spell_ids:
		if sid == "":
			continue
		if kept.size() < f.capacity:
			kept.append(sid)
		else:
			library.append(sid)
	w.frame = f
	w.spell_ids = kept
	_pad(w)
