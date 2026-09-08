extends SceneTree

## External, read-only performance benchmark for the active Gloam courtyard.
##
## This does not alter the project or claim that fixture copies are enemy AI.
## It measures two cases in one normal-renderer process:
##   1. ACTUAL_COURTYARD: the real main_3d.tscn with its player and guard.
##   2. STRESS_9_PLAYER_RIGS: the same scene plus eight visual-only player rigs.
##
## Original one-repetition baseline invocation (preserved; never add --headless
## or --write-movie):
## godot --path /Users/markabraham/dev/batman \
##   --rendering-method gl_compatibility --resolution 1920x1080 \
##   --disable-vsync --script /Users/markabraham/dev/batman/work/character-quality-benchmark/benchmark.gd \
##   -- --benchmark-label=current-v1
##
## Character-art acceptance runs must select both sides explicitly and retain
## the exact long/repeated protocol:
##   -- --benchmark-label=art-final-v1 --model=v1 --measured-seconds=10 --repetitions=3
##   -- --benchmark-label=art-final-v4 --model=v4 --measured-seconds=10 --repetitions=3

const CharacterVisualBuilder = preload("res://actors/character_visual_builder.gd")

const TARGET_RENDER_SIZE := Vector2i(1920, 1080)
const V1_ASSET_PATH := "res://actors/gloam_vigil/gloam_vigil_player.glb"
const V2_ASSET_PATH := "res://actors/gloam_vigil/v2/gloam_vigil_player_v2.glb"
const V4_ASSET_PATH := "res://actors/gloam_vigil/v4/gloam_vigil_player_v4.glb"
const FIXED_SIM_DELTA := 1.0 / 60.0
const WARMUP_SECONDS := 3.0
const WARMUP_MIN_FRAMES := 120
const SAMPLE_FRAMES := 600
const EXTRA_STRESS_RIGS := 8

const CASE_COURTYARD := "ACTUAL_COURTYARD"
const CASE_STRESS := "STRESS_9_PLAYER_RIGS"

var game: Node3D
var fixtures: Array[Dictionary] = []
var case_name := CASE_COURTYARD
var benchmark_label := "unlabelled"
var model_selection := "default"
var minimum_measured_seconds := 0.0
var repetitions := 1
var repetition_index := 0
var phase := "settle"
var settle_frames := 0
var warmup_frames := 0
var warmup_started_usec := 0
var simulation_frame := 0
var last_frame_usec := 0
var sample_started_usec := 0
var samples: Dictionary = {}
var combined_samples: Dictionary = {}
var viewport_rid: RID
var gpu_timer_positive_samples := 0
var selected_asset_path := "project default"
var selected_asset_sha256 := "not recorded for project default"
var selected_runtime_scene_path := "project default"
var selected_rig_is_v2: Variant = null
var retired_visual_materials: Array[Material] = []


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--benchmark-label="):
			benchmark_label = argument.trim_prefix("--benchmark-label=")
		elif argument.begins_with("--model="):
			model_selection = argument.trim_prefix("--model=")
		elif argument.begins_with("--measured-seconds="):
			minimum_measured_seconds = maxf(float(argument.trim_prefix("--measured-seconds=")), 0.0)
		elif argument.begins_with("--repetitions="):
			repetitions = maxi(int(argument.trim_prefix("--repetitions=")), 1)
	call_deferred("_start")


func _start() -> void:
	Engine.max_fps = 0
	Engine.time_scale = 1.0
	OS.low_processor_usage_mode = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# macOS reports window sizes in logical points while the compatibility
	# renderer allocates a HiDPI drawable. Lock the root render viewport itself
	# to 1920x1080 so --resolution cannot silently benchmark a larger buffer.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = TARGET_RENDER_SIZE
	DisplayServer.window_set_size(TARGET_RENDER_SIZE)
	root.size = TARGET_RENDER_SIZE

	game = load("res://main_3d.tscn").instantiate()
	root.add_child(game)
	# Drive the real scene exactly once per rendered frame with a deterministic
	# simulation delta. Wall-clock render frame time is measured separately.
	game.set_process(false)
	game.set_physics_process(false)
	if not _install_explicit_scene_player_if_requested():
		quit(2)
		return
	game.reset_game()

	viewport_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	_reset_samples()
	_reset_combined_samples()
	print("GLOAM_PERF_START label=", benchmark_label, " model=", model_selection, " repetitions=", repetitions, " measured_seconds_min=", minimum_measured_seconds)


