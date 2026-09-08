extends RefCounted

## Compact runtime sampler for the licensed CMU 16_31 walk reference.
## This is a genuinely separate captured motion from the run/jog clip. The
## generated JSON contains presentation deltas only; gameplay owns translation.

const DATA_PATH := "res://actors/gloam_vigil/v4/motion/cmu_16_31_walk_retarget.json"

static var _data: Dictionary = {}


static func cycle_rate() -> float:
	_ensure_loaded()
	return TAU / float(_data["cycle_seconds"])


static func contact_window(side: String) -> Vector2:
	_ensure_loaded()
	var values: Array = _data["contact_windows"][side]
	return Vector2(float(values[0]), float(values[1]))


static func source_sha256() -> String:
	_ensure_loaded()
	return String(_data["source_sha256"])


static func data_sha256() -> String:
	return FileAccess.get_sha256(DATA_PATH)


static func sample(phase: float) -> Dictionary:
	_ensure_loaded()
	var samples: Array = _data["samples"]
	var count := samples.size()
	var cursor: float = fposmod(phase, TAU) / TAU * float(count)
	var first := int(floor(cursor)) % count
	var second := (first + 1) % count
	var amount: float = cursor - floorf(cursor)
	var a: Dictionary = samples[first]
	var b: Dictionary = samples[second]
	var rotations: Dictionary = {}
	for channel: String in a["rotations"]:
		var qa := _quaternion(a["rotations"][channel] as Array)
		var qb := _quaternion(b["rotations"][channel] as Array)
		rotations[StringName(channel)] = qa.slerp(qb, amount).normalized()
	var root_a := _vector(a["root"] as Array)
	var root_b := _vector(b["root"] as Array)
	return {
		"rotations": rotations,
		"root": root_a.lerp(root_b, amount),
	}


static func _ensure_loaded() -> void:
	if not _data.is_empty():
		return
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	assert(file != null, "Missing CMU walk retarget data: %s" % DATA_PATH)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	assert(parsed is Dictionary and parsed.get("format", "") == "gloam-cmu-body-delta-v1", "Invalid CMU walk retarget data")
	_data = parsed


static func _quaternion(values: Array) -> Quaternion:
	# Generated data is WXYZ; Godot's constructor is XYZW.
	return Quaternion(float(values[1]), float(values[2]), float(values[3]), float(values[0]))


static func _vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))
