extends RefCounted

## Original character presentation for the active 3D spike.
## Gameplay state, labels, lights, movement, and combat remain in main_3d.gd.
## This builder owns actor silhouettes, articulated visual pivots, and pose
## blending. The player now uses a Blender-authored skinned GLB behind a narrow
## rig adapter; the accepted procedural player remains below as a preserved
## reference, and the courtyard guard remains procedural.

const PlayerJumpMotion = preload("res://actors/player_jump_motion.gd")

const GloamVigilRigAdapter = preload("res://actors/gloam_vigil/gloam_vigil_rig_adapter.gd")
const R7WalkReference = preload("res://actors/gloam_vigil/v4/motion/cmu_walk_reference.gd")
const R7RunReference = preload("res://actors/gloam_vigil/v4/motion/cmu_run_reference.gd")
const DEFAULT_PLAYER_V2 := false
const R7_SOURCE_TO_TARGET_ROOT_SCALE := 6.195


static func build_player(parent: Node3D, accent_color: Color, use_v2: bool = DEFAULT_PLAYER_V2, candidate_scene_path: String = "") -> Dictionary:
	var visual_root := _node(parent, "OriginalGloamVigilVisual", Vector3.ZERO)
	var footprint_material := _material(Color(accent_color, 0.24), 0.82)
	footprint_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var footprint := _cylinder(visual_root, Vector3(0.0, 0.018, 0.0), 0.47, 0.026, footprint_material)
	footprint.scale = Vector3(1.0, 1.0, 0.78)

	# Preserve the accepted visual-root bob/sway and center-pivot somersault.
	# These driver nodes carry only the existing pose curves; the adapter copies
	# their local rotations into the authored skeleton each frame.
	var action_root := _node(visual_root, "ActionPivot", Vector3(0.0, 0.95, 0.0))
	var body_root := _node(action_root, "AuthoredModelAlignment", Vector3(0.0, -0.95, 0.0))
	var pelvis_root := _node(body_root, "PelvisDriver", Vector3(0.0, 1.05, 0.0))
	var torso_root := _node(body_root, "TorsoDriver", Vector3(0.0, 1.15, 0.0))
	var head_root := _node(torso_root, "HeadDriver", Vector3(0.0, 0.59, 0.0))

	var left_leg := _node(body_root, "LeftHipDriver", Vector3(-0.18, 1.07, 0.0))
	var right_leg := _node(body_root, "RightHipDriver", Vector3(0.18, 1.07, 0.0))
	var left_knee := _node(left_leg, "LeftKneeDriver", Vector3(-0.012, -0.40, 0.018))
	var right_knee := _node(right_leg, "RightKneeDriver", Vector3(0.012, -0.40, 0.018))
	var left_ankle := _node(left_knee, "LeftAnkleDriver", Vector3(0.012, -0.43, 0.025))
	var right_ankle := _node(right_knee, "RightAnkleDriver", Vector3(-0.012, -0.43, 0.025))
	var left_arm := _node(torso_root, "LeftShoulderDriver", Vector3(-0.46, 0.39, 0.0))
	var right_arm := _node(torso_root, "RightShoulderDriver", Vector3(0.46, 0.39, 0.0))
	var left_elbow := _node(left_arm, "LeftElbowDriver", Vector3(-0.055, -0.34, 0.025))
	var right_elbow := _node(right_arm, "RightElbowDriver", Vector3(0.055, -0.34, 0.025))
	var left_tail := _node(pelvis_root, "LeftCapeDriver", Vector3(-0.16, 0.02, -0.105))
	var right_tail := _node(pelvis_root, "RightCapeDriver", Vector3(0.16, 0.02, -0.105))

	# Candidate selection is explicit in review harnesses until its visual,
	# deformation, mechanics and performance acceptance is complete.
	var rig := GloamVigilRigAdapter.attach(body_root, accent_color, use_v2, candidate_scene_path)
	var parts := {
		"visual_root": visual_root,
		"action_root": action_root,
		"accent_material": rig["accent_material"],
		"pelvis_root": pelvis_root,
		"torso_root": torso_root,
		"head_root": head_root,
		"left_leg": left_leg,
		"right_leg": right_leg,
		"left_knee": left_knee,
		"right_knee": right_knee,
		"left_ankle": left_ankle,
		"right_ankle": right_ankle,
		"left_arm": left_arm,
		"right_arm": right_arm,
		"left_elbow": left_elbow,
		"right_elbow": right_elbow,
		"left_tail": left_tail,
		"right_tail": right_tail,
		"authored_rig": rig,
	}
	GloamVigilRigAdapter.sync_pose(rig, parts)
	return parts


## Preserved superseded visual spike. This remains available for comparison and
## rollback evidence but is no longer instantiated by the active game.
static func build_procedural_player(parent: Node3D, accent_color: Color) -> Dictionary:
	var visual_root := _node(parent, "LayeredWayfarerVisual", Vector3.ZERO)
	var coat := _material(Color("#111a29"), 0.88)
	var coat_light := _material(Color("#24344a"), 0.72)
	var leather := _material(Color("#332a39"), 0.8)
	var boot := _material(Color("#090e18"), 0.9)
	var skin := _material(Color("#bba99d"), 0.92)
	var metal := _material(Color("#718197"), 0.42, 0.22)
	var accent := _material(accent_color, 0.56, 0.04, accent_color)
	var muted_accent := _material(Color(accent_color, 0.30), 0.78)
	muted_accent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var footprint := _cylinder(visual_root, Vector3(0.0, 0.018, 0.0), 0.44, 0.026, muted_accent)
	footprint.scale = Vector3(1.0, 1.0, 0.78)
	# ActionPivot rotates the body around its center while the footprint and
	# gameplay root stay grounded. BodyRoot cancels the pivot offset at rest.
	var action_root := _node(visual_root, "ActionPivot", Vector3(0.0, 0.95, 0.0))
	var body_root := _node(action_root, "BodyRoot", Vector3(0.0, -0.95, 0.0))

	# Hip, knee, and ankle pivots let the gait bend instead of swinging each leg
	# as a single block. Rounded toes and tapered segments keep the read athletic.
	var left_leg: Node3D
	var right_leg: Node3D
	var left_knee: Node3D
	var right_knee: Node3D
	var left_ankle: Node3D
	var right_ankle: Node3D
	for side in [-1.0, 1.0]:
		var hip := _node(body_root, "LeftHip" if side < 0.0 else "RightHip", Vector3(side * 0.18, 1.07, 0.0))
		var knee_offset := Vector3(side * 0.012, -0.40, 0.018)
		_tapered_limb(hip, Vector3.ZERO, knee_offset, 0.145, 0.118, coat, 1.0)
		var knee := _node(hip, "LeftKnee" if side < 0.0 else "RightKnee", knee_offset)
		var knee_cap := _sphere(knee, Vector3(0.0, 0.0, 0.035), 0.122, leather)
		knee_cap.scale = Vector3(0.94, 0.82, 0.72)
		var ankle_offset := Vector3(-side * 0.012, -0.43, 0.025)
		_tapered_limb(knee, Vector3(0.0, -0.02, 0.0), ankle_offset, 0.112, 0.085, coat_light, 1.0)
		var ankle := _node(knee, "LeftAnkle" if side < 0.0 else "RightAnkle", ankle_offset)
		_cylinder(ankle, Vector3(0.0, 0.005, 0.0), 0.102, 0.13, boot)
		var foot := _capsule(ankle, Vector3(0.0, -0.075, 0.13), 0.112, 0.39, boot, Vector3(PI * 0.5, 0.0, 0.0))
		foot.scale = Vector3(0.88, 1.0, 0.74)
		foot.rotation.y = side * 0.045
		var toe := _sphere(ankle, Vector3(0.0, -0.075, 0.285), 0.112, boot)
		toe.scale = Vector3(0.90, 0.62, 1.18)
		if side < 0.0:
			left_leg = hip
			left_knee = knee
			left_ankle = ankle
		else:
			right_leg = hip
			right_knee = knee
			right_ankle = ankle

	# Separate pelvis and torso pivots produce weight shift and counter-rotation.
	var pelvis_root := _node(body_root, "PelvisPivot", Vector3(0.0, 1.05, 0.0))
	var pelvis := _sphere(pelvis_root, Vector3.ZERO, 0.31, leather)
	pelvis.scale = Vector3(1.0, 0.56, 0.76)
	var belt := _cylinder(pelvis_root, Vector3(0.0, 0.105, 0.0), 0.30, 0.105, accent)
	belt.scale = Vector3(1.0, 1.0, 0.78)
	var buckle := _sphere(pelvis_root, Vector3(0.0, 0.105, 0.235), 0.064, metal)
	buckle.scale = Vector3(1.15, 0.82, 0.44)

	# Split coat tails have pivots so the cloth can lag the step.
	var left_tail := _node(pelvis_root, "LeftCoatTail", Vector3(-0.16, 0.02, -0.105))
	var right_tail := _node(pelvis_root, "RightCoatTail", Vector3(0.16, 0.02, -0.105))
	for tail_data in [[left_tail, -1.0], [right_tail, 1.0]]:
		var tail: Node3D = tail_data[0]
		var side: float = tail_data[1]
		var cloth := _tapered(tail, Vector3(side * 0.025, -0.28, 0.0), 0.11, 0.17, 0.58, coat)
		cloth.scale = Vector3(1.0, 1.0, 0.42)
		cloth.rotation.z = side * 0.045
		var hem := _capsule(tail, Vector3(side * 0.028, -0.56, 0.0), 0.105, 0.19, coat_light, Vector3(0.0, 0.0, PI * 0.5))
		hem.scale = Vector3(1.0, 1.0, 0.38)

	var torso_root := _node(body_root, "TorsoPivot", Vector3(0.0, 1.15, 0.0))
	var waist := _tapered(torso_root, Vector3(0.0, 0.10, 0.0), 0.30, 0.25, 0.27, coat)
	waist.scale = Vector3(1.0, 1.0, 0.78)
	var ribcage := _sphere(torso_root, Vector3(0.0, 0.31, -0.006), 0.39, coat_light)
	ribcage.scale = Vector3(1.08, 0.84, 0.72)
	var chest_layer := _sphere(torso_root, Vector3(0.0, 0.30, 0.245), 0.29, coat)
	chest_layer.scale = Vector3(0.92, 0.77, 0.22)
	var sash := _capsule(torso_root, Vector3(-0.045, 0.29, 0.31), 0.052, 0.49, accent, Vector3(0.0, 0.0, -0.30))
	sash.scale = Vector3(1.0, 1.0, 0.55)
	var mantle := _capsule(torso_root, Vector3(0.0, 0.46, -0.015), 0.155, 0.96, leather, Vector3(0.0, 0.0, PI * 0.5))
	mantle.scale = Vector3(1.0, 1.0, 0.88)
	var collar := _tapered(torso_root, Vector3(0.0, 0.51, 0.0), 0.17, 0.22, 0.16, coat)
	collar.scale = Vector3(1.0, 1.0, 0.82)

	# Shoulder, elbow, and wrist pivots describe a relaxed arm arc.
	var left_arm: Node3D
	var right_arm: Node3D
	var left_elbow: Node3D
	var right_elbow: Node3D
	for side in [-1.0, 1.0]:
		var shoulder_cap := _sphere(torso_root, Vector3(side * 0.46, 0.39, 0.0), 0.18, leather)
		shoulder_cap.scale = Vector3(0.86, 1.0, 0.88)
		var shoulder := _node(torso_root, "LeftShoulder" if side < 0.0 else "RightShoulder", Vector3(side * 0.46, 0.39, 0.0))
		var elbow_offset := Vector3(side * 0.055, -0.34, 0.025)
		_tapered_limb(shoulder, Vector3.ZERO, elbow_offset, 0.112, 0.092, coat_light, 1.0)
		var elbow := _node(shoulder, "LeftElbow" if side < 0.0 else "RightElbow", elbow_offset)
		var elbow_cap := _sphere(elbow, Vector3.ZERO, 0.103, leather)
		elbow_cap.scale = Vector3(0.86, 0.82, 0.80)
		var wrist_offset := Vector3(-side * 0.022, -0.31, 0.095)
		_tapered_limb(elbow, Vector3(0.0, -0.015, 0.0), wrist_offset, 0.092, 0.071, coat, 1.0)
		var wrist := _node(elbow, "LeftWrist" if side < 0.0 else "RightWrist", wrist_offset)
		if side > 0.0:
			_cylinder(wrist, Vector3(0.0, 0.015, 0.0), 0.088, 0.075, accent)
		var hand := _capsule(wrist, Vector3(0.0, -0.09, 0.018), 0.079, 0.20, boot, Vector3.ZERO)
		hand.scale = Vector3(0.78, 1.0, 0.70)
		var knuckles := _sphere(wrist, Vector3(0.0, -0.175, 0.040), 0.079, boot)
		knuckles.scale = Vector3(0.94, 0.62, 0.78)
		if side < 0.0:
			left_arm = shoulder
			left_elbow = elbow
		else:
			right_arm = shoulder
			right_elbow = elbow

	# A readable neck, jaw, rounded hood, inset face, and brow replace the ball head.
	var head_root := _node(torso_root, "HeadPivot", Vector3(0.0, 0.59, 0.0))
	_cylinder(head_root, Vector3(0.0, -0.025, 0.0), 0.105, 0.16, skin)
	var hood := _sphere(head_root, Vector3(0.0, 0.205, -0.035), 0.285, coat)
	hood.scale = Vector3(0.90, 1.12, 0.92)
	var hood_crown := _tapered(head_root, Vector3(0.0, 0.395, -0.07), 0.03, 0.17, 0.20, coat)
	hood_crown.rotation.x = -0.10
	var face := _sphere(head_root, Vector3(0.0, 0.195, 0.135), 0.195, skin)
	face.scale = Vector3(0.82, 1.08, 0.58)
	var jaw_frame := _capsule(head_root, Vector3(0.0, 0.09, 0.235), 0.075, 0.31, leather, Vector3(0.0, 0.0, PI * 0.5))
	jaw_frame.scale = Vector3(1.0, 1.0, 0.45)
	var brow := _capsule(head_root, Vector3(0.0, 0.265, 0.248), 0.042, 0.32, coat, Vector3(0.0, 0.0, PI * 0.5))
	brow.scale = Vector3(1.0, 1.0, 0.48)
	var nose := _sphere(head_root, Vector3(0.0, 0.19, 0.252), 0.040, skin)
	nose.scale = Vector3(0.68, 0.92, 1.05)
	var clasp := _sphere(torso_root, Vector3(0.0, 0.50, 0.225), 0.068, metal)
	clasp.scale = Vector3(1.15, 0.8, 0.55)

	return {
		"visual_root": visual_root,
		"action_root": action_root,
		"accent_material": accent,
		"pelvis_root": pelvis_root,
		"torso_root": torso_root,
		"head_root": head_root,
		"left_leg": left_leg,
		"right_leg": right_leg,
		"left_knee": left_knee,
		"right_knee": right_knee,
		"left_ankle": left_ankle,
		"right_ankle": right_ankle,
		"left_arm": left_arm,
		"right_arm": right_arm,
		"left_elbow": left_elbow,
		"right_elbow": right_elbow,
		"left_tail": left_tail,
		"right_tail": right_tail,
	}