func _process(_delta: float) -> bool:
	if game == null:
		return false

	var now_usec := Time.get_ticks_usec()
	_drive_deterministic_scene()

	if phase == "settle":
		settle_frames += 1
		if settle_frames >= 30:
			if not _verify_runtime_configuration():
				quit(2)
				return true
			_start_warmup(now_usec)
		return false

	if phase == "warmup":
		warmup_frames += 1
		var warmup_seconds := float(now_usec - warmup_started_usec) / 1000000.0
		if warmup_frames >= WARMUP_MIN_FRAMES and warmup_seconds >= WARMUP_SECONDS:
			phase = "sample"
			last_frame_usec = now_usec
			sample_started_usec = now_usec
			print("GLOAM_PERF_WARM label=", benchmark_label, " model=", model_selection, " case=", case_name, " repetition=", repetition_index + 1, "/", repetitions, " frames=", warmup_frames, " seconds=", snappedf(warmup_seconds, 0.001))
		return false

	if phase == "sample":
		if last_frame_usec > 0:
			_record_sample(now_usec)
		last_frame_usec = now_usec
		var measured_seconds := float(now_usec - sample_started_usec) / 1000000.0
		if samples["frame_ms"].size() >= SAMPLE_FRAMES and measured_seconds >= minimum_measured_seconds:
			_report_case()
			if repetition_index + 1 < repetitions:
				repetition_index += 1
				_restart_current_case()
			elif case_name == CASE_COURTYARD:
				_report_case_aggregate()
				_begin_stress_case()
			else:
				_report_case_aggregate()
				print("GLOAM_PERF_BENCHMARK_OK label=", benchmark_label, " model=", model_selection, " cases=2 repetitions=", repetitions, " minimum_samples_per_repetition=", SAMPLE_FRAMES, " measured_seconds_min_per_repetition=", minimum_measured_seconds)
				quit(0)
				return true
	return false


func _drive_deterministic_scene() -> void:
	# This is real courtyard movement and guard logic, but not native-input proof.
	# Oscillation keeps the player gait active without input-device variance.
	game.held_keys.clear()
	if (simulation_frame / 90) % 2 == 0:
		game.held_keys[KEY_D] = true
	else:
		game.held_keys[KEY_A] = true
	game._process(FIXED_SIM_DELTA)

	for index in fixtures.size():
		var fixture: Dictionary = fixtures[index]
		var local_frame := simulation_frame + index * 19
		var action_index := (local_frame / 90) % 8
		var progress := float(local_frame % 90) / 89.0
		var pose: StringName = [
			&"grounded", &"crouch", &"jump", &"vault",
			&"evade", &"grapple", &"strike", &"counter",
		][action_index]
		var movement := 1.0 if pose == &"grounded" or pose == &"crouch" else 0.35
		CharacterVisualBuilder.pose_player(
			fixture["parts"],
			float(simulation_frame) * 0.12 + index * 0.7,
			movement,
			FIXED_SIM_DELTA,
			pose,
			progress
		)
	simulation_frame += 1


