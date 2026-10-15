class_name Duel
extends RefCounted
## Deterministic 1v1 wand duel on fixed ticks, with no rendering. Everything a viewer
## needs to replay or explain the fight is written to `events`, so the duel screen,
## the Result highlights and async replays can all be driven from the log.
##
## Each tick runs in a fixed order: status ticks, projectile arrivals, casts
## (caster 0 then 1), mana regen, end check.

const TICKS_PER_SECOND := 20
const TICK := 1.0 / TICKS_PER_SECOND

# Hard caps so loops and recursion can't hang the sim.
const MAX_DRAWS_PER_CAST := 64
const MAX_PAYLOAD_DEPTH := 4
const MAX_BOUNCES := 4
const MIN_CAST_DELAY := 0.05

# Status tuning.
const BURN_INTERVAL := 0.5
const BURN_DAMAGE_PER_STACK := 1.0
## Burn loses one stack per interval, so without a cap stacks pile up faster
## than they decay and damage grows without limit.
const MAX_BURN_STACKS := 4
const CHILL_DECAY_INTERVAL := 2.0
const CHILL_FREEZE_AT := 5
const CHILL_SLOW_PER_STACK := 0.1
## A frozen caster skips its next cast and waits at least this long before the one after.
const FROZEN_SECONDS := 0.7
const SHOCK_BONUS_PER_STACK := 5.0
const STEAM_DAMAGE := 12.0
const CHAIN_DAMAGE_MULT := 0.5
## Damage amplification starts at this fraction of fight_seconds.
const ESCALATION_START := 0.6

enum { RUNNING = -2, DRAW = -1 }

## Damage amplification reaches amp_at_end here.
var fight_seconds := 30.0
## If nobody has died by now, the higher HP fraction wins.
var hard_cap_seconds := 60.0
var amp_at_end := 3.0

var tick := 0
var casters: Array[Caster] = []
var in_flight: Array[Shot] = []
var events: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
## RUNNING, DRAW, or the winning caster's index.
var winner: int = RUNNING
var _next_uid := 1


class CastContext:
	var wrapped := false
	var draws := 0
	var delay := 0.0
	var drawn_slots: Array[int] = []


func _init(build_a: WandBuild, build_b: WandBuild, db: SpellDB, p_seed: int = 0, boss := false) -> void:
	rng.seed = p_seed
	if boss:
		fight_seconds = 60.0
		hard_cap_seconds = 120.0
	var builds: Array[WandBuild] = [build_a, build_b]
	for i in 2:
		var c := Caster.new()
		c.index = i
		c.name = builds[i].display_name
		c.wand = WandState.new(builds[i].frame, builds[i].resolve(db), rng)
		casters.append(c)


func run() -> int:
	while winner == RUNNING:
		step()
	return winner


func step() -> void:
	tick += 1
	_tick_statuses()
	_resolve_arrivals()
	for c in casters:
		if tick >= c.wand.next_cast_tick:
			_cast(c)
	_regen_mana()
	_check_end()


func seconds() -> float:
	return tick * TICK


func result() -> Dictionary:
	return {
		"winner": winner,
		"seconds": seconds(),
		"hp": [casters[0].hp, casters[1].hp],
	}


# --- Test and tooling hooks -------------------------------------------------

## Casts caster `i`'s wand immediately and returns the shots it produced.
func cast_now(i: int) -> Array[Shot]:
	return _cast(casters[i])


## Resolves a shot's arrival immediately, wherever it is in flight.
func arrive_now(s: Shot) -> void:
	in_flight.erase(s)
	_arrive(s)


# --- Casting ----------------------------------------------------------------

func _cast(c: Caster) -> Array[Shot]:
	var w := c.wand
	var chill_factor := 1.0 + CHILL_SLOW_PER_STACK * c.chill
	if c.frozen:
		c.frozen = false
		_log("frozen_skip", c.index)
		w.next_cast_tick = tick + maxi(1, _ticks(maxf(FROZEN_SECONDS, w.frame.cast_delay * chill_factor)))
		return []

	var ctx := CastContext.new()
	var shots := _draw_shots(c, ctx, w.frame.spells_per_cast, 0)
	if w.frame.rule == FrameDef.Rule.TWIN_FORK and w.cast_in_cycle == 0:
		var extra: Array[Shot] = []
		for s in shots:
			extra.append(s.copy())
		shots.append_array(extra)
	_log("cast", c.index, {"slots": ctx.drawn_slots, "shots": shots.size(), "mana": snappedf(w.mana, 0.1)})
	w.cast_in_cycle += 1
	for s in shots:
		_launch(s)

	var wait := maxf(MIN_CAST_DELAY, w.frame.cast_delay + ctx.delay) * chill_factor
	var cycle_done := ctx.wrapped or w.pointer >= w.order.size()
	if cycle_done:
		var recharge := maxf(0.0, w.frame.recharge_time + w.recharge_mod)
		wait = maxf(wait, recharge)
		_log("recharge", c.index, {"seconds": snappedf(recharge, 0.01)})
		w.pointer = 0
		w.cast_in_cycle = 0
		w.recharge_mod = 0.0
		if w.frame.shuffle:
			w.reshuffle(rng)
	w.next_cast_tick = tick + maxi(1, _ticks(wait))
	return shots