static func build_guard(parent: Node3D) -> Dictionary:
	var visual_root := _node(parent, "CourtyardWardenVisual", Vector3.ZERO)
	var uniform := _material(Color("#303a4a"), 0.8)
	var armor := _material(Color("#81523f"), 0.66, 0.05)
	var dark_armor := _material(Color("#171f2c"), 0.82)
	var boot := _material(Color("#0b0f17"), 0.92)
	var brass := _material(Color("#ad8254"), 0.48, 0.28)
	var skin := _material(Color("#a89180"), 0.92)
	var rank_cloth := _material(Color("#a13f50"), 0.62, 0.02, Color("#702d39"))
	var footprint_material := _material(Color("#9e394d", 0.26), 0.82)
	footprint_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var footprint := _cylinder(visual_root, Vector3(0.0, 0.018, 0.0), 0.48, 0.026, footprint_material)
	footprint.scale = Vector3(1.0, 1.0, 0.80)
	# Keep the marker planted while a shared floor pivot carries the articulated
	# body through takedown and defeat. Rotating independent torso/leg segments
	# made the old victim finish balanced on their helmet with upright boots.
	var body_root := _node(visual_root, "BodyPivot", Vector3.ZERO)

	# A heavier articulation keeps the warden planted without crate-like greaves.
	var left_leg: Node3D
	var right_leg: Node3D
	var left_knee: Node3D
	var right_knee: Node3D
	var left_ankle: Node3D
	var right_ankle: Node3D
	for side in [-1.0, 1.0]:
		var hip := _node(body_root, "LeftHip" if side < 0.0 else "RightHip", Vector3(side * 0.205, 1.08, 0.0))
		var knee_offset := Vector3(side * 0.012, -0.41, 0.015)
		_tapered_limb(hip, Vector3.ZERO, knee_offset, 0.154, 0.126, uniform, 1.0)
		var knee := _node(hip, "LeftKnee" if side < 0.0 else "RightKnee", knee_offset)
		var knee_cap := _sphere(knee, Vector3(0.0, 0.0, 0.045), 0.135, dark_armor)
		knee_cap.scale = Vector3(0.94, 0.80, 0.76)
		var ankle_offset := Vector3(-side * 0.010, -0.43, 0.025)
		_tapered_limb(knee, Vector3(0.0, -0.02, 0.0), ankle_offset, 0.124, 0.096, uniform, 1.0)
		var greave := _tapered_limb(knee, Vector3(0.0, -0.055, 0.075), Vector3(0.0, -0.35, 0.105), 0.112, 0.086, armor, 0.54)
		greave.scale.x = 0.84
		var ankle := _node(knee, "LeftAnkle" if side < 0.0 else "RightAnkle", ankle_offset)
		_cylinder(ankle, Vector3(0.0, 0.005, 0.0), 0.112, 0.14, boot)
		var foot := _capsule(ankle, Vector3(0.0, -0.078, 0.145), 0.124, 0.43, boot, Vector3(PI * 0.5, 0.0, 0.0))
		foot.scale = Vector3(0.92, 1.0, 0.78)
		foot.rotation.y = side * -0.035
		var toe := _sphere(ankle, Vector3(0.0, -0.078, 0.315), 0.123, boot)
		toe.scale = Vector3(0.94, 0.62, 1.15)
		if side < 0.0:
			left_leg = hip
			left_knee = knee
			left_ankle = ankle
		else:
			right_leg = hip
			right_knee = knee
			right_ankle = ankle

	var pelvis_root := _node(body_root, "PelvisPivot", Vector3(0.0, 1.06, 0.0))
	var pelvis := _sphere(pelvis_root, Vector3.ZERO, 0.34, dark_armor)
	pelvis.scale = Vector3(1.0, 0.55, 0.76)
	var belt := _cylinder(pelvis_root, Vector3(0.0, 0.105, 0.0), 0.35, 0.13, brass)
	belt.scale = Vector3(1.0, 1.0, 0.80)
	var belt_plate := _sphere(pelvis_root, Vector3(-0.15, 0.105, 0.265), 0.080, armor)
	belt_plate.scale = Vector3(1.3, 0.9, 0.42)

	var torso_root := _node(body_root, "TorsoPivot", Vector3(0.0, 1.17, 0.0))
	var waist := _tapered(torso_root, Vector3(0.0, 0.09, 0.0), 0.34, 0.29, 0.27, uniform)
	waist.scale = Vector3(1.0, 1.0, 0.80)
	var ribcage := _sphere(torso_root, Vector3(0.0, 0.30, -0.005), 0.41, uniform)
	ribcage.scale = Vector3(1.06, 0.82, 0.74)
	var breastplate := _sphere(torso_root, Vector3(0.0, 0.29, 0.255), 0.34, armor)
	breastplate.scale = Vector3(1.02, 0.70, 0.28)
	var rank_strip := _capsule(torso_root, Vector3(0.0, 0.29, 0.345), 0.052, 0.40, rank_cloth, Vector3.ZERO)
	rank_strip.scale = Vector3(1.0, 1.0, 0.48)
	var gorget := _tapered(torso_root, Vector3(0.0, 0.50, 0.0), 0.17, 0.235, 0.16, dark_armor)
	gorget.scale = Vector3(1.0, 1.0, 0.84)

	var left_arm: Node3D
	var right_arm: Node3D
	var left_elbow: Node3D
	var right_elbow: Node3D
	var right_wrist: Node3D
	for side in [-1.0, 1.0]:
		var pauldron := _sphere(torso_root, Vector3(side * 0.49, 0.38, 0.0), 0.215, armor)
		pauldron.scale = Vector3(1.10, 0.72, 0.94)
		var shoulder := _node(torso_root, "LeftShoulder" if side < 0.0 else "RightShoulder", Vector3(side * 0.49, 0.37, 0.0))
		var elbow_offset := Vector3(side * 0.060, -0.34, 0.025)
		_tapered_limb(shoulder, Vector3.ZERO, elbow_offset, 0.124, 0.102, uniform, 1.0)
		var elbow := _node(shoulder, "LeftElbow" if side < 0.0 else "RightElbow", elbow_offset)
		var elbow_cap := _sphere(elbow, Vector3.ZERO, 0.115, dark_armor)
		elbow_cap.scale = Vector3(0.88, 0.80, 0.84)
		var hand_z := 0.135 if side > 0.0 else 0.075
		var wrist_offset := Vector3(side * 0.018, -0.31, hand_z)
		_tapered_limb(elbow, Vector3(0.0, -0.015, 0.0), wrist_offset, 0.105, 0.080, armor, 1.0)
		var wrist := _node(elbow, "LeftWrist" if side < 0.0 else "RightWrist", wrist_offset)
		var glove := _capsule(wrist, Vector3(0.0, -0.09, 0.02), 0.086, 0.21, boot, Vector3.ZERO)
		glove.scale = Vector3(0.82, 1.0, 0.76)
		var knuckles := _sphere(wrist, Vector3(0.0, -0.175, 0.045), 0.085, boot)
		knuckles.scale = Vector3(0.96, 0.62, 0.86)
		if side < 0.0:
			left_arm = shoulder
			left_elbow = elbow
		else:
			right_arm = shoulder
			right_elbow = elbow
			right_wrist = wrist

	# Rounded layered helmet and a tapered utilitarian crest preserve identity.
	var head_root := _node(torso_root, "HeadPivot", Vector3(0.0, 0.59, 0.0))
	_cylinder(head_root, Vector3(0.0, -0.025, 0.0), 0.115, 0.16, skin)
	var head := _sphere(head_root, Vector3(0.0, 0.18, 0.035), 0.24, skin)
	head.scale = Vector3(0.86, 1.08, 0.82)
	var jaw := _sphere(head_root, Vector3(0.0, 0.08, 0.105), 0.17, skin)
	jaw.scale = Vector3(0.78, 0.70, 0.72)
	var helmet := _sphere(head_root, Vector3(0.0, 0.285, -0.015), 0.295, dark_armor)
	helmet.scale = Vector3(1.04, 0.72, 1.02)
	var helmet_band := _capsule(head_root, Vector3(0.0, 0.265, 0.235), 0.050, 0.47, brass, Vector3(0.0, 0.0, PI * 0.5))
	helmet_band.scale = Vector3(1.0, 1.0, 0.58)
	var brow := _capsule(head_root, Vector3(0.0, 0.16, 0.255), 0.047, 0.32, dark_armor, Vector3(0.0, 0.0, PI * 0.5))
	brow.scale = Vector3(1.0, 1.0, 0.52)
	var rear_guard := _tapered(head_root, Vector3(0.0, -0.015, -0.105), 0.22, 0.17, 0.20, dark_armor)
	rear_guard.scale.z = 0.72
	var crest := _tapered(head_root, Vector3(0.0, 0.49, -0.02), 0.018, 0.075, 0.25, armor)
	crest.scale.z = 0.48

	# The original short watch-blade follows the articulated weapon arm.
	var weapon_root := _node(right_wrist, "WatchBlade", Vector3(0.10, -0.06, 0.04))
	weapon_root.rotation.z = -0.10
	_cylinder(weapon_root, Vector3.ZERO, 0.035, 0.92, dark_armor)
	var blade_guard := _capsule(weapon_root, Vector3(0.0, 0.50, 0.0), 0.043, 0.19, brass, Vector3(0.0, 0.0, PI * 0.5))
	blade_guard.scale.z = 0.70
	var blade := _tapered(weapon_root, Vector3(0.0, 0.67, 0.0), 0.018, 0.072, 0.30, armor)
	blade.scale.z = 0.42
	blade.rotation.z = 0.08

	return {
		"visual_root": visual_root,
		"body_root": body_root,
		"pelvis_root": pelvis_root,
		"torso_root": torso_root,
		"head_root": head_root,
		"left_leg": left_leg,
		"right_leg": right_leg,
		"left_knee": left_knee,
		"right_knee": right_knee,
		"left_ankle": left_ankle,
		"right_ankle": right_ankle,
		"left_arm": left_arm,
		"right_arm": right_arm,
		"left_elbow": left_elbow,
		"right_elbow": right_elbow,
	}