func _install_explicit_scene_player_if_requested() -> bool:
	if model_selection == "default":
		return true
	if model_selection not in ["v1", "v2", "v4"]:
		push_error("GLOAM_PERF_CONFIG_FAIL --model must be default, v1, v2, or v4")
		return false
	if not _builder_supports_explicit_model_selection():
		push_error("GLOAM_PERF_CONFIG_FAIL character builder does not expose the arguments required by the selected model")
		return false
	selected_asset_path = _selected_asset_path()
	if not ResourceLoader.exists(selected_asset_path):
		push_error("GLOAM_PERF_CONFIG_FAIL selected asset is not imported: " + selected_asset_path)
		return false
	_retire_existing_scene_player()
	var parts := _build_selected_player(game.player_root, game.outfit_colors[game.outfit_index])
	if parts.is_empty():
		return false
	var authored_rig: Dictionary = parts.get("authored_rig", {})
	selected_rig_is_v2 = authored_rig.get("is_v2", null)
	var expected_expanded_rig := model_selection in ["v2", "v4"]
	if selected_rig_is_v2 == null or bool(selected_rig_is_v2) != expected_expanded_rig:
		push_error("GLOAM_PERF_CONFIG_FAIL explicit model selection did not produce the requested rig")
		return false
	var imported_root := authored_rig.get("imported_root") as Node
	selected_runtime_scene_path = imported_root.scene_file_path if imported_root != null else ""
	if selected_runtime_scene_path != selected_asset_path:
		push_error("GLOAM_PERF_CONFIG_FAIL runtime scene path does not match explicit asset: %s != %s" % [selected_runtime_scene_path, selected_asset_path])
		return false
	selected_asset_sha256 = FileAccess.get_sha256(selected_asset_path)
	if selected_asset_sha256.is_empty():
		push_error("GLOAM_PERF_CONFIG_FAIL could not fingerprint selected asset " + selected_asset_path)
		return false
	game.player_visual_parts = parts
	game.player_accent_material = parts["accent_material"]
	return true


func _retire_existing_scene_player() -> void:
	var old_parts: Dictionary = game.player_visual_parts
	var old_rig: Dictionary = old_parts.get("authored_rig", {})
	for mesh_value in old_rig.get("mesh_instances", []):
		if not mesh_value is MeshInstance3D:
			continue
		var mesh_instance := mesh_value as MeshInstance3D
		if mesh_instance.material_override != null:
			retired_visual_materials.append(mesh_instance.material_override)
		mesh_instance.material_override = null
		if mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var override := mesh_instance.get_surface_override_material(surface_index)
			if override != null:
				retired_visual_materials.append(override)
			mesh_instance.set_surface_override_material(surface_index, null)
	var old_visual := old_parts.get("visual_root") as Node3D
	if old_visual != null:
		# Defer destruction out of the current renderer update. Retained material
		# references remain alive for the benchmark lifetime so the compatibility
		# backend never observes a freed/null override during teardown.
		old_visual.queue_free()
	print("GLOAM_PERF_RETIRED_DEFAULT_PLAYER retained_materials=", retired_visual_materials.size(), " deferred_free=", old_visual != null)


func _builder_supports_explicit_model_selection() -> bool:
	var builder_script: Script = CharacterVisualBuilder
	for method: Dictionary in builder_script.get_script_method_list():
		if method.get("name", "") == "build_player":
			var minimum_arguments := 4 if model_selection == "v4" else 3
			return (method.get("args", []) as Array).size() >= minimum_arguments
	return false


func _build_selected_player(parent: Node3D, accent: Color) -> Dictionary:
	if model_selection == "default":
		return CharacterVisualBuilder.build_player(parent, accent)
	var use_expanded_rig := model_selection in ["v2", "v4"]
	var builder_callable := Callable(CharacterVisualBuilder, "build_player")
	var arguments: Array = [parent, accent, use_expanded_rig]
	if model_selection == "v4":
		arguments.append(V4_ASSET_PATH)
	var result: Variant = builder_callable.callv(arguments)
	if not result is Dictionary:
		push_error("GLOAM_PERF_CONFIG_FAIL explicit build_player call did not return a Dictionary")
		return {}
	return result as Dictionary