## Draws until `need` projectiles are ready. Modifiers and utilities draw a
## replacement; multicasts raise `need`; triggers recurse for their payload.
func _draw_shots(c: Caster, ctx: CastContext, need: int, depth: int) -> Array[Shot]:
	var w := c.wand
	var shots: Array[Shot] = []
	var mods: Array[SpellDef] = []
	var groups: Array[Dictionary] = [] # active multicasts: left, mult, copies
	while need > 0:
		var slot := _draw_card(c, ctx)
		if slot < 0:
			break
		var sp: SpellDef = w.slots[slot]
		var cost := float(sp.mana_cost)
		if w.frame.rule == FrameDef.Rule.LEYLINE_ROD and slot == 0:
			cost = 0.0
		if cost > w.mana:
			_log("no_mana", c.index, {"slot": slot, "spell": sp.id})
			continue
		w.mana -= cost
		ctx.delay += sp.cast_delay

		match sp.kind:
			SpellDef.Kind.MODIFIER:
				mods.append(sp)
			SpellDef.Kind.UTILITY:
				w.mana = minf(w.frame.mana_max, w.mana + sp.mana_refund)
				w.recharge_mod += sp.recharge
			SpellDef.Kind.MULTICAST:
				need += sp.draw - 1
				groups.append({"left": sp.draw, "mult": sp.damage_mult, "copies": sp.copies})
			_: # PROJECTILE or SELF
				need -= 1
				var shot := _make_shot(c, sp, slot, mods)
				mods.clear()
				var copies := 1
				var still_open: Array[Dictionary] = []
				for g in groups:
					shot.damage_mult *= g["mult"]
					copies *= g["copies"]
					g["left"] -= 1
					if g["left"] > 0:
						still_open.append(g)
				groups = still_open
				if sp.trigger:
					if depth < MAX_PAYLOAD_DEPTH:
						shot.payload = _draw_shots(c, ctx, 1, depth + 1)
					else:
						_log("payload_cap", c.index, {"slot": slot})
				var produced: Array[Shot] = [shot]
				for i in shot.split - 1:
					produced.append(shot.copy())
				for p in produced:
					shots.append(p)
					for i in copies - 1:
						shots.append(p.copy())
	if not mods.is_empty():
		_log("fizzle", c.index, {"mods": mods.map(func(m: SpellDef) -> StringName: return m.id)})
	return shots


## Returns the next slot to resolve, or -1 when the cast can't draw any more.
## Running past the last slot wraps to the first, once per cast.
func _draw_card(c: Caster, ctx: CastContext) -> int:
	var w := c.wand
	while ctx.draws < MAX_DRAWS_PER_CAST:
		if w.pointer >= w.order.size():
			if ctx.wrapped or w.order.is_empty():
				return -1
			ctx.wrapped = true
			w.pointer = 0
			_log("wrap", c.index)
		var slot := w.order[w.pointer]
		w.pointer += 1
		ctx.draws += 1
		if w.slots[slot] == null:
			continue
		if c.silence > 0:
			c.silence -= 1
			_log("silenced", c.index, {"slot": slot, "spell": w.slots[slot].id})
			continue
		ctx.drawn_slots.append(slot)
		return slot
	return -1


