class_name FrameDef
extends Resource
## A wand frame: stats, plus an optional special rule on rare frames.

enum Rule { NONE, TWIN_FORK, EMBER_STAFF, GLACIER_WAND, LEYLINE_ROD, OUROBOROS }

@export var id: StringName
@export var display_name: String
@export var capacity: int = 5
@export var spells_per_cast: int = 1
@export var cast_delay: float = 0.25
@export var recharge_time: float = 0.6
@export var mana_max: float = 100.0
## Mana regained per second.
@export var mana_regen: float = 30.0
@export var shuffle: bool = false
@export var rule: Rule = Rule.NONE