func _selected_asset_path() -> String:
	match model_selection:
		"v1":
			return V1_ASSET_PATH
		"v2":
			return V2_ASSET_PATH
		"v4":
			return V4_ASSET_PATH
	return ""


func _verify_runtime_configuration() -> bool:
	var renderer_method := RenderingServer.get_current_rendering_method()
	var renderer_driver := RenderingServer.get_current_rendering_driver_name()
	var display_driver := DisplayServer.get_name()
	var window_size := DisplayServer.window_get_size()
	var root_size := root.size
	var visible_size := Vector2i(root.get_visible_rect().size)
	var texture_size := Vector2i(root.get_texture().get_size())
	var content_scale_size := root.content_scale_size
	var vsync_mode := DisplayServer.window_get_vsync_mode()

	var config := {
		"label": benchmark_label,
		"model_selection": model_selection,
		"selected_rig_is_v2": selected_rig_is_v2,
		"selected_asset_path": selected_asset_path,
		"selected_runtime_scene_path": selected_runtime_scene_path,
		"selected_asset_sha256": selected_asset_sha256,
		"renderer_method": renderer_method,
		"renderer_driver": renderer_driver,
		"display_driver": display_driver,
		"window_size": [window_size.x, window_size.y],
		"root_viewport_size": [root_size.x, root_size.y],
		"visible_rect_size": [visible_size.x, visible_size.y],
		"viewport_texture_size": [texture_size.x, texture_size.y],
		"content_scale_render_size": [content_scale_size.x, content_scale_size.y],
		"content_scale_mode": root.content_scale_mode,
		"engine_max_fps": Engine.max_fps,
		"vsync_mode": vsync_mode,
		"warmup_seconds_min": WARMUP_SECONDS,
		"warmup_frames_min": WARMUP_MIN_FRAMES,
		"samples_per_case": SAMPLE_FRAMES,
		"minimum_measured_seconds_per_repetition": minimum_measured_seconds,
		"repetitions": repetitions,
		"fixed_simulation_hz": 60,
		"stress_extra_visual_rigs": EXTRA_STRESS_RIGS,
	}
	print("GLOAM_PERF_CONFIG ", JSON.stringify(config))

	var valid := true
	valid = _require(model_selection in ["default", "v1", "v2", "v4"], "model selection must be default, v1, v2, or v4") and valid
	valid = _require(renderer_method == "gl_compatibility", "renderer must be gl_compatibility") and valid
	valid = _require(display_driver.to_lower() != "headless", "normal display driver is required") and valid
	valid = _require(window_size == TARGET_RENDER_SIZE, "window content must be exactly 1920x1080") and valid
	valid = _require(root_size == TARGET_RENDER_SIZE, "root viewport must be exactly 1920x1080") and valid
	valid = _require(content_scale_size == TARGET_RENDER_SIZE, "fixed viewport content scale must be exactly 1920x1080") and valid
	valid = _require(texture_size == TARGET_RENDER_SIZE, "viewport texture must render exactly 1920x1080") and valid
	valid = _require(Engine.max_fps == 0, "Engine.max_fps must be uncapped") and valid
	valid = _require(vsync_mode == DisplayServer.VSYNC_DISABLED, "vsync must be disabled") and valid
	if model_selection in ["v1", "v4"]:
		valid = _require(minimum_measured_seconds >= 10.0, "paired character-art runs require at least 10 measured seconds per repetition") and valid
		valid = _require(repetitions >= 3, "paired character-art runs require at least 3 repetitions") and valid
	if valid:
		print("GLOAM_PERF_CONFIG_OK label=", benchmark_label)
	return valid


func _require(condition: bool, failure: String) -> bool:
	if not condition:
		push_error("GLOAM_PERF_CONFIG_FAIL " + failure)
	return condition


func _start_warmup(now_usec: int) -> void:
	phase = "warmup"
	warmup_frames = 0
	warmup_started_usec = now_usec
	last_frame_usec = 0
	sample_started_usec = 0


