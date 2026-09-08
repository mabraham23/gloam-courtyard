extends RefCounted

const AttackCatalog = preload("res://actors/player_attack_catalog.gd")

## Presentation-only action poses for the exact R7 review candidate.
##
## The controller remains authoritative for timing, collision, damage,
## invulnerability and root displacement. These normalized curves only replace
## the legacy mannequin rotations on the denser anatomical skeleton.

const TAKEDOWN_CONTACT := 0.34 / 1.10


static func sample(pose_state: StringName, pose_progress: float, attack_variant: StringName = AttackCatalog.RIGHT_PUNCH) -> Dictionary:
	var progress := clampf(pose_progress, 0.0, 1.0)
	match pose_state:
		&"strike":
			return _strike(progress, attack_variant)
		&"evade":
			return _evade(progress)
		&"takedown":
			return _takedown(progress)
	return {}


static func _strike(progress: float, attack_variant: StringName) -> Dictionary:
	if AttackCatalog.kind(attack_variant) == &"kick":
		return _kick(progress, attack_variant)
	return _punch(progress, attack_variant)


static func _punch(progress: float, attack_variant: StringName) -> Dictionary:
	# The frozen R7 suffixes are spatially mirrored: logical right is the .L
	# chain. Keep that mapping explicit so the visible side, not the source name,
	# owns the attack. Shoulder, chest, hip and rear heel lead/follow in sequence.
	var attack_suffix := _logical_bone_suffix(attack_variant)
	var guard_suffix := "R" if attack_suffix == "L" else "L"
	var side := -1.0 if attack_suffix == "L" else 1.0
	var contact := AttackCatalog.contact_progress(attack_variant)
	var anticipation := smoothstep(0.0, 0.16, progress) * (1.0 - smoothstep(0.23, contact, progress))
	var extension := smoothstep(0.15, contact, progress) * (1.0 - smoothstep(0.57, 0.90, progress))
	var brace := smoothstep(0.02, 0.18, progress) * (1.0 - smoothstep(0.67, 0.97, progress))
	var retract := smoothstep(contact + 0.08, 0.68, progress) * (1.0 - smoothstep(0.84, 0.99, progress))
	var retract_fold := retract * (1.0 - extension)
	# A low persistent fighting guard gives a buffered follow-up the same entry
	# silhouette as the prior recovery instead of flashing through hands-down idle.
	var guard_pose := 0.26 + 0.74 * brace
	var attack_ready := 0.26 * (1.0 - extension) * (1.0 - retract)
	var impact := smoothstep(contact - 0.075, contact, progress) * (1.0 - smoothstep(contact, contact + 0.15, progress))
	var result := {
		&"pelvis": _euler(0.065 * brace, side * (-0.13 * anticipation + 0.22 * extension), side * -0.022 * extension),
		&"spine": _euler(0.025 * brace, side * (-0.07 * anticipation + 0.11 * extension), side * 0.014 * extension),
		&"spine_upper": _euler(0.034 * brace, side * (-0.11 * anticipation + 0.17 * extension), side * 0.022 * extension),
		&"chest": _euler(0.04 * brace + 0.04 * impact, side * (-0.17 * anticipation + 0.27 * extension), side * 0.032 * extension),
		&"neck": _euler(-0.03 * impact, side * (0.06 * anticipation - 0.09 * extension), side * -0.012 * extension),
		&"head": _euler(-0.05 * impact, side * (0.07 * anticipation - 0.11 * extension), side * -0.016 * extension),
	}
	# Rear/attacking heel pivots while the opposite leg stays visibly loaded.
	result[StringName("thigh.%s" % attack_suffix)] = _euler(-0.08 * brace + 0.08 * extension, side * 0.04 * extension, side * -0.025 * brace)
	result[StringName("shin.%s" % attack_suffix)] = _euler(0.17 * brace, 0.0, 0.0)
	result[StringName("foot.%s" % attack_suffix)] = _euler(-0.10 * brace, side * 0.13 * extension, side * 0.025 * extension)
	result[StringName("ball.%s" % attack_suffix)] = _euler(0.16 * extension, 0.0, 0.0)
	result[StringName("thigh.%s" % guard_suffix)] = _euler(0.11 * brace - 0.08 * extension, 0.0, side * 0.02 * brace)
	result[StringName("shin.%s" % guard_suffix)] = _euler(0.23 * brace, 0.0, 0.0)
	result[StringName("foot.%s" % guard_suffix)] = _euler(-0.09 * brace, 0.0, 0.0)
	result[StringName("clavicle.%s" % attack_suffix)] = _euler(-0.18 * extension + 0.06 * anticipation, side * -0.04 * extension, side * 0.03 * extension)
	# The imported rest arm hangs nearly vertically. Pitch supplies the reach;
	# the substantial mirrored body-yaw below then draws that diagonal reach back
	# onto the opponent centerline instead of leaving the fist flared outside the
	# shoulder. This value comes from measured shoulder-to-fist contact geometry.
	result[StringName("upper_arm.%s" % attack_suffix)] = _euler(0.34 * anticipation - 1.54 * extension - 0.52 * retract_fold - 0.48 * attack_ready, side * (-0.11 * anticipation - 0.82 * extension + 0.10 * retract_fold), side * (0.065 * extension - 0.05 * retract_fold))
	result[StringName("upper_arm_twist.%s" % attack_suffix)] = _euler(-0.08 * extension, side * -0.09 * extension, side * 0.025 * extension)
	result[StringName("forearm.%s" % attack_suffix)] = _euler(0.94 * anticipation + 0.08 * extension - 2.35 * retract_fold - 2.65 * attack_ready, 0.0, side * -0.02 * extension)
	result[StringName("forearm_twist.%s" % attack_suffix)] = _euler(0.08 * anticipation, side * -0.07 * extension, 0.0)
	result[StringName("hand.%s" % attack_suffix)] = _euler(-0.07 * impact, 0.0, side * 0.022 * extension)
	result[StringName("clavicle.%s" % guard_suffix)] = _euler(-0.08 * guard_pose, side * 0.04 * guard_pose, side * -0.025 * guard_pose)
	result[StringName("upper_arm.%s" % guard_suffix)] = _euler(-0.48 * guard_pose, side * 0.12 * guard_pose, side * -0.08 * guard_pose)
	result[StringName("upper_arm_twist.%s" % guard_suffix)] = _euler(-0.08 * guard_pose, side * 0.08 * guard_pose, side * -0.025 * guard_pose)
	result[StringName("forearm.%s" % guard_suffix)] = _euler(-2.65 * guard_pose, side * 0.04 * guard_pose, 0.0)
	result[StringName("hand.%s" % guard_suffix)] = _euler(-0.09 * guard_pose, side * -0.05 * guard_pose, side * 0.035 * guard_pose)
	return result


