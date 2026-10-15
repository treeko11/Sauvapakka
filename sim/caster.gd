class_name Caster
extends RefCounted
## One wizard's live state during a duel.

var index := 0
var name := ""
var max_hp := 320.0
var hp := max_hp

var burn := 0
var chill := 0
## Set by Glacier Wand chill; stops decay until the target freezes.
var chill_permanent := false
var frozen := false
var wet := 0
var shock := 0

var wards := 0
var reflects := 0
## Spells to skip on upcoming draws.
var silence := 0

var wand: WandState
