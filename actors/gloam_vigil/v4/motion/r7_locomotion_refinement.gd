extends RefCounted

## Presentation-only refinement of the licensed CMU retarget for the frozen R7
## anatomy. The capture still owns cadence and flexion timing; these bounded
## body-axis gains compensate for source-to-target proportion/rest differences.
## Gameplay root motion, contact windows and the frozen GLB remain untouched.

const THIGH_AXES := Vector3(1.0, 0.72, 0.58)
const FOOT_AXES := Vector3(1.0, 0.76, 1.0)
const LOWER_SPINE_AXES := Vector3(0.15, 1.0, 1.0)
const UPPER_SPINE_AXES := Vector3(0.30, 1.0, 1.0)
const CHEST_AXES := Vector3(1.0, 1.0, 1.0)
const NECK_AXES := Vector3(0.10, 1.0, 1.0)
const HEAD_AXES := Vector3(0.20, 1.0, 1.0)


static func refine(rotations: Dictionary) -> Dictionary:
	return refine_run(rotations)


static func refine_run(rotations: Dictionary) -> Dictionary:
	var result := rotations.duplicate()
	# Preserve captured sagittal hip flexion while reducing the excessive
	# abduction/external rotation produced when the source leg planes are applied
	# to R7's broader, spatially mirrored anatomical rest stance.
	for channel in [&"thigh.L", &"thigh.R"]:
		result[channel] = _scale_body_axes(result[channel] as Quaternion, THIGH_AXES)
	for channel in [&"foot.L", &"foot.R"]:
		result[channel] = _scale_body_axes(result[channel] as Quaternion, FOOT_AXES)

	# The source's pelvis keeps its captured weight transfer. On R7's longer
	# torso, however, its roughly 17 degree neck extension overwhelms the captured
	# forward spine and reads as a backward-looking jog. Preserve most of the
	# trunk drive while retaining only enough neck/head counter-rotation to keep
	# the gaze near the travel horizon.
	result[&"spine"] = _scale_body_axes(result[&"spine"] as Quaternion, LOWER_SPINE_AXES)
	result[&"spine_upper"] = _scale_body_axes(result[&"spine_upper"] as Quaternion, UPPER_SPINE_AXES)
	result[&"chest"] = _scale_body_axes(result[&"chest"] as Quaternion, CHEST_AXES)
	result[&"neck"] = _scale_body_axes(result[&"neck"] as Quaternion, NECK_AXES)
	result[&"head"] = _scale_body_axes(result[&"head"] as Quaternion, HEAD_AXES)
	return result


static func refine_walk(rotations: Dictionary) -> Dictionary:
	# The selected walk is already a relaxed upright capture with restrained arm
	# swing and narrow forward knee planes. Preserve it without reusing the run's
	# thigh attenuation or torso correction.
	return rotations.duplicate()


static func _scale_body_axes(rotation: Quaternion, axes: Vector3) -> Quaternion:
	var euler := rotation.normalized().get_euler()
	euler *= axes
	return Quaternion.from_euler(euler).normalized()