static func _kick(progress: float, attack_variant: StringName) -> Dictionary:
	# A short load moves mass over the support foot before the free thigh lifts.
	# The knee leads, the shin opens at contact, and both chains recover before the
	# controller releases the planted root.
	var attack_suffix := _logical_bone_suffix(attack_variant)
	var support_suffix := "R" if attack_suffix == "L" else "L"
	var side := -1.0 if attack_suffix == "L" else 1.0
	var contact := AttackCatalog.contact_progress(attack_variant)
	var load := smoothstep(0.0, 0.15, progress) * (1.0 - smoothstep(0.24, contact, progress))
	var pickup := smoothstep(0.0, 0.13, progress) * (1.0 - smoothstep(contact + 0.04, 0.72, progress))
	var chamber := smoothstep(0.09, 0.27, progress) * (1.0 - smoothstep(contact + 0.06, 0.73, progress))
	var extension := smoothstep(0.27, contact, progress) * (1.0 - smoothstep(0.54, 0.74, progress))
	var rechamber := smoothstep(contact + 0.04, 0.60, progress) * (1.0 - smoothstep(0.82, 0.95, progress))
	var recover := smoothstep(0.70, 0.98, progress)
	var guard_wave := smoothstep(0.01, 0.16, progress) * (1.0 - recover)
	# Match the punch entry/exit convention: a light persistent guard prevents a
	# buffered kick from flashing through the hands-down idle pose for one frame.
	var guard := 0.26 + 0.74 * guard_wave
	var result := {
		&"pelvis": _euler(0.10 * load + 0.04 * chamber, side * (0.08 * load - 0.13 * extension), side * -0.12 * chamber),
		&"spine": _euler(-0.05 * extension + 0.05 * load, side * -0.04 * extension, side * 0.05 * chamber),
		&"spine_upper": _euler(-0.08 * extension + 0.06 * load, side * -0.06 * extension, side * 0.07 * chamber),
		&"chest": _euler(-0.15 * extension + 0.08 * load, side * -0.09 * extension, side * 0.10 * chamber),
		&"neck": _euler(0.06 * extension, side * 0.04 * extension, side * -0.035 * chamber),
		&"head": _euler(0.08 * extension, side * 0.055 * extension, side * -0.05 * chamber),
	}
	result[StringName("thigh.%s" % support_suffix)] = _euler(0.04 * load - 0.015 * extension, side * -0.025 * chamber, side * 0.035 * chamber)
	result[StringName("shin.%s" % support_suffix)] = _euler(0.055 * load + 0.018 * chamber, 0.0, 0.0)
	result[StringName("foot.%s" % support_suffix)] = _euler(-0.02 * load - 0.008 * chamber, side * 0.015 * chamber, 0.0)
	result[StringName("ball.%s" % support_suffix)] = _euler(0.025 * load, 0.0, 0.0)
	result[StringName("thigh.%s" % attack_suffix)] = _euler(-0.16 * pickup - 0.42 * chamber - 0.88 * extension - 0.54 * rechamber, side * 0.07 * chamber, side * -0.07 * chamber)
	result[StringName("thigh_twist.%s" % attack_suffix)] = _euler(-0.05 * chamber, side * 0.07 * extension, 0.0)
	result[StringName("shin.%s" % attack_suffix)] = _euler(0.34 * pickup + 1.18 * chamber - 1.02 * extension + 1.30 * rechamber, 0.0, 0.0)
	result[StringName("shin_twist.%s" % attack_suffix)] = _euler(0.05 * chamber, side * -0.04 * extension, 0.0)
	result[StringName("foot.%s" % attack_suffix)] = _euler(-0.10 * pickup - 0.30 * chamber + 0.14 * extension - 0.12 * rechamber, 0.0, side * 0.035 * extension)
	result[StringName("ball.%s" % attack_suffix)] = _euler(-0.12 * extension, 0.0, 0.0)
	# Both hands protect the head; the arm opposite the kick counterbalances a
	# little wider without turning the body into an exaggerated windmill.
	result[StringName("clavicle.%s" % attack_suffix)] = _euler(-0.07 * guard, side * 0.05 * guard, side * -0.03 * guard)
	result[StringName("upper_arm.%s" % attack_suffix)] = _euler(-0.62 * guard, side * 0.14 * guard, side * -0.08 * guard)
	result[StringName("forearm.%s" % attack_suffix)] = _euler(-1.40 * guard, 0.0, 0.0)
	result[StringName("clavicle.%s" % support_suffix)] = _euler(-0.10 * guard, side * -0.07 * guard, side * 0.04 * guard)
	result[StringName("upper_arm.%s" % support_suffix)] = _euler(-0.70 * guard, side * -0.15 * guard, side * 0.10 * guard)
	result[StringName("forearm.%s" % support_suffix)] = _euler(-1.38 * guard, 0.0, 0.0)
	return result