static func pose_player(parts: Dictionary, phase: float, movement_amount: float, delta: float, pose_state: StringName = &"grounded", pose_progress := 0.0, attack_variant: StringName = &"right_punch", run_amount := 0.0, jump_lead := 1.0, jump_moving := false) -> void:
	var anatomical_profile := parts.has("authored_rig") and bool(parts["authored_rig"].get("anatomical_profile", false))
	var movement := smoothstep(0.0, 1.0, clampf(movement_amount, 0.0, 1.0))
	var gait := sin(phase)
	var step_height := (1.0 - cos(phase * 2.0)) * 0.5
	var weight_shift := gait * movement
	var idle := sin(phase * 0.72 + 0.4) * (1.0 - movement)
	var left_leg_target := gait * 0.32 * movement
	var right_leg_target := -left_leg_target
	var left_knee_target := 0.055 + maxf(-gait, 0.0) * 0.46 * movement
	var right_knee_target := 0.055 + maxf(gait, 0.0) * 0.46 * movement
	var left_ankle_target := -left_leg_target * 0.32 - left_knee_target * 0.16
	var right_ankle_target := -right_leg_target * 0.32 - right_knee_target * 0.16
	var left_arm_target := -gait * 0.27 * movement - 0.035
	var right_arm_target := gait * 0.27 * movement + 0.045
	var left_arm_yaw := 0.0
	var right_arm_yaw := 0.0
	var left_arm_roll := -0.055
	var right_arm_roll := 0.055
	var left_elbow_target := 0.14 + maxf(gait, 0.0) * 0.14 * movement
	var right_elbow_target := 0.18 + maxf(-gait, 0.0) * 0.12 * movement
	var rise_target := step_height * 0.026 * movement + idle * 0.006
	var sway_target := weight_shift * 0.028 + idle * 0.004
	var forward_target := 0.0
	var pelvis_rotation := Vector3(0.0, -weight_shift * 0.075, -weight_shift * 0.035)
	var torso_rotation := Vector3(-0.025 * movement + idle * 0.006, weight_shift * 0.105, weight_shift * 0.026)
	var head_rotation := Vector3(-idle * 0.008, -weight_shift * 0.035, -weight_shift * 0.012)
	var left_tail_target := -0.035 + gait * 0.075 * movement
	var right_tail_target := -0.035 - gait * 0.075 * movement
	var action_height := 0.0
	var action_roll := 0.0
	var evade_spin := 0.0
	# Mechanics own each state's duration. These bounded response multipliers only
	# tune how decisively the procedural figure reaches and leaves its target pose.
	var limb_response_scale := 1.0
	var core_response_scale := 1.0
	var cloth_response_scale := 1.0
	var action_response_scale := 1.0
	if anatomical_profile and pose_state == &"grounded":
		# Blend the separate captured walk/run pelvis paths on their shared contact
		# phase. A single source-to-target leg-length ratio replaces the previous
		# unrelated per-axis gains, so lateral transfer and vertical rebound keep
		# their captured relationship. Gameplay translation remains controller-owned.
		var gait_mix := smoothstep(0.06, 0.94, clampf(float(run_amount), 0.0, 1.0))
		var walk_root: Vector3 = R7WalkReference.sample(phase)["root"]
		var run_root: Vector3 = R7RunReference.sample(phase)["root"]
		var mocap_root := walk_root.lerp(run_root, gait_mix) * R7_SOURCE_TO_TARGET_ROOT_SCALE
		rise_target = mocap_root.y * movement + idle * 0.006
		sway_target = mocap_root.x * movement + idle * 0.004
		forward_target = mocap_root.z * movement

	if pose_state == &"grapple":
		var progress := clampf(float(pose_progress), 0.0, 1.0)
		var launch := smoothstep(0.06, 0.30, progress)
		var approach := smoothstep(0.62, 0.88, progress)
		var landing := smoothstep(0.84, 1.0, progress)
		weight_shift = 0.0
		# Coil at launch, extend into an asymmetric overhead reach, then prepare
		# the feet and hips to receive the elevated surface. The final targets match
		# grapple_recover's first compressed frame so landing no longer pops.
		left_leg_target = lerpf(0.20, -0.20, launch)
		right_leg_target = lerpf(-0.12, 0.26, launch)
		left_leg_target = lerpf(left_leg_target, 0.12, approach)
		right_leg_target = lerpf(right_leg_target, -0.08, approach)
		left_leg_target = lerpf(left_leg_target, 0.14, landing)
		right_leg_target = lerpf(right_leg_target, -0.09, landing)
		left_knee_target = lerpf(0.68, 0.18, launch)
		right_knee_target = lerpf(0.56, 0.12, launch)
		left_knee_target = lerpf(left_knee_target, 0.40, approach)
		right_knee_target = lerpf(right_knee_target, 0.50, approach)
		left_knee_target = lerpf(left_knee_target, 0.62, landing)
		right_knee_target = lerpf(right_knee_target, 0.52, landing)
		left_arm_target = lerpf(0.18, -0.96, launch)
		right_arm_target = lerpf(0.26, -1.18, launch)
		left_arm_target = lerpf(left_arm_target, -0.54, approach)
		right_arm_target = lerpf(right_arm_target, -0.66, approach)
		left_arm_target = lerpf(left_arm_target, -0.48, landing)
		right_arm_target = lerpf(right_arm_target, -0.62, landing)
		left_elbow_target = lerpf(0.38, 0.08, launch)
		right_elbow_target = lerpf(0.32, 0.06, launch)
		left_elbow_target = lerpf(left_elbow_target, 0.28, approach)
		right_elbow_target = lerpf(right_elbow_target, 0.34, approach)
		left_elbow_target = lerpf(left_elbow_target, 0.34, landing)
		right_elbow_target = lerpf(right_elbow_target, 0.38, landing)
		left_ankle_target = lerpf(-0.18, 0.03, launch)
		right_ankle_target = lerpf(-0.12, 0.09, launch)
		left_ankle_target = lerpf(left_ankle_target, -0.12, approach)
		right_ankle_target = lerpf(right_ankle_target, -0.15, approach)
		left_ankle_target = lerpf(left_ankle_target, -0.20, landing)
		right_ankle_target = lerpf(right_ankle_target, -0.16, landing)
		rise_target = lerpf(-0.075, 0.055, launch) + sin(progress * PI) * 0.035
		rise_target = lerpf(rise_target, -0.025, approach)
		rise_target = lerpf(rise_target, -0.105, landing)
		sway_target = 0.0
		pelvis_rotation = Vector3(lerpf(0.10, -0.08, launch), lerpf(-0.10, 0.05, launch), lerpf(-0.07, 0.02, launch))
		torso_rotation = Vector3(lerpf(0.14, -0.18, launch), lerpf(0.08, -0.04, approach), lerpf(0.04, -0.025, approach))
		head_rotation = Vector3(lerpf(-0.10, 0.14, launch), -0.03, 0.0)
		left_tail_target = lerpf(-0.02, 0.32, launch)
		right_tail_target = lerpf(-0.04, 0.25, launch)
		pelvis_rotation = pelvis_rotation.lerp(Vector3(0.14, 0.0, -0.04), landing)
		torso_rotation = torso_rotation.lerp(Vector3(0.18, 0.0, 0.05), landing)
		head_rotation = head_rotation.lerp(Vector3(-0.16, 0.0, 0.0), landing)
		left_tail_target = lerpf(left_tail_target, 0.22, landing)
		right_tail_target = lerpf(right_tail_target, 0.18, landing)
		limb_response_scale = 1.18
		core_response_scale = 1.12
		cloth_response_scale = 0.92
	elif pose_state == &"grapple_recover":
		var recovery_progress := clampf(float(pose_progress), 0.0, 1.0)
		var recovery := smoothstep(0.08, 0.92, recovery_progress)
		var recovery_lift := sin(recovery * PI) * 0.018
		weight_shift = 0.0
		left_leg_target = lerpf(0.14, 0.0, recovery)
		right_leg_target = lerpf(-0.09, 0.0, recovery)
		left_knee_target = lerpf(0.62, 0.055, recovery)
		right_knee_target = lerpf(0.52, 0.055, recovery)
		left_ankle_target = lerpf(-0.20, 0.0, recovery)
		right_ankle_target = lerpf(-0.16, 0.0, recovery)
		left_arm_target = lerpf(-0.48, -0.035, recovery)
		right_arm_target = lerpf(-0.62, 0.045, recovery)
		left_elbow_target = lerpf(0.34, 0.14, recovery)
		right_elbow_target = lerpf(0.38, 0.18, recovery)
		rise_target = lerpf(-0.105, idle * 0.006, recovery) + recovery_lift
		sway_target = 0.0
		pelvis_rotation = Vector3(lerpf(0.14, 0.0, recovery), 0.0, lerpf(-0.04, 0.0, recovery))
		torso_rotation = Vector3(lerpf(0.18, idle * 0.006, recovery), 0.0, lerpf(0.05, 0.0, recovery))
		head_rotation = Vector3(lerpf(-0.16, -idle * 0.008, recovery), 0.0, 0.0)
		left_tail_target = lerpf(0.22, -0.035, recovery)
		right_tail_target = lerpf(0.18, -0.035, recovery)
		limb_response_scale = 0.92
		core_response_scale = 0.86
		cloth_response_scale = 0.72
	elif pose_state == &"evade":
		var evade_progress := clampf(float(pose_progress), 0.0, 1.0)
		var tuck_in := smoothstep(0.0, 0.14, evade_progress)
		var untuck := smoothstep(0.62, 0.88, evade_progress)
		var compact := tuck_in * (1.0 - untuck)
		var landing_absorb := smoothstep(0.68, 0.80, evade_progress) * (1.0 - smoothstep(0.88, 1.0, evade_progress))
		var head_clearance := smoothstep(0.21, 0.27, evade_progress) * (1.0 - smoothstep(0.32, 0.39, evade_progress))
		evade_spin = smoothstep(0.06, 0.78, evade_progress)
		weight_shift = 0.0
		left_leg_target = lerpf(0.02, -0.72 if anatomical_profile else -0.66, compact) + 0.10 * landing_absorb
		right_leg_target = lerpf(-0.02, -0.38 if anatomical_profile else -0.50, compact) - 0.07 * landing_absorb
		left_knee_target = lerpf(0.055, 1.30 if anatomical_profile else 1.22, compact) + 0.34 * landing_absorb
		right_knee_target = lerpf(0.055, 0.94 if anatomical_profile else 1.08, compact) + 0.42 * landing_absorb
		left_ankle_target = lerpf(0.0, -0.36, compact) - 0.10 * landing_absorb
		right_ankle_target = lerpf(0.0, -0.30, compact) - 0.13 * landing_absorb
		left_arm_target = lerpf(-0.035, -0.70 if anatomical_profile else -0.92, compact)
		right_arm_target = lerpf(0.045, -1.12 if anatomical_profile else -1.02, compact)
		left_arm_yaw = (-0.42 if anatomical_profile else -0.20) * compact
		right_arm_yaw = (0.16 if anatomical_profile else 0.24) * compact
		left_arm_roll = lerpf(-0.055, -0.52 if anatomical_profile else -0.36, compact)
		right_arm_roll = lerpf(0.055, 0.28 if anatomical_profile else 0.40, compact)
		left_elbow_target = lerpf(0.14, 1.02 if anatomical_profile else 0.82, compact)
		right_elbow_target = lerpf(0.18, 0.66 if anatomical_profile else 0.76, compact)
		rise_target = -0.10 * compact - 0.045 * landing_absorb
		sway_target = 0.0
		forward_target = (0.20 if anatomical_profile else 0.10) * sin(evade_spin * PI) + (0.06 * compact if anatomical_profile else 0.0)
		pelvis_rotation = Vector3(0.18 * compact + 0.08 * landing_absorb, 0.0, -0.06 * compact - 0.04 * landing_absorb)
		torso_rotation = Vector3(0.30 * compact + 0.10 * landing_absorb, 0.0, 0.08 * compact + 0.04 * landing_absorb)
		head_rotation = Vector3(-0.34 * compact - 0.08 * landing_absorb, 0.0, -0.04 * compact)
		left_tail_target = lerpf(-0.035, 0.46, compact)
		right_tail_target = lerpf(-0.035, 0.38, compact)
		# R7 folds around the existing hip-height pivot and stays close to its
		# committed forward path. The former stacked 0.64-unit lift read as an
		# airborne backflip even though controller displacement was forward.
		action_height = sin(evade_spin * PI) * (0.31 if anatomical_profile else 0.38) - compact * (0.03 if anatomical_profile else 0.04)
		if anatomical_profile:
			# The extra mid-roll clearance is deliberately localized after the
			# head-first launch and before landing. It prevents the fitted hair/mask
			# silhouette from grazing the floor without turning the move into an
			# airborne backflip or changing controller-owned travel.
			action_height += 0.18 * head_clearance
		action_roll = sin(evade_spin * PI) * 0.055
		limb_response_scale = 1.35
		core_response_scale = 1.28
		cloth_response_scale = 0.94
		action_response_scale = 1.25
	elif pose_state == &"crouch":
		var crouch_move := smoothstep(0.08, 0.92, clampf(float(pose_progress), 0.0, 1.0))
		var crouch_breath := idle * (1.0 - crouch_move)
		weight_shift = gait * crouch_move * 0.45
		left_leg_target = gait * 0.16 * crouch_move - 0.10
		right_leg_target = -gait * 0.16 * crouch_move + 0.06
		left_knee_target = 0.82 + maxf(-gait, 0.0) * 0.18 * crouch_move
		right_knee_target = 0.70 + maxf(gait, 0.0) * 0.20 * crouch_move
		left_ankle_target = -0.20 - left_leg_target * 0.18
		right_ankle_target = -0.18 - right_leg_target * 0.18
		# The anatomical arms are composed with their size-dependent torso
		# compensation below, so there is only one owner for their targets.
		if not anatomical_profile:
			left_arm_target = -gait * 0.16 * crouch_move - 0.18
			right_arm_target = gait * 0.16 * crouch_move - 0.12
			left_elbow_target = 0.38
			right_elbow_target = 0.42
		rise_target = -0.03 + step_height * 0.010 * crouch_move + crouch_breath * 0.003
		sway_target = weight_shift * 0.018
		forward_target = 0.05
		pelvis_rotation = Vector3(0.14, -weight_shift * 0.05, -weight_shift * 0.025)
		torso_rotation = Vector3(0.24 + crouch_breath * 0.004, weight_shift * 0.07, weight_shift * 0.025)
		head_rotation = Vector3(-0.18 - crouch_breath * 0.006, -weight_shift * 0.025, 0.0)
		left_tail_target = 0.12 + gait * 0.04 * crouch_move
		right_tail_target = 0.10 - gait * 0.04 * crouch_move
		if anatomical_profile:
			# Let the long cape hang behind the lowered hips. Following the torso's
			# forward fold with a positive tail pitch made the large preset's cape tip
			# become the highest point beneath the lintel.
			left_tail_target = -0.20 + gait * 0.025 * crouch_move
			right_tail_target = -0.18 - gait * 0.025 * crouch_move
		action_height = -0.36
		limb_response_scale = 0.94
		core_response_scale = 0.88
		cloth_response_scale = 0.72
		action_response_scale = 0.78
	elif pose_state in [&"jump_prepare", &"jump", &"jump_land"]:
		var jump := PlayerJumpMotion.sample(pose_state, pose_progress, jump_moving, jump_lead)
		left_leg_target = jump.thigh.x
		right_leg_target = jump.thigh.y
		left_knee_target = jump.knee.x
		right_knee_target = jump.knee.y
		left_ankle_target = jump.ankle
		right_ankle_target = jump.ankle
		left_arm_target = jump.arm.x
		right_arm_target = jump.arm.y
		left_arm_yaw = -0.06
		right_arm_yaw = 0.06
		left_arm_roll = -jump.arm_spread
		right_arm_roll = jump.arm_spread
		left_elbow_target = jump.elbow.x
		right_elbow_target = jump.elbow.y
		rise_target = jump.rise
		sway_target = 0.0
		forward_target = 0.0
		pelvis_rotation = Vector3(jump.pelvis, 0.0, 0.0)
		torso_rotation = Vector3(jump.torso, 0.0, 0.0)
		head_rotation = Vector3(jump.head, 0.0, 0.0)
		left_tail_target = jump.tail
		right_tail_target = jump.tail
		limb_response_scale = 1.65
		core_response_scale = 1.7
		cloth_response_scale = 0.90
	elif pose_state == &"vault":
		var air_progress := clampf(float(pose_progress), 0.0, 1.0)
		var takeoff_release := smoothstep(0.06, 0.24, air_progress)
		var flight := smoothstep(0.08, 0.30, air_progress) * (1.0 - smoothstep(0.66, 0.92, air_progress))
		var landing := smoothstep(0.72, 1.0, air_progress)
		var vaulting := 1.0 if pose_state == &"vault" else 0.0
		weight_shift = 0.0
		# A brief loaded takeoff gives way to a held airborne silhouette. Vaulting
		# stays deliberately asymmetric, while a free jump keeps a more balanced arc.
		left_leg_target = lerpf(0.14, -0.34 - vaulting * 0.16, flight)
		right_leg_target = lerpf(-0.08, 0.18 + vaulting * 0.24, flight)
		left_leg_target = lerpf(left_leg_target, 0.08, landing)
		right_leg_target = lerpf(right_leg_target, -0.06, landing)
		left_knee_target = lerpf(0.64, 0.72 + vaulting * 0.22, flight)
		right_knee_target = lerpf(0.56, 0.62 + vaulting * 0.12, flight)
		left_knee_target = lerpf(left_knee_target, 0.66, landing)
		right_knee_target = lerpf(right_knee_target, 0.60, landing)
		left_ankle_target = lerpf(-0.20, -0.10, flight)
		right_ankle_target = lerpf(-0.16, -0.06, flight)
		left_ankle_target = lerpf(left_ankle_target, -0.20, landing)
		right_ankle_target = lerpf(right_ankle_target, -0.16, landing)
		left_arm_target = lerpf(-0.28, -0.82 - vaulting * 0.22, flight)
		right_arm_target = lerpf(-0.22, -0.70 + vaulting * 0.34, flight)
		left_arm_target = lerpf(left_arm_target, -0.18, landing)
		right_arm_target = lerpf(right_arm_target, -0.12, landing)
		left_arm_yaw = -0.20 * vaulting * flight
		right_arm_yaw = 0.34 * vaulting * flight
		left_elbow_target = lerpf(0.36, 0.14, flight)
		right_elbow_target = lerpf(0.40, 0.24 + vaulting * 0.20, flight)
		left_elbow_target = lerpf(left_elbow_target, 0.30, landing)
		right_elbow_target = lerpf(right_elbow_target, 0.34, landing)
		# The measured v4 legs need a shallower visual landing compression:
		# the scaffold's old dip pushed its soles through the final airborne
		# frame. This does not move the actor/collider or change the jump arc.
		var landing_compression := 0.075 if anatomical_profile else 0.105
		rise_target = -0.09 * (1.0 - takeoff_release) - landing_compression * landing
		sway_target = -0.030 * vaulting * flight
		forward_target = 0.09 * flight + 0.035 * landing
		pelvis_rotation = Vector3(lerpf(0.18, -0.10 - vaulting * 0.12, flight), 0.0, -0.055 * vaulting * flight)
		torso_rotation = Vector3(lerpf(0.21, -0.12 - vaulting * 0.18, flight), 0.07 * vaulting * flight, 0.055 * vaulting * flight)
		head_rotation = Vector3(-0.12 * flight, -0.045 * vaulting * flight, 0.0)
		pelvis_rotation = pelvis_rotation.lerp(Vector3(0.16, 0.0, -0.025 * vaulting), landing)
		torso_rotation = torso_rotation.lerp(Vector3(0.22, 0.0, 0.03 * vaulting), landing)
		head_rotation = head_rotation.lerp(Vector3(-0.14, 0.0, 0.0), landing)
		left_tail_target = 0.30 * flight + 0.12 * landing
		right_tail_target = 0.23 * flight + 0.10 * landing
		if anatomical_profile:
			# A complete R7 airborne phrase: compress, open into a contralateral
			# running-leap silhouette, absorb, then return to neutral before the
			# controller releases the state. The previous curve arched the long torso
			# backward and still held a deep knee bend at progress 1, causing both an
			# awkward flight pose and a visible landing pop.
			var compression := 1.0 - smoothstep(0.10, 0.30, air_progress)
			var airborne := smoothstep(0.12, 0.30, air_progress) * (1.0 - smoothstep(0.68, 0.88, air_progress))
			# Finish the visual crouch just before the controller reaches the floor.
			# Leaving it active through 1.0 put the large preset's toe 4 mm below
			# the established floor tolerance on the final 60 Hz airborne frame.
			var absorb := smoothstep(0.70, 0.84, air_progress) * (1.0 - smoothstep(0.90, 0.98, air_progress))
			var vault_reach := vaulting * airborne
			left_leg_target = -0.16 * compression - (0.38 + 0.16 * vaulting) * airborne - 0.18 * absorb
			right_leg_target = -0.12 * compression + (0.42 + 0.14 * vaulting) * airborne - 0.14 * absorb
			left_knee_target = 0.055 + 0.68 * compression + (0.70 + 0.20 * vaulting) * airborne + 0.78 * absorb
			right_knee_target = 0.055 + 0.62 * compression + (0.48 + 0.16 * vaulting) * airborne + 0.72 * absorb
			left_ankle_target = -0.18 * compression - 0.08 * airborne - 0.24 * absorb
			right_ankle_target = -0.16 * compression - 0.04 * airborne - 0.22 * absorb
			left_arm_target = -0.16 * compression + 0.48 * airborne - 0.24 * absorb - 0.85 * vault_reach
			right_arm_target = -0.14 * compression - 0.88 * airborne - 0.22 * absorb - 0.55 * vault_reach
			left_arm_yaw = -0.08 * airborne - 0.12 * vault_reach
			right_arm_yaw = 0.08 * airborne + 0.18 * vault_reach
			left_arm_roll = -0.055 - 0.06 * airborne
			right_arm_roll = 0.055 + 0.06 * airborne
			left_elbow_target = 0.14 + 0.18 * compression + 0.18 * airborne + 0.18 * absorb
			right_elbow_target = 0.18 + 0.18 * compression + 0.34 * airborne + 0.16 * absorb
			# Knee/ankle flex carries most of the landing absorption. Keep the
			# translated pelvis shallow enough that the large boots remain above
			# the shared floor bar during the final smoothed frame.
			rise_target = -0.070 * compression - 0.030 * absorb
			sway_target = -0.028 * vault_reach
			forward_target = 0.055 * airborne + 0.025 * absorb
			pelvis_rotation = Vector3(0.14 * compression + 0.075 * airborne + 0.18 * absorb, 0.0, -0.045 * vault_reach)
			torso_rotation = Vector3(0.18 * compression + 0.10 * airborne + 0.22 * absorb, 0.06 * vault_reach, 0.045 * vault_reach)
			head_rotation = Vector3(-0.10 * compression - 0.045 * airborne - 0.14 * absorb, -0.035 * vault_reach, 0.0)
			left_tail_target = 0.26 * airborne + 0.10 * absorb
			right_tail_target = 0.21 * airborne + 0.08 * absorb
		limb_response_scale = 1.22 + vaulting * 0.06
		core_response_scale = 1.15
		cloth_response_scale = 0.86
	elif pose_state == &"strike":
		var strike_progress := clampf(float(pose_progress), 0.0, 1.0)
		var is_kick := attack_variant == &"left_kick" or attack_variant == &"right_kick"
		var logical_right := attack_variant == &"right_punch" or attack_variant == &"right_kick"
		# R7's source suffixes/drivers are spatially mirrored. Logical right uses
		# the x-negative (left-named) chain so the move's visible side is correct.
		var side := -1.0 if logical_right else 1.0
		var contact_progress := 0.44 if is_kick else (0.389 if logical_right else 0.395)
		var windup := smoothstep(0.0, 0.18, strike_progress)
		var contact := smoothstep(0.18 if not is_kick else 0.27, contact_progress, strike_progress)
		var recover := smoothstep(0.58 if not is_kick else 0.70, 1.0, strike_progress)
		var coil := windup * (1.0 - contact)
		var extend := contact * (1.0 - recover)
		var guard_hand := windup * (1.0 - recover)
		weight_shift = 0.0
		if is_kick:
			var chamber := smoothstep(0.08, 0.27, strike_progress) * (1.0 - smoothstep(contact_progress + 0.06, 0.73, strike_progress))
			var load := smoothstep(0.0, 0.15, strike_progress) * (1.0 - smoothstep(0.24, contact_progress, strike_progress))
			if logical_right:
				left_leg_target = -0.42 * chamber - 0.88 * extend
				left_knee_target = 0.055 + 1.18 * chamber - 1.02 * extend
				left_ankle_target = -0.30 * chamber + 0.14 * extend
				right_leg_target = 0.13 * load - 0.04 * extend
				right_knee_target = 0.055 + 0.38 * load + 0.16 * chamber
				right_ankle_target = -0.17 * load - 0.06 * chamber
			else:
				right_leg_target = -0.42 * chamber - 0.88 * extend
				right_knee_target = 0.055 + 1.18 * chamber - 1.02 * extend
				right_ankle_target = -0.30 * chamber + 0.14 * extend
				left_leg_target = 0.13 * load - 0.04 * extend
				left_knee_target = 0.055 + 0.38 * load + 0.16 * chamber
				left_ankle_target = -0.17 * load - 0.06 * chamber
			left_arm_target = -0.035 - 0.96 * guard_hand
			right_arm_target = 0.045 - 1.02 * guard_hand
			left_arm_yaw = -0.18 * side * guard_hand
			right_arm_yaw = 0.20 * side * guard_hand
			left_elbow_target = 0.14 + 0.92 * guard_hand
			right_elbow_target = 0.18 + 0.94 * guard_hand
			rise_target = -0.045 * load - 0.025 * chamber
			sway_target = side * 0.055 * chamber
			forward_target = 0.11 * extend
			pelvis_rotation = Vector3(0.10 * load + 0.04 * chamber, side * (0.08 * load - 0.13 * extend), side * -0.12 * chamber)
			torso_rotation = Vector3(0.08 * load - 0.15 * extend, side * -0.09 * extend, side * 0.10 * chamber)
			head_rotation = Vector3(0.08 * extend, side * 0.055 * extend, side * -0.05 * chamber)
		else:
			left_leg_target = -0.09 * coil + 0.07 * extend
			right_leg_target = 0.10 * coil - 0.10 * extend
			left_knee_target = 0.055 + 0.13 * guard_hand
			right_knee_target = 0.055 + 0.18 * guard_hand
			left_ankle_target = -left_leg_target - left_knee_target + 0.055
			right_ankle_target = -right_leg_target - right_knee_target + 0.055
			if logical_right:
				left_arm_target = -0.035 + 0.60 * coil - 1.65 * extend
				left_arm_yaw = -0.30 * coil + 0.08 * extend
				left_arm_roll = -0.055 - 0.18 * coil + 0.10 * extend
				left_elbow_target = 0.14 + 0.86 * coil - 0.13 * extend
				right_arm_target = 0.045 - 0.95 * guard_hand
				right_arm_yaw = -0.10 * guard_hand
				right_arm_roll = 0.055 + 0.10 * guard_hand
				right_elbow_target = 0.18 + 0.90 * guard_hand
			else:
				right_arm_target = 0.045 + 0.60 * coil - 1.65 * extend
				right_arm_yaw = 0.30 * coil - 0.08 * extend
				right_arm_roll = 0.055 + 0.18 * coil - 0.10 * extend
				right_elbow_target = 0.18 + 0.86 * coil - 0.13 * extend
				left_arm_target = -0.035 - 0.95 * guard_hand
				left_arm_yaw = 0.10 * guard_hand
				left_arm_roll = -0.055 - 0.10 * guard_hand
				left_elbow_target = 0.14 + 0.90 * guard_hand
			rise_target = -0.025 * guard_hand
			sway_target = side * (-0.025 * coil + 0.025 * extend)
			forward_target = 0.17 * extend
			pelvis_rotation = Vector3(0.0, side * (0.10 * coil - 0.12 * extend), 0.0)
			torso_rotation = Vector3(0.04 * coil + 0.12 * extend, side * (0.32 * coil - 0.26 * extend), 0.0)
			head_rotation = Vector3(-0.06 * extend, side * (-0.12 * coil + 0.15 * extend), 0.0)
		left_tail_target = -0.035 + (0.16 if not logical_right else 0.20) * extend
		right_tail_target = -0.035 + (0.20 if not logical_right else 0.16) * extend
		# These are already eased, time-authored curves. A second low-pass on a
		# .36-second action erases its contact pose, especially on the v1 rig.
		limb_response_scale = 100.0
		core_response_scale = 100.0
		cloth_response_scale = 0.88
	elif pose_state == &"takedown":
		var p := clampf(float(pose_progress), 0.0, 1.0)
		var reach := smoothstep(0.0, 0.26, p)
		var pull := smoothstep(0.31, 0.59, p)
		var release := smoothstep(0.65, 1.0, p)
		var hold := reach * (1.0 - release)
		var draw := pull * (1.0 - release)
		weight_shift = 0.0
		left_leg_target = -0.22 * hold
		right_leg_target = -0.08 * hold
		left_knee_target = 0.055 + 0.46 * hold
		right_knee_target = 0.055 + 0.30 * hold
		left_ankle_target = -left_leg_target - left_knee_target + 0.055
		right_ankle_target = -right_leg_target - right_knee_target + 0.055
		left_arm_target = -0.035 - 1.72 * hold + 0.65 * draw
		right_arm_target = 0.045 - 1.95 * hold + 0.76 * draw
		left_arm_yaw = 0.12 * hold
		right_arm_yaw = -0.14 * hold
		left_arm_roll = -0.055 - 0.08 * hold
		right_arm_roll = 0.055 + 0.10 * hold
		left_elbow_target = 0.14 + 0.08 * hold + 0.75 * draw
		right_elbow_target = 0.18 + 0.10 * hold + 0.90 * draw
		pelvis_rotation = Vector3(0.0, -0.10 * draw, -0.03 * draw)
		torso_rotation = Vector3(0.22 * hold - 0.28 * draw, 0.18 * draw, 0.04 * draw)
		head_rotation = Vector3(-0.12 * hold, -0.10 * draw, 0.0)
		rise_target = -0.075 * hold
		sway_target = -0.045 * draw
		forward_target = 0.26 * hold - 0.18 * draw
		left_tail_target = -0.035 + 0.22 * draw
		right_tail_target = -0.035 + 0.18 * draw
		limb_response_scale = 2.2
		core_response_scale = 2.0
	elif pose_state == &"counter":
		var counter_progress := clampf(float(pose_progress), 0.0, 1.0)
		var brace := smoothstep(0.0, 0.18, counter_progress)
		var redirect := smoothstep(0.18, 0.46, counter_progress)
		var recover := smoothstep(0.56, 0.94, counter_progress)
		weight_shift = 0.0
		left_leg_target = -0.12 * (1.0 - recover)
		right_leg_target = 0.16 * (1.0 - recover)
		left_knee_target = lerpf(0.055, 0.34, brace)
		right_knee_target = lerpf(0.055, 0.40, brace)
		left_knee_target = lerpf(left_knee_target, 0.055, recover)
		right_knee_target = lerpf(right_knee_target, 0.055, recover)
		left_ankle_target = -0.09 * (1.0 - recover)
		right_ankle_target = -0.12 * (1.0 - recover)
		left_arm_target = lerpf(-0.20, -0.82, brace)
		left_arm_target = lerpf(left_arm_target, -0.48, redirect)
		left_arm_target = lerpf(left_arm_target, -0.035, recover)
		right_arm_target = lerpf(-0.12, -0.52, brace)
		right_arm_target = lerpf(right_arm_target, -0.88, redirect)
		right_arm_target = lerpf(right_arm_target, 0.045, recover)
		left_arm_yaw = lerpf(0.22, -0.56, redirect) * (1.0 - recover)
		right_arm_yaw = lerpf(-0.20, 0.52, redirect) * (1.0 - recover)
		left_arm_roll = lerpf(-0.48, -0.24, redirect) * (1.0 - recover) - 0.055 * recover
		right_arm_roll = lerpf(0.46, 0.28, redirect) * (1.0 - recover) + 0.055 * recover
		left_elbow_target = lerpf(0.32, 0.62, brace)
		right_elbow_target = lerpf(0.40, 0.24, redirect)
		left_elbow_target = lerpf(left_elbow_target, 0.14, recover)
		right_elbow_target = lerpf(right_elbow_target, 0.18, recover)
		rise_target = lerpf(0.0, -0.065, brace) * (1.0 - recover)
		sway_target = lerpf(-0.02, 0.055, redirect) * (1.0 - recover)
		forward_target = 0.05 * redirect * (1.0 - recover)
		pelvis_rotation = Vector3(0.10 * brace * (1.0 - recover), -0.16 * (1.0 - recover), -0.08 * (1.0 - recover))
		torso_rotation = Vector3(lerpf(0.14, -0.08, redirect) * (1.0 - recover), lerpf(-0.20, 0.34, redirect) * (1.0 - recover), 0.12 * (1.0 - recover))
		head_rotation = Vector3(-0.08 * (1.0 - recover), -0.18 * (1.0 - recover), -0.04 * (1.0 - recover))
		left_tail_target = lerpf(-0.02, 0.14, redirect) * (1.0 - recover) - 0.035 * recover
		right_tail_target = lerpf(-0.02, 0.20, redirect) * (1.0 - recover) - 0.035 * recover
		limb_response_scale = 1.38
		core_response_scale = 1.30
		cloth_response_scale = 0.84
	elif pose_state == &"fall":
		weight_shift = 0.0
		left_leg_target = 0.16
		right_leg_target = -0.11
		left_knee_target = 0.24
		right_knee_target = 0.34
		left_arm_target = -0.42
		right_arm_target = 0.34
		left_elbow_target = 0.34
		right_elbow_target = 0.24
		left_ankle_target = 0.08
		right_ankle_target = -0.06
		rise_target = 0.0
		sway_target = 0.0
		pelvis_rotation = Vector3(0.08, 0.0, -0.04)
		torso_rotation = Vector3(-0.04, 0.0, 0.05)
		head_rotation = Vector3(-0.10, 0.0, -0.02)
		left_tail_target = 0.24
		right_tail_target = 0.20
	elif pose_state == &"hurt":
		var hurt_progress := clampf(float(pose_progress), 0.0, 1.0)
		var recoil := smoothstep(0.0, 0.18, hurt_progress) * (1.0 - smoothstep(0.54, 1.0, hurt_progress))
		weight_shift = 0.0
		left_leg_target = -0.18 * recoil
		right_leg_target = 0.24 * recoil
		left_knee_target = 0.055 + 0.34 * recoil
		right_knee_target = 0.055 + 0.46 * recoil
		left_ankle_target = -0.08 * recoil
		right_ankle_target = -0.14 * recoil
		left_arm_target = -0.64 * recoil - 0.035 * (1.0 - recoil)
		right_arm_target = -0.36 * recoil + 0.045 * (1.0 - recoil)
		left_arm_yaw = -0.30 * recoil
		right_arm_yaw = 0.42 * recoil
		left_arm_roll = -0.38 * recoil - 0.055 * (1.0 - recoil)
		right_arm_roll = 0.30 * recoil + 0.055 * (1.0 - recoil)
		left_elbow_target = 0.14 + 0.78 * recoil
		right_elbow_target = 0.18 + 0.62 * recoil
		pelvis_rotation = Vector3(-0.14 * recoil, -0.18 * recoil, -0.10 * recoil)
		torso_rotation = Vector3(-0.34 * recoil, 0.32 * recoil, -0.18 * recoil)
		head_rotation = Vector3(0.18 * recoil, -0.24 * recoil, 0.10 * recoil)
		# Preserve the planted gameplay root while keeping the braced boots above
		# the floor through the asymmetric recoil on every body preset.
		rise_target = 0.025 * recoil
		sway_target = -0.10 * recoil
		forward_target = -0.10 * recoil
		left_tail_target = -0.035 + 0.30 * recoil
		right_tail_target = -0.035 + 0.24 * recoil
		limb_response_scale = 1.60
		core_response_scale = 1.50
		cloth_response_scale = 0.86
	elif pose_state == &"downed":
		var down_progress := clampf(float(pose_progress), 0.0, 1.0)
		var collapse := smoothstep(0.0, 0.72, down_progress)
		var settle := smoothstep(0.62, 1.0, down_progress)
		weight_shift = 0.0
		left_leg_target = lerpf(-0.16, 0.46, collapse)
		right_leg_target = lerpf(0.20, -0.52, collapse)
		left_knee_target = lerpf(0.055, 1.02, collapse)
		right_knee_target = lerpf(0.055, 0.74, collapse)
		left_ankle_target = lerpf(0.0, -0.24, collapse)
		right_ankle_target = lerpf(0.0, -0.18, collapse)
		left_arm_target = lerpf(-0.035, -0.82, collapse)
		right_arm_target = lerpf(0.045, 0.54, collapse)
		left_arm_yaw = -0.30 * collapse
		right_arm_yaw = 0.22 * collapse
		left_arm_roll = lerpf(-0.055, -0.58, collapse)
		right_arm_roll = lerpf(0.055, 0.62, collapse)
		left_elbow_target = lerpf(0.14, 0.70, collapse)
		right_elbow_target = lerpf(0.18, 0.52, collapse)
		pelvis_rotation = Vector3(0.22 * collapse, 0.12 * collapse, 0.64 * collapse)
		torso_rotation = Vector3(0.30 * collapse, -0.16 * collapse, 1.12 * collapse)
		head_rotation = Vector3(-0.20 * collapse, 0.12 * collapse, 0.32 * collapse)
		# R7 is a continuous skinned body. Collapse it around the shared action
		# pivot instead of trying to imply a fall by rotating isolated torso bones.
		# This keeps the silhouette connected and brings the torso, not just one
		# extremity, down onto the floor.
		if anatomical_profile:
			action_roll = 1.42 * collapse
			# Rotate around a near-floor side-fall pivot. The previous waist-height
			# pivot left the chest/head visibly hovering even though one toe satisfied
			# the coarse minimum-vertex floor check. A constant local pivot height keeps
			# every body preset proportionally supported after actor scaling.
			action_height = -0.57 * collapse + sin(collapse * PI) * 0.27
			# Keep the arms beside the torso during the whole-body roll. The earlier
			# counterbalancing reach left one hand as the sole floor contact and made
			# the chest appear suspended above it.
			left_arm_target = lerpf(-0.035, -0.28, collapse)
			right_arm_target = lerpf(0.045, 0.22, collapse)
			left_arm_yaw = -0.14 * collapse
			right_arm_yaw = 0.18 * collapse
			left_arm_roll = lerpf(-0.055, 0.28, collapse)
			right_arm_roll = lerpf(0.055, -0.20, collapse)
			left_elbow_target = lerpf(0.14, 0.62, collapse)
			right_elbow_target = lerpf(0.18, 0.48, collapse)
			pelvis_rotation = Vector3(0.16 * collapse, 0.10 * collapse, 0.10 * collapse)
			torso_rotation = Vector3(0.20 * collapse, -0.14 * collapse, 0.16 * collapse)
			head_rotation = Vector3(-0.18 * collapse, 0.10 * collapse, 0.10 * collapse)
			rise_target = -0.025 * settle
			left_tail_target = lerpf(-0.035, -0.18, collapse)
			right_tail_target = lerpf(-0.035, -0.12, collapse)
		else:
			rise_target = -0.30 * collapse - 0.010 * settle + sin(collapse * PI) * 0.15
		sway_target = 0.17 * collapse
		forward_target = -0.05 * collapse
		left_tail_target = lerpf(-0.035, 0.26, collapse)
		right_tail_target = lerpf(-0.035, 0.20, collapse)
		limb_response_scale = 1.34
		core_response_scale = 1.28
		cloth_response_scale = 0.76

	# The skinned figure has continuous hips and anatomical thigh lengths. Fold
	# the hips as well as the knees when lowering it; the older segmented pose
	# lowered nearly straight thighs through the floor at the crouch pivot.
	if parts.has("authored_rig") and pose_state == &"crouch":
		var actor := (parts["visual_root"] as Node3D).get_parent() as Node3D
		var large_build := clampf((actor.scale.y - 1.35) / 0.216, 0.0, 1.0)
		var anatomical_size := clampf((actor.scale.y / 1.35 - 0.88) / 0.28, 0.0, 1.0)
		var crouch_gait := gait * float(pose_progress) * (0.12 if anatomical_profile else 0.08)
		if anatomical_profile:
			# Lower the whole figure and use a believable hip/knee squat instead of
			# folding the knees past 130 degrees and hinging the chest nearly flat.
			# The translated action pivot preserves the same 2.0-unit gameplay
			# clearance without contorting the frozen skinned mesh.
			left_leg_target = lerpf(-0.96, -1.28, anatomical_size) + crouch_gait
			right_leg_target = lerpf(-0.90, -1.22, anatomical_size) - crouch_gait
			left_knee_target = lerpf(1.76, 2.20, anatomical_size) + maxf(-gait, 0.0) * float(pose_progress) * 0.12
			right_knee_target = lerpf(1.68, 2.12, anatomical_size) + maxf(gait, 0.0) * float(pose_progress) * 0.12
			pelvis_rotation.x = lerpf(0.16, 0.19, anatomical_size)
			torso_rotation.x = lerpf(0.74, 1.30, anatomical_size)
			head_rotation.x = lerpf(-0.52, -1.02, anatomical_size)
			# The fitted hair/cape maximum changes owners across the three body
			# presets. A small mid-scale bell correction keeps the medium build under
			# the same 2 m lintel without over-compressing either endpoint preset.
			var medium_clearance := 4.0 * anatomical_size * (1.0 - anatomical_size)
			action_height = lerpf(-0.52, -0.70, anatomical_size) - 0.018 * medium_clearance
			# Foot contact rightfully cancels pure root lowering, so the remaining
			# mid-build clearance comes from a very small additional body fold.
			torso_rotation.x += 0.035 * medium_clearance
			head_rotation.x -= 0.020 * medium_clearance
			# Compensate for the chest fold while keeping the shoulders relaxed.
			# Negative X folds the elbows forward; mirrored yaw carries the hands
			# toward the abdomen, with a small counter-swing during crouch travel.
			left_arm_target = -lerpf(0.68, 1.18, anatomical_size) + gait * float(pose_progress) * 0.10
			right_arm_target = -lerpf(0.62, 1.12, anatomical_size) - gait * float(pose_progress) * 0.10
			left_arm_yaw = 0.50
			right_arm_yaw = -0.50
			left_arm_roll = -0.08
			right_arm_roll = 0.08
			left_elbow_target = -0.82
			right_elbow_target = -0.90
		else:
			# Preserve the accepted v1 authored-player clearance pose exactly.
			left_leg_target = -1.23 - large_build * 0.14 + crouch_gait
			right_leg_target = -1.17 - large_build * 0.14 - crouch_gait
			left_knee_target = 2.15 + large_build * 0.27 + maxf(-gait, 0.0) * float(pose_progress) * 0.10
			right_knee_target = 2.07 + large_build * 0.27 + maxf(gait, 0.0) * float(pose_progress) * 0.10
			pelvis_rotation.x = 0.20
			torso_rotation.x = 0.86 + large_build * 0.22
			head_rotation.x = -0.66 - large_build * 0.16
			if bool(parts["authored_rig"].get("is_v2", false)):
				torso_rotation.x += large_build * 0.035
			action_height = -0.68 - large_build * 0.10
		left_ankle_target = -pelvis_rotation.x - left_leg_target - left_knee_target
		right_ankle_target = -pelvis_rotation.x - right_leg_target - right_knee_target
	elif parts.has("authored_rig") and pose_state == &"grapple":
		var reach_progress := clampf(float(pose_progress), 0.0, 1.0)
		var reach := smoothstep(0.06, 0.30, reach_progress)
		var receive := smoothstep(0.62, 0.90, reach_progress)
		# Anatomical arms need a real shoulder elevation to reach above the head.
		# The old short-limb targets stopped at a chest-height forward gesture.
		left_arm_target = lerpf(lerpf(0.18, -1.90, reach), -0.48, receive)
		right_arm_target = lerpf(lerpf(0.26, -2.45, reach), -0.62, receive)
		left_elbow_target = lerpf(lerpf(0.38, 0.25, reach), 0.34, receive)
		right_elbow_target = lerpf(lerpf(0.32, 0.18, reach), 0.38, receive)
	elif anatomical_profile and pose_state == &"evade":
		# The exact R7 action sampler owns the tuck. Do not add a second aerial
		# lift here: a hip-height pivot plus the compact skeleton clears the floor.
		action_height += 0.0

	_pose_rotation(parts["left_leg"], Vector3(left_leg_target, 0.0, -weight_shift * 0.018), delta, 11.5 * limb_response_scale)
	_pose_rotation(parts["right_leg"], Vector3(right_leg_target, 0.0, -weight_shift * 0.018), delta, 11.5 * limb_response_scale)
	_pose_rotation(parts["left_knee"], Vector3(left_knee_target, 0.0, 0.0), delta, 13.0 * limb_response_scale)
	_pose_rotation(parts["right_knee"], Vector3(right_knee_target, 0.0, 0.0), delta, 13.0 * limb_response_scale)
	_pose_rotation(parts["left_ankle"], Vector3(left_ankle_target, 0.0, 0.0), delta, 14.0 * limb_response_scale)
	_pose_rotation(parts["right_ankle"], Vector3(right_ankle_target, 0.0, 0.0), delta, 14.0 * limb_response_scale)
	_pose_rotation(parts["left_arm"], Vector3(left_arm_target, left_arm_yaw, left_arm_roll), delta, 11.0 * limb_response_scale)
	_pose_rotation(parts["right_arm"], Vector3(right_arm_target, right_arm_yaw, right_arm_roll), delta, 11.0 * limb_response_scale)
	_pose_rotation(parts["left_elbow"], Vector3(left_elbow_target, 0.0, 0.0), delta, 13.0 * limb_response_scale)
	_pose_rotation(parts["right_elbow"], Vector3(right_elbow_target, 0.0, 0.0), delta, 13.0 * limb_response_scale)
	_pose_rotation(parts["pelvis_root"], pelvis_rotation, delta, 9.5 * core_response_scale)
	_pose_rotation(parts["torso_root"], torso_rotation, delta, 9.0 * core_response_scale)
	_pose_rotation(parts["head_root"], head_rotation, delta, 8.5 * core_response_scale)
	_pose_rotation(parts["left_tail"], Vector3(left_tail_target, 0.0, -0.045), delta, 7.5 * cloth_response_scale)
	_pose_rotation(parts["right_tail"], Vector3(right_tail_target, 0.0, 0.045), delta, 7.5 * cloth_response_scale)
	_pose_position(parts["visual_root"], Vector3(sway_target, rise_target, forward_target), delta, 11.0 * core_response_scale)
	_pose_position(parts["action_root"], Vector3(0.0, 0.95 + action_height, 0.0), delta, 15.0 * action_response_scale)
	var action_root := parts["action_root"] as Node3D
	if pose_state == &"evade":
		# +X carries the +Z-facing head forward first. The root itself owns the
		# unchanged 1.96-unit committed travel; this pivot only authors the roll.
		action_root.rotation = Vector3(TAU * evade_spin, 0.0, action_roll)
	elif anatomical_profile and pose_state == &"downed":
		_pose_rotation(action_root, Vector3(0.0, 0.0, action_roll), delta, 11.0 * action_response_scale)
	else:
		action_root.rotation.x = wrapf(action_root.rotation.x, -PI, PI)
		_pose_rotation(action_root, Vector3.ZERO, delta, 15.0 * action_response_scale)

	if parts.has("authored_rig"):
		GloamVigilRigAdapter.sync_pose(parts["authored_rig"], parts, pose_state, delta, phase, movement, float(pose_progress), attack_variant, float(run_amount))