func _make_shot(c: Caster, sp: SpellDef, slot: int, mods: Array[SpellDef]) -> Shot:
	var w := c.wand
	var s := Shot.new()
	s.spell = sp
	s.slot = slot
	s.source = c.index
	s.target = 1 - c.index
	s.self_target = sp.kind == SpellDef.Kind.SELF
	s.damage = sp.damage
	s.hits = sp.hits
	s.chain = sp.chain
	s.travel_time = sp.travel_time
	s.burn = sp.burn
	s.chill = sp.chill
	s.wet = sp.wet
	s.shock = sp.shock
	s.ward_hits = sp.ward_hits
	s.reflect_hits = sp.reflect_hits
	s.mana_drain = sp.mana_drain
	s.silence = sp.silence
	s.delay_target = sp.delay_target
	s.condition = sp.condition
	s.condition_mult = sp.condition_damage_mult
	for m in mods:
		s.mod_ids.append(m.id)
		s.damage += m.add_damage
		s.damage_mult *= m.damage_mult
		s.burn += m.burn
		s.chill += m.chill
		s.wet += m.wet
		s.shock += m.shock
		s.pierce += m.add_pierce
		s.split = maxi(s.split, m.split_into)
		s.mana_drain += m.mana_drain
		s.silence += m.silence
		if m.speed_mult > 0.0:
			s.travel_time /= m.speed_mult
		if m.mana_to_damage > 0.0:
			s.damage += w.mana * m.mana_to_damage
			w.mana = 0.0
		if m.condition != SpellDef.Condition.NONE:
			s.condition = m.condition
			s.condition_mult = m.condition_damage_mult
	if w.frame.rule == FrameDef.Rule.EMBER_STAFF and s.burn > 0:
		s.burn += 1
	s.permanent_chill = w.frame.rule == FrameDef.Rule.GLACIER_WAND
	if s.condition == SpellDef.Condition.FIRST_CAST:
		if w.cast_in_cycle == 0:
			s.damage_mult *= s.condition_mult
		s.condition = SpellDef.Condition.NONE
	return s


func _launch(s: Shot) -> void:
	s.uid = _next_uid
	_next_uid += 1
	if s.self_target:
		var c := casters[s.source]
		c.wards += s.ward_hits
		c.reflects += s.reflect_hits
		_log("self", s.source, {"uid": s.uid, "spell": s.spell.id, "slot": s.slot, "wards": c.wards, "reflects": c.reflects})
		return
	s.launch_tick = tick
	s.arrive_tick = tick + maxi(1, _ticks(s.travel_time))
	in_flight.append(s)
	_log("launch", s.source, {"uid": s.uid, "spell": s.spell.id, "slot": s.slot, "mods": s.mod_ids, "arrive": s.arrive_tick})


# --- Hits -------------------------------------------------------------------

func _resolve_arrivals() -> void:
	var arriving: Array[Shot] = []
	var remaining: Array[Shot] = []
	for s in in_flight:
		if s.arrive_tick <= tick:
			arriving.append(s)
		else:
			remaining.append(s)
	in_flight = remaining
	for s in arriving:
		_arrive(s)


func _arrive(s: Shot) -> void:
	var target := casters[s.target]
	var attacker := casters[s.source]
	for h in s.hits + s.chain:
		var chain_hit := h >= s.hits
		if target.wards > 0 or target.reflects > 0:
			if s.pierce > 0:
				s.pierce -= 1
				_log("pierce", s.target, {"uid": s.uid})
			elif target.reflects > 0 and s.bounces < MAX_BOUNCES:
				# The payload pops on the ward before the projectile bounces back.
				target.reflects -= 1
				_log("reflect", s.target, {"uid": s.uid})
				_fire_payload(s)
				_bounce(s)
				return
			else:
				if target.wards > 0:
					target.wards -= 1
				else:
					target.reflects -= 1
				_log("blocked", s.target, {"uid": s.uid, "wards": target.wards})
				_fire_payload(s)
				continue
		_hit(s, target, attacker, chain_hit)
		_fire_payload(s)


func _hit(s: Shot, target: Caster, attacker: Caster, chain_hit: bool) -> void:
	var dmg := s.damage * s.damage_mult
	if chain_hit:
		dmg *= CHAIN_DAMAGE_MULT
	if s.condition != SpellDef.Condition.NONE and _condition_met(s.condition, target):
		dmg *= s.condition_mult
	if target.shock > 0:
		var bonus := SHOCK_BONUS_PER_STACK * target.shock
		var boosted := target.wet > 0
		if boosted:
			bonus *= 2.0
			target.wet = 0
		target.shock = 0
		dmg += bonus
		_log("shock_burst", target.index, {"uid": s.uid, "bonus": bonus, "wet": boosted})
	dmg *= _amp()
	_damage(target, dmg, "hit", {"uid": s.uid, "spell": s.spell.id, "chain": chain_hit})
	if chain_hit:
		return

	# Fixed order: wet, burn, chill, shock. One projectile can't freeze and steam itself.
	if s.wet > 0:
		if target.burn > 0:
			target.burn = 0
			_log("doused", target.index, {"uid": s.uid})
		else:
			target.wet = 1
	if s.burn > 0:
		if target.frozen:
			target.frozen = false
			_damage(target, STEAM_DAMAGE * _amp(), "steam", {"uid": s.uid})
		elif target.wet > 0:
			target.wet = 0
			_log("doused", target.index, {"uid": s.uid})
		else:
			target.burn = mini(MAX_BURN_STACKS, target.burn + s.burn)
	if s.chill > 0:
		if target.wet > 0:
			target.wet = 0
			_freeze(target, "wet")
		else:
			target.chill += s.chill
			if s.permanent_chill:
				target.chill_permanent = true
			if target.chill >= CHILL_FREEZE_AT:
				_freeze(target, "chill")
	if s.shock > 0:
		target.shock += s.shock
	if s.mana_drain > 0:
		var stolen := minf(float(s.mana_drain), target.wand.mana)
		target.wand.mana -= stolen
		attacker.wand.mana = minf(attacker.wand.frame.mana_max, attacker.wand.mana + stolen)
		_log("mana_drain", target.index, {"uid": s.uid, "amount": stolen})
	if s.silence > 0:
		target.silence += s.silence
		_log("silence", target.index, {"uid": s.uid, "stacks": target.silence})
	if s.delay_target > 0.0:
		target.wand.next_cast_tick += _ticks(s.delay_target)
	_log("status", target.index, _status_snapshot(target))


