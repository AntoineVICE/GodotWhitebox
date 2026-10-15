extends SceneTree
## Compiles author-edited Ink and exercises the real runtime, including Inky fallbacks.
const DB = preload("res://scripts/content_db.gd")
const Story = preload("res://addons/inkgd/runtime/ink_story.gd")
const Runtime = preload("res://addons/inkgd/ink_runtime.gd")
var count = 0
var failures = 0
var db
var state
var runtime
var conditions = preload("res://scripts/condition_evaluator.gd").new()
var errors: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	count += 1
	if not value: failures += 1
	print(("PASS: " if value else "FAIL: ") + message)

func compile_ink(source: String, output: String) -> bool:
	var compiler = OS.get_environment("INKLECATE")
	if compiler.is_empty(): compiler = ProjectSettings.globalize_path("res://tools/inklecate/inklecate.exe")
	var messages: Array = []
	var code = OS.execute(compiler, PackedStringArray(["-o", ProjectSettings.globalize_path(output), ProjectSettings.globalize_path(source)]), messages, true)
	check(code == 0 and not "ERROR:" in "\n".join(messages), "compile " + source + ": " + "\n".join(messages))
	return code == 0

func drain(story) -> String:
	var lines: Array = []
	var steps = 0
	while story.can_continue and steps < 200:
		lines.append(story.continue_story())
		steps += 1
	check(steps < 200 and errors.is_empty() and not runtime.has_raised_exceptions, "Ink preview completes without runtime errors")
	return "".join(lines)

func choose(story, id: String) -> String:
	for choice in story.current_choices:
		if choice.tags != null and choice.tags.has("id:" + id):
			story.choose_choice_index(choice.index)
			return drain(story)
	check(false, "preview choice exists: " + id)
	return ""

func commit(next: Dictionary, _reason: String) -> bool:
	for id in db.data.tasks:
		next.task_states[id] = "complete" if conditions.evaluate(db.data.tasks[id].condition, next).ok else "active"
	var valid = preload("res://scripts/save_service.gd").new().validate_snapshot(next, db)
	if not valid.ok: return false
	state.replace_state(valid.state)
	return true

func run() -> void:
	var build = preload("res://scripts/story_compiler.gd").new().build()
	check(build.ok, "production compiler and generated preview entry build")
	if not build.ok:
		printerr(build.error)
		quit(1)
		return
	db = DB.new()
	check(db.load_content().ok, "load current production bundle")
	runtime = Runtime.new()
	runtime.name = "__InkRuntime"
	runtime.stop_execution_on_exception = false
	runtime.stop_execution_on_error = false
	root.add_child(runtime)
	var preview_output = "res://tests/artifacts/preview.json"
	if not compile_ink("res://story/preview/main.ink", preview_output):
		quit(1)
		return
	for scenario in ["high", "low", "cabinet", "delivery", "monk"]:
		errors.clear()
		runtime.clear_raised_exceptions()
		var preview = Story.new(FileAccess.get_file_as_string(preview_output), runtime)
		preview.on_error.connect(func(message, _type): errors.append(message))
		preview.allow_external_function_fallbacks = true
		check(drain(preview).contains("写作预览"), "generated entry is executable, not an empty/comment-only story")
		choose(preview, "preview_" + scenario)
		match scenario:
			"high", "low":
				var text = choose(preview, "private_check")
				check(text.contains("检定成功" if scenario == "high" else "检定失败"), "standalone preview takes " + scenario + " branch after choice")
				check(preview.variables_state.get_variable("mock_once_npc_a_private_check"), "preview simulates once-only action")
			"cabinet":
				choose(preview, "search_cabinet")
				check(not preview.variables_state.get_variable("mock_flag_poppy_held"), "preview search does not take packet")
				choose(preview, "take_poppy")
				check(preview.variables_state.get_variable("mock_flag_poppy_held"), "preview take applies configured effect")
			"delivery":
				check(choose(preview, "hand_over").contains("不是说不帮我"), "preview refusal followed by delivery has revised response")
				choose(preview, "finish_delivery")
				check(preview.variables_state.get_variable("mock_outcome") == "outcome_a", "preview final goodbye selects configured outcome")
			"monk":
				check(choose(preview, "ask_warning").contains("脑子"), "preview includes monk's hiding explanation")
	# Compile a changed copy; production files remain untouched.
	var merged: Array = []
	for path in db.manifest.sources:
		if path != "res://story/main.ink": merged.append(FileAccess.get_file_as_string(path))
	var source = "\n".join(merged).replace("我要一点罂粟。", "作者改稿已生效。我要一点罂粟。")
	source += '\n=== test_transaction ===\n选择后先加属性，检定仍读取提交前状态。 # speaker:narrator\n+ [开始测试 # id:test]\n    ~ game_action("prepare_pass")\n    {game_check("ask_reason"):\n        ~ game_action("resolve_pass")\n        成功 # speaker:narrator\n    - else:\n        ~ game_action("resolve_fail")\n        失败 # speaker:narrator\n    }\n    ++ [结束 # id:leave]\n        -> DONE\n'
	var source_path = "res://tests/artifacts/edited_story.ink"
	var output_path = "res://tests/artifacts/edited_story.json"
	var file = FileAccess.open(source_path, FileAccess.WRITE)
	file.store_string(source)
	file.close()
	if not compile_ink(source_path, output_path):
		quit(1)
		return
	db.compiled_json = FileAccess.get_file_as_string(output_path)
	db.manifest.build_id = FileAccess.get_sha256(output_path)
	db.data.initial_state.narrative.build_id = db.manifest.build_id
	db.data.dialogue_routes.test_dialogue = [{"entry":"test_transaction", "condition":{}}]
	state = preload("res://scripts/game_state.gd").new()
	root.add_child(state)
	state.reset(db.data.initial_state)
	var runner = preload("res://scripts/dialogue_runner.gd").new()
	root.add_child(runner)
	runner.setup(db, conditions, preload("res://scripts/effect_executor.gd").new(db, conditions), state, commit)
	check(runner.start("dialogue_a") and runner.current_view().text.contains("作者改稿已生效"), "edited source compiles to actual displayed game dialogue")
	runner.close()
	state.reset(db.data.initial_state)
	var prepared = state.snapshot()
	prepared.clues = ["clue_a"]
	state.replace_state(prepared)
	check(runner.start("test_dialogue"), "start real Ink transaction fixture")
	check(runner.choose("test"), "same choice stages trait reward and resolves check")
	check(state.snapshot().traits.mercy == 20 and state.snapshot().flags.get("check_resolved", false) and not state.snapshot().flags.get("check_passed", true), "same-choice reward cannot improve pre-choice trait check")
	runner.free()
	state.free()
	print("AUTHORING TOTAL: %d assertions / %d failures" % [count, failures])
	quit(0 if failures == 0 else 1)
