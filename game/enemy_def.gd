class_name EnemyDef
extends Resource
## An enemy archetype. Regular enemies generate a wand from `spell_pool`; the boss
## uses `fixed_build`.

@export var id: StringName
@export var display_name: String
## Themed archetypes test a specific counter; generic ones fill most fights.
@export var themed := false
## Shown on the Preview screen for themed enemies; generic enemies show the
## traits their generated wand happens to have.
@export var traits: PackedStringArray
@export var counter: String
## Spell ids to draw from; repeat an id to weight it.
@export var spell_pool: PackedStringArray
## Named frames this archetype may use from `rule_frame_depth` on.
@export var frames: PackedStringArray
@export var rule_frame_depth := 3
@export var min_depth := 0
@export var max_depth := 9
@export var max_hp := 320.0
@export var robe := Color("6b6b73")
@export var fixed_build: WandBuild