func _fire_payload(s: Shot) -> void:
	for p in s.payload:
		p.source = s.source
		p.target = s.target
		p.travel_time = TICK
		_launch(p)
	s.payload.clear()


func _bounce(s: Shot) -> void:
	var b := s.copy()
	b.payload = []
	b.source = s.target
	b.target = s.source
	b.bounces += 1
	_launch(b)


func _freeze(c: Caster, cause: String) -> void:
	c.frozen = true
	c.chill = 0
	c.chill_permanent = false
	_log("frozen", c.index, {"cause": cause})


func _condition_met(cond: SpellDef.Condition, target: Caster) -> bool:
	match cond:
		SpellDef.Condition.TARGET_BURNING:
			return target.burn > 0
		SpellDef.Condition.TARGET_CHILLED:
			return target.chill > 0 or target.frozen
		SpellDef.Condition.TARGET_WET:
			return target.wet > 0
		SpellDef.Condition.TARGET_SHOCKED:
			return target.shock > 0
	return false


func _damage(c: Caster, amount: float, cause: String, data: Dictionary) -> void:
	if amount <= 0.0:
		return
	c.hp -= amount
	var e := {"amount": snappedf(amount, 0.01), "cause": cause, "hp": snappedf(c.hp, 0.01)}
	e.merge(data)
	_log("damage", c.index, e)


# --- Per-tick upkeep ---------------------------------------------------------

func _tick_statuses() -> void:
	if tick % _ticks(BURN_INTERVAL) == 0:
		for c in casters:
			if c.burn > 0:
				_damage(c, c.burn * BURN_DAMAGE_PER_STACK * _amp(), "burn", {"stacks": c.burn})
				c.burn -= 1
	if tick % _ticks(CHILL_DECAY_INTERVAL) == 0:
		for c in casters:
			if c.chill > 0 and not c.chill_permanent:
				c.chill -= 1


func _regen_mana() -> void:
	for c in casters:
		var w := c.wand
		w.mana = minf(w.frame.mana_max, w.mana + w.frame.mana_regen * TICK)


func _check_end() -> void:
	var dead_a := casters[0].hp <= 0.0
	var dead_b := casters[1].hp <= 0.0
	if dead_a and dead_b:
		winner = DRAW
	elif dead_a:
		winner = 1
	elif dead_b:
		winner = 0
	elif seconds() >= hard_cap_seconds:
		var fa := casters[0].hp / casters[0].max_hp
		var fb := casters[1].hp / casters[1].max_hp
		winner = DRAW if is_equal_approx(fa, fb) else (0 if fa > fb else 1)
	if winner != RUNNING:
		_log("end", winner, {"hp": [snappedf(casters[0].hp, 0.01), snappedf(casters[1].hp, 0.01)]})


func _amp() -> float:
	var start := fight_seconds * ESCALATION_START
	var t := seconds()
	if t <= start:
		return 1.0
	return 1.0 + (amp_at_end - 1.0) * (t - start) / (fight_seconds - start)


func _ticks(secs: float) -> int:
	return roundi(secs * TICKS_PER_SECOND)


func _status_snapshot(c: Caster) -> Dictionary:
	return {"burn": c.burn, "chill": c.chill, "wet": c.wet, "shock": c.shock, "frozen": c.frozen}


func _log(type: String, who: int, data: Dictionary = {}) -> void:
	var e := {"tick": tick, "type": type, "who": who}
	e.merge(data)
	events.append(e)