func _restart_current_case() -> void:
	game.reset_game()
	simulation_frame = 0
	_reset_samples()
	_start_warmup(Time.get_ticks_usec())


func _begin_stress_case() -> void:
	case_name = CASE_STRESS
	repetition_index = 0
	game.reset_game()
	simulation_frame = 0
	var positions := [
		Vector3(-4.5, 0.0, -3.1), Vector3(-1.5, 0.0, -3.1),
		Vector3(1.5, 0.0, -3.1), Vector3(4.5, 0.0, -3.1),
		Vector3(-4.5, 0.0, 0.4), Vector3(-1.5, 0.0, 0.4),
		Vector3(1.5, 0.0, 0.4), Vector3(4.5, 0.0, 0.4),
	]
	for index in EXTRA_STRESS_RIGS:
		var fixture_root := Node3D.new()
		fixture_root.name = "BenchmarkVisualRig_%02d" % (index + 1)
		fixture_root.position = positions[index]
		fixture_root.scale = Vector3.ONE * 1.35
		game.add_child(fixture_root)
		var accent := Color("#ba4f68") if index % 2 == 0 else Color("#5c99cb")
		var parts := _build_selected_player(fixture_root, accent)
		if parts.is_empty():
			quit(2)
			return
		fixtures.append({
			"root": fixture_root,
			"parts": parts,
		})
	print("GLOAM_PERF_STRESS_FIXTURE extra_visual_player_rigs=", EXTRA_STRESS_RIGS, " total_player_rigs=", EXTRA_STRESS_RIGS + 1, " enemy_ai_copies=0")
	_reset_samples()
	_reset_combined_samples()
	_start_warmup(Time.get_ticks_usec())


func _reset_samples() -> void:
	samples = {
		"frame_ms": [],
		"process_ms": [],
		"physics_ms": [],
		"viewport_render_cpu_ms": [],
		"viewport_render_gpu_ms": [],
		"draw_calls": [],
		"objects": [],
		"primitives": [],
	}
	gpu_timer_positive_samples = 0


func _reset_combined_samples() -> void:
	combined_samples = {
		"frame_ms": [],
		"process_ms": [],
		"physics_ms": [],
		"viewport_render_cpu_ms": [],
		"viewport_render_gpu_ms": [],
		"draw_calls": [],
		"objects": [],
		"primitives": [],
	}


func _record_sample(now_usec: int) -> void:
	(samples["frame_ms"] as Array).append(float(now_usec - last_frame_usec) / 1000.0)
	(samples["process_ms"] as Array).append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	(samples["physics_ms"] as Array).append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	(samples["viewport_render_cpu_ms"] as Array).append(RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid))
	var gpu_ms := RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
	(samples["viewport_render_gpu_ms"] as Array).append(gpu_ms)
	if is_finite(gpu_ms) and gpu_ms > 0.0001:
		gpu_timer_positive_samples += 1
	(samples["draw_calls"] as Array).append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	(samples["objects"] as Array).append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	(samples["primitives"] as Array).append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))


func _report_case() -> void:
	for metric: String in samples:
		(combined_samples[metric] as Array).append_array(samples[metric])
	var frame_stats := _distribution(samples["frame_ms"])
	var result := {
		"label": benchmark_label,
		"model_selection": model_selection,
		"case": case_name,
		"repetition": repetition_index + 1,
		"repetitions": repetitions,
		"fixture_claim": "real courtyard" if case_name == CASE_COURTYARD else "real courtyard plus 8 visual-only animated player-rig copies; not enemy AI",
		"sample_frames": samples["frame_ms"].size(),
		"measured_wall_seconds": _sum(samples["frame_ms"]) / 1000.0,
		"frame_ms": frame_stats,
		"observed_fps_from_mean_wall_delta": 1000.0 / maxf(frame_stats["mean"], 0.000001),
		"cpu_process_ms": _distribution(samples["process_ms"]),
		"cpu_physics_ms": _distribution(samples["physics_ms"]),
		"viewport_render_cpu_ms": _distribution(samples["viewport_render_cpu_ms"]),
		"draw_calls": _distribution(samples["draw_calls"]),
		"objects_drawn": _distribution(samples["objects"]),
		"primitives_drawn": _distribution(samples["primitives"]),
	}
	var gpu_sample_count: int = samples["viewport_render_gpu_ms"].size()
	if gpu_sample_count > 0 and gpu_timer_positive_samples >= int(ceil(gpu_sample_count * 0.95)):
		result["viewport_render_gpu_ms"] = _distribution(samples["viewport_render_gpu_ms"])
		result["gpu_timing_status"] = "reported by RenderingServer viewport timer"
	else:
		result["viewport_render_gpu_ms"] = null
		result["gpu_timing_status"] = "unavailable: gl_compatibility did not return a positive viewport GPU timer for at least 95% of samples"
	print("GLOAM_PERF_CASE ", JSON.stringify(result))