static func _logical_bone_suffix(attack_variant: StringName) -> String:
	return "L" if AttackCatalog.side(attack_variant) > 0.0 else "R"


static func _evade(progress: float) -> Dictionary:
	# The action pivot performs the controller-facing somersault. The skeleton
	# compresses into a human forward roll instead of carrying a standing body
	# through a high rigid flip, then opens before invulnerability expires.
	var load := smoothstep(0.0, 0.10, progress) * (1.0 - smoothstep(0.16, 0.34, progress))
	var tuck := smoothstep(0.08, 0.24, progress) * (1.0 - smoothstep(0.58, 0.80, progress))
	var open := smoothstep(0.60, 0.78, progress) * (1.0 - smoothstep(0.90, 1.0, progress))
	var absorb := smoothstep(0.72, 0.86, progress) * (1.0 - smoothstep(0.91, 1.0, progress))
	return {
		&"pelvis": _euler(0.30 * load + 0.48 * tuck + 0.17 * absorb, 0.025 * tuck, -0.055 * tuck),
		&"spine": _euler(0.22 * load + 0.28 * tuck + 0.09 * absorb, 0.0, 0.035 * tuck),
		&"spine_upper": _euler(0.28 * load + 0.38 * tuck + 0.11 * absorb, 0.0, 0.045 * tuck),
		&"chest": _euler(0.34 * load + 0.50 * tuck + 0.13 * absorb, 0.0, 0.055 * tuck),
		&"neck": _euler(-0.22 * tuck - 0.05 * absorb, 0.0, -0.025 * tuck),
		&"head": _euler(-0.38 * tuck - 0.10 * absorb, 0.0, -0.035 * tuck),
		&"thigh.L": _euler(-0.62 * load - 1.05 * tuck - 0.26 * absorb, -0.08 * tuck, -0.12 * tuck),
		&"thigh_twist.L": _euler(-0.10 * tuck, -0.06 * tuck, 0.0),
		&"shin.L": _euler(0.92 * load + 1.62 * tuck + 0.62 * absorb, 0.0, 0.0),
		&"shin_twist.L": _euler(0.12 * tuck, 0.0, 0.0),
		&"foot.L": _euler(-0.30 * tuck - 0.19 * absorb, 0.0, 0.04 * tuck),
		&"thigh.R": _euler(-0.48 * load - 0.86 * tuck - 0.20 * absorb, 0.08 * tuck, 0.10 * tuck),
		&"thigh_twist.R": _euler(-0.08 * tuck, 0.06 * tuck, 0.0),
		&"shin.R": _euler(0.78 * load + 1.38 * tuck + 0.70 * absorb, 0.0, 0.0),
		&"shin_twist.R": _euler(0.10 * tuck, 0.0, 0.0),
		&"foot.R": _euler(-0.24 * tuck - 0.22 * absorb, 0.0, -0.04 * tuck),
		&"clavicle.L": _euler(-0.06 * tuck, 0.08 * tuck, -0.06 * tuck),
		&"upper_arm.L": _euler(-0.76 * tuck + 0.20 * open, -0.30 * tuck, -0.34 * tuck),
		&"upper_arm_twist.L": _euler(-0.08 * tuck, -0.08 * tuck, -0.04 * tuck),
		&"forearm.L": _euler(1.18 * tuck - 0.18 * open, 0.0, 0.0),
		&"forearm_twist.L": _euler(0.10 * tuck, -0.05 * tuck, 0.0),
		&"clavicle.R": _euler(-0.08 * tuck, -0.06 * tuck, 0.06 * tuck),
		&"upper_arm.R": _euler(-1.02 * tuck + 0.16 * open, 0.20 * tuck, 0.25 * tuck),
		&"upper_arm_twist.R": _euler(-0.10 * tuck, 0.07 * tuck, 0.035 * tuck),
		&"forearm.R": _euler(0.94 * tuck - 0.14 * open, 0.0, 0.0),
		&"forearm_twist.R": _euler(0.08 * tuck, 0.04 * tuck, 0.0),
	}