static func pose_guard(parts: Dictionary, phase: float, movement_amount: float, delta: float, pose_state: StringName = &"grounded", pose_progress := 0.0, reaction_side := 1.0) -> void:
	if parts.has("authored_rig"):
		var authored_pose := &"grounded"
		var authored_progress := float(pose_progress)
		match pose_state:
			&"attack":
				authored_pose = &"strike"
			&"stagger", &"restrained":
				authored_pose = &"hurt"
			&"takedown_victim", &"defeated":
				authored_pose = &"downed"
		pose_player(
			parts,
			phase,
			movement_amount,
			delta,
			authored_pose,
			authored_progress,
			&"right_punch",
			0.0
		)
		return

	var movement := smoothstep(0.0, 1.0, clampf(movement_amount, 0.0, 1.0))
	var gait := sin(phase)
	var weight_shift := gait * movement
	var idle := sin(phase * 0.62 + 0.7) * (1.0 - movement)
	var stride := gait * 0.27 * movement
	var side := 1.0 if reaction_side >= 0.0 else -1.0
	var left_leg_target := stride
	var right_leg_target := -stride
	var left_knee_target := 0.065 + maxf(-gait, 0.0) * 0.34 * movement
	var right_knee_target := 0.065 + maxf(gait, 0.0) * 0.34 * movement
	var left_ankle_target := -stride * 0.24
	var right_ankle_target := stride * 0.24
	var left_arm_target := -stride * 0.62 - 0.03
	var right_arm_target := stride * 0.47 + 0.02
	var left_arm_yaw := 0.0
	var right_arm_yaw := 0.0
	var left_arm_roll := -0.045
	var right_arm_roll := 0.035
	var left_elbow_target := 0.16 + maxf(gait, 0.0) * 0.10 * movement
	var right_elbow_target := 0.24 + maxf(-gait, 0.0) * 0.07 * movement
	var pelvis_rotation := Vector3(0.0, -weight_shift * 0.050, -weight_shift * 0.026)
	var torso_rotation := Vector3(-0.018 * movement + idle * 0.004, weight_shift * 0.065, weight_shift * 0.020)
	var head_rotation := Vector3(-idle * 0.006, -weight_shift * 0.022, 0.0)
	var rise_target := (1.0 - cos(phase * 2.0)) * 0.009 * movement + idle * 0.004
	var sway_target := weight_shift * 0.020 + idle * 0.003
	var forward_target := 0.0
	var body_rotation := Vector3.ZERO
	var body_position := Vector3.ZERO
	var limb_response_scale := 1.0
	var core_response_scale := 1.0

	if pose_state == &"attack":
		var attack_progress := clampf(float(pose_progress), 0.0, 1.0)
		var windup := smoothstep(0.0, 0.32, attack_progress)
		var cut := smoothstep(0.48, 0.68, attack_progress)
		var attack_recover := smoothstep(0.74, 1.0, attack_progress)
		weight_shift = 0.0
		left_leg_target = -0.12 * windup + 0.20 * cut
		right_leg_target = 0.18 * windup - 0.14 * cut
		left_leg_target = lerpf(left_leg_target, 0.0, attack_recover)
		right_leg_target = lerpf(right_leg_target, 0.0, attack_recover)
		left_knee_target = lerpf(0.065, 0.28, windup)
		right_knee_target = lerpf(0.065, 0.36, windup)
		left_knee_target = lerpf(left_knee_target, 0.065, attack_recover)
		right_knee_target = lerpf(right_knee_target, 0.065, attack_recover)
		left_ankle_target = -0.08 * windup * (1.0 - attack_recover)
		right_ankle_target = -0.12 * windup * (1.0 - attack_recover)
		right_arm_target = lerpf(-0.10, -1.02, windup)
		right_arm_target = lerpf(right_arm_target, 0.72, cut)
		right_arm_target = lerpf(right_arm_target, 0.02, attack_recover)
		right_arm_yaw = lerpf(0.58, -0.46, cut) * (1.0 - attack_recover)
		right_arm_roll = lerpf(0.54, -0.34, cut) * (1.0 - attack_recover) + 0.035 * attack_recover
		right_elbow_target = lerpf(0.66, 0.10, cut)
		right_elbow_target = lerpf(right_elbow_target, 0.24, attack_recover)
		left_arm_target = lerpf(-0.16, -0.48, windup)
		left_arm_target = lerpf(left_arm_target, -0.03, attack_recover)
		left_arm_yaw = 0.18 * windup * (1.0 - attack_recover)
		left_arm_roll = -0.22 * windup * (1.0 - attack_recover) - 0.045 * attack_recover
		left_elbow_target = lerpf(0.28, 0.44, windup)
		left_elbow_target = lerpf(left_elbow_target, 0.16, attack_recover)
		pelvis_rotation = Vector3(-0.04 * windup, lerpf(-0.20, 0.22, cut) * (1.0 - attack_recover), -0.06 * (1.0 - attack_recover))
		torso_rotation = Vector3(lerpf(0.16, -0.26, cut) * (1.0 - attack_recover), lerpf(-0.32, 0.44, cut) * (1.0 - attack_recover), lerpf(-0.10, 0.13, cut) * (1.0 - attack_recover))
		head_rotation = Vector3(-0.06 * (1.0 - attack_recover), -0.18 * (1.0 - attack_recover), 0.03 * (1.0 - attack_recover))
		rise_target = -0.045 * windup * (1.0 - attack_recover)
		sway_target = lerpf(-0.03, 0.07, cut) * (1.0 - attack_recover)
		forward_target = 0.12 * cut * (1.0 - attack_recover)
		limb_response_scale = 1.28
		core_response_scale = 1.20
	elif pose_state == &"stagger":
		var stagger_progress := clampf(float(pose_progress), 0.0, 1.0)
		# Hold the impact shape for a beat before yielding into the existing timed
		# recovery, so a strike and a perfect counter do not read as soft sways.
		var recoil := 1.0 - smoothstep(0.14, 1.0, stagger_progress)
		weight_shift = 0.0
		left_leg_target = -0.18 * recoil
		right_leg_target = 0.24 * recoil
		left_knee_target = 0.065 + 0.30 * recoil
		right_knee_target = 0.065 + 0.40 * recoil
		left_ankle_target = -0.10 * recoil
		right_ankle_target = -0.15 * recoil
		left_arm_target = -0.36 * recoil - 0.03 * (1.0 - recoil)
		right_arm_target = 0.64 * recoil + 0.02 * (1.0 - recoil)
		left_arm_yaw = -side * 0.28 * recoil
		right_arm_yaw = side * 0.22 * recoil
		left_arm_roll = -0.045 - side * 0.24 * recoil
		right_arm_roll = 0.035 + side * 0.28 * recoil
		left_elbow_target = 0.16 + 0.34 * recoil
		right_elbow_target = 0.24 + 0.18 * recoil
		pelvis_rotation = Vector3(-0.12 * recoil, side * 0.18 * recoil, side * 0.12 * recoil)
		torso_rotation = Vector3(-0.34 * recoil, side * 0.34 * recoil, side * 0.18 * recoil)
		head_rotation = Vector3(0.16 * recoil, -side * 0.18 * recoil, -side * 0.12 * recoil)
		rise_target = -0.035 * recoil
		sway_target = side * 0.085 * recoil
		forward_target = -0.08 * recoil
		limb_response_scale = 1.42 if stagger_progress < 0.24 else 1.08
		core_response_scale = 1.36 if stagger_progress < 0.24 else 1.02
	elif pose_state == &"takedown_victim":
		var takedown_progress := clampf(float(pose_progress), 0.0, 1.0)
		var caught := smoothstep(0.04, 0.30, takedown_progress)
		# The victim may brace early, but does not begin the fall before the
		# gameplay-owned 0.34 s contact (0.309 normalized).
		var collapse := smoothstep(0.31, 0.88, takedown_progress)
		var settle := smoothstep(0.76, 1.0, takedown_progress)
		weight_shift = 0.0
		left_leg_target = lerpf(-0.08 * caught, 0.30, collapse)
		right_leg_target = lerpf(0.05 * caught, -0.38, collapse)
		left_knee_target = lerpf(0.065 + 0.22 * caught, 0.78, collapse)
		right_knee_target = lerpf(0.065 + 0.16 * caught, 0.62, collapse)
		left_ankle_target = lerpf(-0.04 * caught, -0.22, collapse)
		right_ankle_target = lerpf(-0.06 * caught, -0.16, collapse)
		left_arm_target = lerpf(-0.03, -0.68, caught)
		right_arm_target = lerpf(0.02, -0.54, caught)
		left_arm_target = lerpf(left_arm_target, -0.72, collapse)
		right_arm_target = lerpf(right_arm_target, 0.48, collapse)
		left_arm_yaw = lerpf(-0.18 * caught, -side * 0.26, collapse)
		right_arm_yaw = lerpf(0.16 * caught, side * 0.24, collapse)
		left_arm_roll = lerpf(-0.045 - 0.20 * caught, -side * 0.46, collapse)
		right_arm_roll = lerpf(0.035 + 0.18 * caught, side * 0.54, collapse)
		left_elbow_target = lerpf(0.16 + 0.74 * caught, 0.58, collapse)
		right_elbow_target = lerpf(0.24 + 0.58 * caught, 0.44, collapse)
		pelvis_rotation = Vector3(lerpf(0.0, 0.18, collapse), side * 0.12 * collapse, side * 0.10 * collapse)
		torso_rotation = Vector3(lerpf(-0.16 * caught, 0.24, collapse), lerpf(0.10 * caught, -side * 0.10, collapse), side * 0.16 * collapse)
		head_rotation = Vector3(lerpf(0.08 * caught, -0.18, collapse), lerpf(-0.14 * caught, side * 0.10, collapse), side * 0.10 * collapse)
		body_rotation.z = side * 1.46 * collapse
		body_position = Vector3(side * 0.08 * collapse, 0.28 * collapse + sin(collapse * PI) * 0.10, 0.0)
		rise_target = -0.04 * caught * (1.0 - collapse) - 0.01 * settle
		sway_target = side * 0.18 * collapse
		forward_target = -0.06 * caught * (1.0 - collapse)
		limb_response_scale = 2.0
		core_response_scale = 1.85
	elif pose_state == &"restrained":
		var caught := smoothstep(0.25, 1.0, clampf(float(pose_progress), 0.0, 1.0))
		weight_shift = 0.0
		left_leg_target = -0.08 * caught
		right_leg_target = 0.05 * caught
		left_knee_target = 0.065 + 0.22 * caught
		right_knee_target = 0.065 + 0.16 * caught
		left_arm_target = -0.03 - 0.65 * caught
		right_arm_target = 0.02 - 0.48 * caught
		left_elbow_target = 0.16 + 0.70 * caught
		right_elbow_target = 0.24 + 0.52 * caught
		torso_rotation = Vector3(-0.16 * caught, 0.10 * caught, 0.0)
		head_rotation = Vector3(0.08 * caught, -0.14 * caught, 0.0)
		rise_target = -0.04 * caught
		forward_target = -0.06 * caught
		limb_response_scale = 1.8
		core_response_scale = 1.6
	elif pose_state == &"defeated":
		var defeat_progress := clampf(float(pose_progress), 0.0, 1.0)
		var collapse := smoothstep(0.0, 0.56, defeat_progress)
		var settle := smoothstep(0.42, 1.0, defeat_progress)
		weight_shift = 0.0
		left_leg_target = lerpf(-0.14, 0.30, collapse)
		right_leg_target = lerpf(0.18, -0.38, collapse)
		left_knee_target = lerpf(0.065, 0.78, collapse)
		right_knee_target = lerpf(0.065, 0.62, collapse)
		left_ankle_target = lerpf(0.0, -0.22, collapse)
		right_ankle_target = lerpf(0.0, -0.16, collapse)
		left_arm_target = lerpf(-0.03, -0.72, collapse)
		right_arm_target = lerpf(0.02, 0.48, collapse)
		left_arm_yaw = -side * 0.26 * collapse
		right_arm_yaw = side * 0.24 * collapse
		left_arm_roll = lerpf(-0.045, -side * 0.46, collapse)
		right_arm_roll = lerpf(0.035, side * 0.54, collapse)
		left_elbow_target = lerpf(0.16, 0.58, collapse)
		right_elbow_target = lerpf(0.24, 0.44, collapse)
		pelvis_rotation = Vector3(0.18 * collapse, side * 0.12 * collapse, side * 0.10 * collapse)
		torso_rotation = Vector3(0.24 * collapse, -side * 0.10 * collapse, side * 0.16 * collapse)
		head_rotation = Vector3(-0.18 * collapse, side * 0.10 * collapse, side * 0.10 * collapse)
		body_rotation.z = side * 1.46 * collapse
		body_position = Vector3(side * 0.08 * collapse, 0.28 * collapse + sin(collapse * PI) * 0.10, 0.0)
		rise_target = -0.01 * settle
		sway_target = side * lerpf(0.0, 0.18, collapse)

	_pose_rotation(parts["left_leg"], Vector3(left_leg_target, 0.0, -weight_shift * 0.015), delta, 10.5 * limb_response_scale)
	_pose_rotation(parts["right_leg"], Vector3(right_leg_target, 0.0, -weight_shift * 0.015), delta, 10.5 * limb_response_scale)
	_pose_rotation(parts["left_knee"], Vector3(left_knee_target, 0.0, 0.0), delta, 11.5 * limb_response_scale)
	_pose_rotation(parts["right_knee"], Vector3(right_knee_target, 0.0, 0.0), delta, 11.5 * limb_response_scale)
	_pose_rotation(parts["left_ankle"], Vector3(left_ankle_target, 0.0, 0.0), delta, 12.0 * limb_response_scale)
	_pose_rotation(parts["right_ankle"], Vector3(right_ankle_target, 0.0, 0.0), delta, 12.0 * limb_response_scale)
	_pose_rotation(parts["left_arm"], Vector3(left_arm_target, left_arm_yaw, left_arm_roll), delta, 11.5 * limb_response_scale)
	_pose_rotation(parts["right_arm"], Vector3(right_arm_target, right_arm_yaw, right_arm_roll), delta, 11.5 * limb_response_scale)
	_pose_rotation(parts["left_elbow"], Vector3(left_elbow_target, 0.0, 0.0), delta, 12.5 * limb_response_scale)
	_pose_rotation(parts["right_elbow"], Vector3(right_elbow_target, 0.0, 0.0), delta, 12.5 * limb_response_scale)
	_pose_rotation(parts["pelvis_root"], pelvis_rotation, delta, 10.0 * core_response_scale)
	_pose_rotation(parts["torso_root"], torso_rotation, delta, 10.5 * core_response_scale)
	_pose_rotation(parts["head_root"], head_rotation, delta, 10.0 * core_response_scale)
	_pose_rotation(parts["body_root"], body_rotation, delta, 12.0 * core_response_scale)
	_pose_position(parts["body_root"], body_position, delta, 12.0 * core_response_scale)
	_pose_position(parts["visual_root"], Vector3(sway_target, rise_target, forward_target), delta, 10.5 * core_response_scale)


