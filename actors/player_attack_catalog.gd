extends RefCounted

## Shared, controller-authoritative attack identities and timing.
##
## All four attacks keep the established damage and Momentum values in
## `main_3d.gd`.  This catalog only owns presentation/contact timing and reach,
## so the controller, R7 action layer, diagnostics, and legacy visual can agree
## on the exact same normalized contact beat.

const RIGHT_PUNCH: StringName = &"right_punch"
const LEFT_PUNCH: StringName = &"left_punch"
const LEFT_KICK: StringName = &"left_kick"
const RIGHT_KICK: StringName = &"right_kick"

const ORDER: Array[StringName] = [RIGHT_PUNCH, LEFT_PUNCH, LEFT_KICK, RIGHT_KICK]

const DATA := {
	RIGHT_PUNCH: {
		"duration": 0.36,
		"contact": 0.14,
		"reach": 2.20,
		"side": 1.0,
		"kind": &"punch",
		"label": "right straight",
	},
	LEFT_PUNCH: {
		"duration": 0.38,
		"contact": 0.15,
		"reach": 2.20,
		"side": -1.0,
		"kind": &"punch",
		"label": "left straight",
	},
	LEFT_KICK: {
		"duration": 0.50,
		"contact": 0.22,
		"reach": 2.38,
		"side": -1.0,
		"kind": &"kick",
		"label": "left front kick",
	},
	RIGHT_KICK: {
		"duration": 0.48,
		"contact": 0.21,
		"reach": 2.38,
		"side": 1.0,
		"kind": &"kick",
		"label": "right front kick",
	},
}


static func is_valid(variant: StringName) -> bool:
	return DATA.has(variant)


static func datum(variant: StringName) -> Dictionary:
	return DATA.get(variant, DATA[RIGHT_PUNCH])


static func duration(variant: StringName) -> float:
	return float(datum(variant)["duration"])


static func contact_time(variant: StringName) -> float:
	return float(datum(variant)["contact"])


static func contact_progress(variant: StringName) -> float:
	return contact_time(variant) / duration(variant)


static func reach(variant: StringName) -> float:
	return float(datum(variant)["reach"])


static func side(variant: StringName) -> float:
	return float(datum(variant)["side"])


static func kind(variant: StringName) -> StringName:
	return datum(variant)["kind"] as StringName


static func label(variant: StringName) -> String:
	return str(datum(variant)["label"])


static func maximum_reach() -> float:
	var result := 0.0
	for variant: StringName in ORDER:
		result = maxf(result, reach(variant))
	return result
