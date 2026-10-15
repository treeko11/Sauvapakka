class_name SpellDef
extends Resource
## One spell, defined entirely as data. Each export group is one effect primitive
## from the design scope; a spell is whatever combination of them it sets, so adding
## a spell never needs new code.
##
## Status fields mean "applies on hit" for projectiles and "adds to the next
## projectile" for modifiers. For multicasts, damage_mult and copies apply to every
## projectile the multicast draws.

enum Kind {
	PROJECTILE, ## Counts toward spells-per-cast and flies at the enemy.
	MODIFIER, ## Attaches to the next projectile and draws a replacement.
	MULTICAST, ## Replaces itself with `draw` projectiles in this cast.
	SELF, ## Counts toward spells-per-cast and resolves on the caster (wards).
	UTILITY, ## Affects the wand itself and draws a replacement.
}
enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }
enum Condition { NONE, TARGET_BURNING, TARGET_CHILLED, TARGET_WET, TARGET_SHOCKED, FIRST_CAST }

@export var id: StringName
@export var display_name: String
## The category shown on the card (Projectile, Modifier, Defence, ...).
@export var type_label: String
@export_multiline var description: String
@export var kind: Kind = Kind.PROJECTILE
@export var rarity: Rarity = Rarity.COMMON
@export var mana_cost: int = 0

@export_group("Damage")
@export var damage: float = 0.0
## Separate hits per arrival; each is checked against wards on its own.
@export var hits: int = 1
## Extra hits at reduced damage that apply no statuses.
@export var chain: int = 0
## Seconds from cast to arrival.
@export var travel_time: float = 0.5

@export_group("Status")
@export var burn: int = 0
@export var chill: int = 0
@export var wet: int = 0
@export var shock: int = 0

@export_group("Ward")
@export var ward_hits: int = 0
@export var reflect_hits: int = 0

@export_group("Modify")
@export var add_damage: float = 0.0
@export var damage_mult: float = 1.0
@export var add_pierce: int = 0
## The projectile becomes this many copies (0 or 1 means no split).
@export var split_into: int = 0
@export var speed_mult: float = 1.0
## Spends all of the wand's remaining mana; adds this much damage per mana spent.
@export var mana_to_damage: float = 0.0

@export_group("Draw")
@export var draw: int = 0

@export_group("Copy")
## Each projectile drawn by this multicast fires this many times.
@export var copies: int = 1

@export_group("Payload")
## Carries the next draw and fires it when this projectile makes contact.
@export var trigger: bool = false

@export_group("Timing")
@export var cast_delay: float = 0.0
@export var recharge: float = 0.0

@export_group("Mana")
@export var mana_refund: int = 0

@export_group("Disrupt")
@export var mana_drain: int = 0
@export var silence: int = 0
@export var delay_target: float = 0.0

@export_group("Condition")
@export var condition: Condition = Condition.NONE
@export var condition_damage_mult: float = 1.0