static func _pose_rotation(node: Node3D, target: Vector3, delta: float, response: float) -> void:
	var blend := minf(delta * response, 1.0)
	node.rotation.x = lerp_angle(node.rotation.x, target.x, blend)
	node.rotation.y = lerp_angle(node.rotation.y, target.y, blend)
	node.rotation.z = lerp_angle(node.rotation.z, target.z, blend)


static func _pose_position(node: Node3D, target: Vector3, delta: float, response: float) -> void:
	node.position = node.position.lerp(target, minf(delta * response, 1.0))


static func _material(color: Color, roughness: float, metallic := 0.0, emission := Color.TRANSPARENT) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission.a > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 1.1
	return material


static func _node(parent: Node3D, node_name: String, position: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	node.position = position
	parent.add_child(node)
	return node


static func _cylinder(parent: Node3D, position: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	return _mesh(parent, position, mesh, material)


static func _tapered(parent: Node3D, position: Vector3, top_radius: float, bottom_radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 20
	return _mesh(parent, position, mesh, material)


static func _sphere(parent: Node3D, position: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	return _mesh(parent, position, mesh, material)


static func _capsule(parent: Node3D, position: Vector3, radius: float, height: float, material: Material, rotation: Vector3) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh.rings = 8
	var instance := _mesh(parent, position, mesh, material)
	instance.rotation = rotation
	return instance


static func _tapered_limb(parent: Node3D, start: Vector3, finish: Vector3, start_radius: float, finish_radius: float, material: Material, depth_scale: float) -> MeshInstance3D:
	var direction := finish - start
	var mesh := CylinderMesh.new()
	mesh.top_radius = finish_radius
	mesh.bottom_radius = start_radius
	mesh.height = direction.length()
	mesh.radial_segments = 20
	var instance := _mesh(parent, start.lerp(finish, 0.5), mesh, material)
	instance.quaternion = Quaternion(Vector3.UP, direction.normalized())
	instance.scale.z = depth_scale
	return instance


static func _mesh(parent: Node3D, position: Vector3, mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)
	return instance