static func _takedown(progress: float) -> Dictionary:
	# Contact is synchronized with PLAYER_TAKEDOWN_CONTACT. The player reaches
	# with separated hands, anchors a wide base, then draws the target across the
	# hip before releasing rather than performing an unconstrained helmet shove.
	var reach := smoothstep(0.0, 0.20, progress)
	var contact_hold := reach * (1.0 - smoothstep(0.78, 0.96, progress))
	var draw := smoothstep(TAKEDOWN_CONTACT, 0.60, progress) * (1.0 - smoothstep(0.78, 0.96, progress))
	var brace := smoothstep(0.04, 0.22, progress) * (1.0 - smoothstep(0.82, 1.0, progress))
	return {
		&"pelvis": _euler(0.10 * brace + 0.08 * draw, -0.16 * draw, -0.08 * draw),
		&"spine": _euler(0.07 * contact_hold + 0.12 * draw, 0.08 * draw, 0.04 * draw),
		&"spine_upper": _euler(0.10 * contact_hold + 0.18 * draw, 0.11 * draw, 0.055 * draw),
		&"chest": _euler(0.15 * contact_hold + 0.28 * draw, 0.15 * draw, 0.08 * draw),
		&"neck": _euler(-0.08 * contact_hold - 0.06 * draw, -0.06 * draw, -0.025 * draw),
		&"head": _euler(-0.14 * contact_hold - 0.10 * draw, -0.09 * draw, -0.04 * draw),
		&"thigh.L": _euler(-0.28 * brace - 0.10 * draw, -0.05 * brace, -0.08 * brace),
		&"thigh_twist.L": _euler(-0.05 * brace, 0.0, 0.0),
		&"shin.L": _euler(0.52 * brace + 0.20 * draw, 0.0, 0.0),
		&"foot.L": _euler(-0.22 * brace - 0.06 * draw, 0.0, 0.0),
		&"thigh.R": _euler(-0.12 * brace - 0.06 * draw, 0.06 * brace, 0.08 * brace),
		&"thigh_twist.R": _euler(-0.025 * brace, 0.0, 0.0),
		&"shin.R": _euler(0.34 * brace + 0.15 * draw, 0.0, 0.0),
		&"foot.R": _euler(-0.14 * brace - 0.04 * draw, 0.0, 0.0),
		&"clavicle.L": _euler(-0.14 * contact_hold + 0.06 * draw, 0.10 * contact_hold, -0.06 * contact_hold),
		&"upper_arm.L": _euler(-1.30 * contact_hold + 0.28 * draw, -0.34 * contact_hold, -0.14 * contact_hold),
		&"upper_arm_twist.L": _euler(-0.10 * contact_hold, -0.10 * contact_hold, 0.0),
		&"forearm.L": _euler(1.12 * contact_hold - 0.52 * draw, 0.0, 0.08 * contact_hold),
		&"forearm_twist.L": _euler(0.10 * contact_hold, -0.06 * contact_hold, 0.0),
		&"hand.L": _euler(-0.10 * contact_hold, 0.12 * contact_hold, 0.0),
		&"clavicle.R": _euler(-0.18 * contact_hold + 0.08 * draw, -0.08 * contact_hold, 0.06 * contact_hold),
		&"upper_arm.R": _euler(-1.52 * contact_hold + 0.62 * draw, 0.28 * contact_hold, 0.16 * contact_hold),
		&"upper_arm_twist.R": _euler(-0.12 * contact_hold, 0.10 * contact_hold, 0.0),
		&"forearm.R": _euler(0.84 * contact_hold + 0.62 * draw, 0.0, -0.08 * contact_hold),
		&"forearm_twist.R": _euler(0.08 * contact_hold, 0.06 * contact_hold, 0.0),
		&"hand.R": _euler(-0.08 * contact_hold, -0.10 * contact_hold, 0.0),
	}


static func _euler(x: float, y: float, z: float) -> Quaternion:
	return Quaternion.from_euler(Vector3(x, y, z)).normalized()