func _report_case_aggregate() -> void:
	var frame_stats := _distribution(combined_samples["frame_ms"])
	var gpu_positive := 0
	for value: float in combined_samples["viewport_render_gpu_ms"]:
		if is_finite(value) and value > 0.0001:
			gpu_positive += 1
	var aggregate := {
		"label": benchmark_label,
		"model_selection": model_selection,
		"case": case_name,
		"repetitions": repetitions,
		"total_sample_frames": combined_samples["frame_ms"].size(),
		"total_measured_wall_seconds": _sum(combined_samples["frame_ms"]) / 1000.0,
		"frame_ms": frame_stats,
		"observed_fps_from_mean_wall_delta": 1000.0 / maxf(frame_stats["mean"], 0.000001),
		"cpu_process_ms": _distribution(combined_samples["process_ms"]),
		"cpu_physics_ms": _distribution(combined_samples["physics_ms"]),
		"viewport_render_cpu_ms": _distribution(combined_samples["viewport_render_cpu_ms"]),
		"draw_calls": _distribution(combined_samples["draw_calls"]),
		"objects_drawn": _distribution(combined_samples["objects"]),
		"primitives_drawn": _distribution(combined_samples["primitives"]),
		"presentation_caveat": "Observed wall cadence can include compositor or swap pacing even when Engine.max_fps=0 and vsync reports disabled; it is not a GPU ceiling.",
		"sampling_caveat": "Godot Performance process/render monitors can describe the preceding frame and must be compared only under this identical protocol.",
	}
	if gpu_positive >= int(combined_samples["viewport_render_gpu_ms"].size() * 0.95):
		aggregate["viewport_render_gpu_ms"] = _distribution(combined_samples["viewport_render_gpu_ms"])
		aggregate["gpu_timing_status"] = "reported by RenderingServer viewport timer"
	else:
		aggregate["viewport_render_gpu_ms"] = null
		aggregate["gpu_timing_status"] = "unavailable: gl_compatibility did not return a positive viewport GPU timer for at least 95% of samples"
	print("GLOAM_PERF_AGGREGATE ", JSON.stringify(aggregate))


func _sum(values: Array) -> float:
	var total := 0.0
	for value in values:
		total += float(value)
	return total


func _distribution(values: Array) -> Dictionary:
	var ordered := values.duplicate()
	ordered.sort()
	var total := 0.0
	for value in ordered:
		total += float(value)
	return {
		"min": float(ordered.front()),
		"median": _percentile(ordered, 0.50),
		"p95": _percentile(ordered, 0.95),
		"p99": _percentile(ordered, 0.99),
		"max": float(ordered.back()),
		"mean": total / float(ordered.size()),
	}


func _percentile(ordered: Array, percentile: float) -> float:
	var position := (ordered.size() - 1) * percentile
	var lower := int(floor(position))
	var upper := int(ceil(position))
	if lower == upper:
		return float(ordered[lower])
	return lerpf(float(ordered[lower]), float(ordered[upper]), position - lower)
