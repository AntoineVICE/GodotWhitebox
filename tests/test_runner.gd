extends SceneTree
## Uses the pinned, real Ink runtime; no mock parser.
const DB = preload("res://scripts/content_db.gd")
const Conditions = preload("res://scripts/condition_evaluator.gd")
const Effects = preload("res://scripts/effect_executor.gd")
const State = preload("res://scripts/game_state.gd")
const Runner = preload("res://scripts/dialogue_runner.gd")
const Save = preload("res://scripts/save_service.gd")
var db = DB.new()
var conditions = Conditions.new()
var effects
var state
var runner
var count: int = 0
var failures: int = 0
var last_check: Dictionary = {}
var reject_commit: bool = false
var m1_done = false
var world_done = false
var persistence_done = false
var registry_done = false

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	count += 1
	if not value:
		failures += 1
		printerr("FAIL: " + description)
	else: print("PASS: " + description)

func world_state(snapshot: Dictionary) -> Dictionary:
	var value = snapshot.duplicate(true)
	value.erase("narrative")
	return value

func commit(next: Dictionary, _reason: String) -> bool:
	if reject_commit: return false
	for id in db.data.tasks:
		next.task_states[id] = "complete" if conditions.evaluate(db.data.tasks[id].condition, next).ok else "active"
	var validated = Save.new().validate_snapshot(next, db)
	if not validated.ok:
		printerr("FAIL: fixture commit rejected " + validated.error)
		failures += 1
		return false
	state.replace_state(validated.state)
	return true

func reset_fixture() -> void:
	runner.close()
	state.reset(db.data.initial_state)
	last_check.clear()
	reject_commit = false

func has_choice(id: String) -> bool:
	for choice in runner.current_view().get("choices", []):
		if choice.id == id: return not choice.disabled
	return false

func run() -> void:
	var loaded = db.load_content()
	check(loaded.ok, "world, character registry, rules and compiled Ink validate: " + loaded.get("error", ""))
	if not loaded.ok:
		quit(1)
		return
	effects = Effects.new(db, conditions)
	state = State.new()
	root.add_child(state)
	runner = Runner.new()
	root.add_child(runner)
	runner.setup(db, conditions, effects, state, commit)
	runner.checked.connect(func(details): last_check = details)
	if "--registry" in OS.get_cmdline_user_args():
		await registry_tests()
		print("REGISTRY TOTAL: %d assertions / %d failures" % [count, failures])
		runner.free()
		state.free()
		quit(0 if failures == 0 else 1)
		return
	core_tests()
	check(m1_done, "all M1 test functions completed")
	print("M1: %d assertions / %d failures" % [count, failures])
	if not "--m1" in OS.get_cmdline_user_args():
		await extended_tests()
		check(world_done, "all world/agency tests completed")
		if not "--m2" in OS.get_cmdline_user_args(): check(persistence_done, "all persistence tests completed")
		await registry_tests()
		check(registry_done, "26-character registry tests completed")
	runner.free()
	state.free()
	print("TOTAL: %d assertions / %d failures" % [count, failures])
	quit(0 if failures == 0 else 1)

func core_tests() -> void:
	check(not db.data.has("dialogues"), "JSON dialogue engine removed; prose and branches are Ink")
	check(ProjectSettings.get_setting("autoload/GameState") != null, "GameState is registered")
	var autoloads = 0
	for property in ProjectSettings.get_property_list():
		if property.name.begins_with("autoload/"): autoloads += 1
	check(autoloads == 1, "only one Autoload; Ink service is an ordinary node")
	for affinity in [0, 20]:
		for has_clue in [false, true]:
			reset_fixture()
			var snapshot = state.snapshot()
			snapshot.affinities.npc_a = affinity
			snapshot.clues = ["clue_a"] if has_clue else []
			state.replace_state(snapshot)
			runner.start("dialogue_a")
			check(has_choice("private_check") == (affinity == 20 and has_clue), "Ink private topic gate affinity=%s clue=%s" % [affinity, has_clue])
	for high in [true, false]:
		reset_fixture()
		check(runner.start("dialogue_a"), "start real Ink story")
		var token = runner.token
		check(runner.current_view().lines.any(func(line): return line.speaker_id == "player"), "one Ink passage contains multiple registered speakers")
		check(runner.current_view().text.contains("麻醉") and runner.current_view().text.contains("藏"), "new character motivation is authored in Ink")
		check(runner.choose("prepare_pass" if high else "prepare_fail", token), "intro high=%s" % high)
		check(not runner.choose("refuse_help", token), "stale menu callback rejected")
		check(not runner.choose("prepare_pass"), "shared initial response cannot repeat")
		runner.close()
		runner.start("dialogue_a")
		check(not runner.choose("prepare_fail"), "reopening Ink cannot repeat initial reward")
		check(not has_choice("private_check"), "no clue blocks private topic")
		runner.close()
		var prepared = state.snapshot()
		prepared.clues = ["clue_a"]
		state.replace_state(prepared)
		runner.start("dialogue_a")
		check(has_choice("private_check"), "low and high traits both see enabled inquiry")
		check(last_check.is_empty(), "presenting choices never performs a trait check")
		check(runner.choose("private_check"), "choose then check high=%s" % high)
		check(state.snapshot().flags.check_passed == high, "Ink success/failure branch matches trait")
		check(last_check.actual == (20 if high else 0) and last_check.threshold == 20, "pre-choice trait and configured threshold diagnostic")
		check(state.snapshot().task_states.task_a == "active", "learning background is not errand completion")
		check(runner.current_view().text.contains("检定成功" if high else "检定失败"), "Ink branch text matches result")
		runner.close()
		runner.start("dialogue_a")
		check(not runner.choose("private_check"), "private response once key persists outside Ink menu")
		runner.close()
		runner.start("dialogue_b")
		var prior_traits = state.snapshot().traits
		check(runner.choose("greet_b"), "monk reward from Ink action")
		check(state.snapshot().affinities == {"npc_a":20,"npc_b":5} and state.snapshot().traits == prior_traits, "affinities independent and fixed")
		check(not runner.choose("greet_b"), "monk cannot reward twice")
		check(runner.choose("ask_warning") and runner.current_view().text.contains("脑子"), "monk explains his own reason for hiding the drug")
	reset_fixture()
	var before = state.snapshot()
	var copied = before.duplicate(true)
	copied.traits.mercy = 999
	copied.clues.append("clue_a")
	check(state.snapshot() == before and db.data.initial_state.traits.mercy == 0, "snapshots and initial definitions are isolated")
	var batch: Array = []
	for id in db.data.traits: batch.append({"type":"add_trait","id":id,"amount":-7})
	var applied = effects.apply(batch, before)
	check(applied.ok and applied.state.traits.values().all(func(v): return v == -7), "six independent negative traits supported")
	check(not effects.apply([{"type":"add_trait","id":"mercy","amount":10},{"type":"add_affinity","id":"unknown","amount":5}], before).ok and state.snapshot() == before, "effect validation is atomic")
	check(not effects.apply([{"type":"execute_code","id":"mercy"}], before).ok, "unregistered effects rejected")
	check(not db.validate_condition({"not":{"any":[{"kind":"trait","id":"mercy","value":0}]}}, true).is_empty(), "nested attribute visibility gate prohibited")
	check(conditions.evaluate({"any":[{"kind":"phase","id":"phase_b"},{"not":{"kind":"clue","id":"clue_a"}}]}, before).ok, "any/not conditions")
	check(conditions.evaluate({"kind":"trait","id":"mercy","op":"lte","value":0}, before).ok, "numeric lte condition")
	check(conditions.evaluate({"kind":"once_unused","id":"npc_a_intro"}, before).ok, "once_unused condition")
	# Failure in the commit must roll back both the narrative cursor and the world.
	runner.start("dialogue_a")
	before = state.snapshot()
	var view_before = runner.current_view()
	reject_commit = true
	check(not runner.choose("prepare_pass"), "failed world commit rejects Ink turn")
	check(state.snapshot() == before and runner.session.serialize() == before.narrative.ink_state and runner.current_view() == view_before, "Ink and world rollback together; old menu remains valid")
	reject_commit = false
	check(runner.choose("prepare_pass"), "same action can retry after rollback without lost choice")
	reset_fixture()
	runner.start("dialogue_a")
	before = state.snapshot()
	db.data.actions.prepare_pass.effects.append({"type":"set_flag","id":"unknown","value":true})
	check(not runner.choose("prepare_pass") and state.snapshot() == before, "invalid action midway rolls back world and Ink")
	db.data.actions.prepare_pass.effects.pop_back()
	check(runner.choose("prepare_pass"), "fixed action retries successfully")
	story_state_tests()
	compiler_tests()
	m1_done = true

func story_state_tests() -> void:
	reset_fixture()
	var world_before = world_state(state.snapshot())
	var openings: Dictionary = {}
	for i in range(18):
		runner.start("dialogue_a")
		openings[runner.current_view().text] = true
		runner.close()
	check(openings.size() > 1, "Ink shuffle varies greetings")
	check(world_state(state.snapshot()) == world_before, "reading and shuffle do not award world progress")
	check(not state.snapshot().narrative.ink_state.is_empty(), "Ink reading/visit/random progress is persisted")
	runner.start("dialogue_a")
	var view = runner.current_view()
	check(runner.current_view() == view and runner.current_view() == view, "UI repaint does not advance Ink")
	runner.close()
	var checkpoint = state.snapshot()
	runner.start("dialogue_a")
	var predicted = runner.current_view().text
	runner.close()
	state.replace_state(checkpoint)
	runner.start("dialogue_a")
	check(runner.current_view().text == predicted, "restoring Ink random state reproduces the next reading")
	reset_fixture()
	runner.start("dialogue_a")
	runner.choose("refuse_help")
	runner.close()
	check(db.route_entry("dialogue_a", state.snapshot(), conditions) == "rodrigo_refused", "spoken stance selects route")
	var held = state.snapshot()
	held.flags.poppy_held = true
	state.replace_state(held)
	check(db.route_entry("dialogue_a", held, conditions) == "rodrigo_carrying", "carried packet takes route priority over spoken refusal")
	reset_fixture()
	check(state.snapshot() == db.data.initial_state and state.snapshot().narrative.ink_state.is_empty(), "full reset clears all Ink visits and story state")

func compiler_tests() -> void:
	var compiler = preload("res://scripts/story_compiler.gd").new()
	var source = "user://invalid_authoring.ink"
	var file = FileAccess.open(source, FileAccess.WRITE)
	file.store_string('EXTERNAL game_check(id)\n-> entry\n=== entry ===\n+ {game_check("ask_reason")} [Bad # id:bad]\n    -> END\n')
	file.close()
	var result = compiler.build(source, "user://invalid_authoring.json", "user://invalid_authoring_manifest.json")
	check(not result.ok and result.error.contains("选择之后"), "authoring linter rejects checks used to hide options")
	file = FileAccess.open(source, FileAccess.WRITE)
	file.store_string('EXTERNAL game_action(id)\n-> entry\n=== entry ===\n+ [Bad # id:bad]\n    ~ game_action("unregistered")\n    -> END\n')
	file.close()
	result = compiler.build(source, "user://invalid_authoring.json", "user://invalid_authoring_manifest.json")
	check(not result.ok and result.error.contains("未注册"), "authoring linter catches unknown action with source location")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(source))

func extended_tests() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var runtime = root.get_node("GameState")
	for high in [true, false]:
		main.reset_game()
		check(main.world.room.get_node("Actors").get_child_count() == 1, "initial NPC count")
		main.interact("npc_a")
		check(main.player.locked and main.save_button.disabled and main.load_button.disabled, "dialogue locks world/save/load")
		var original = runtime.snapshot()
		main.debug_phase("phase_b")
		check(runtime.snapshot() == original, "phase modification rejected during dialogue")
		main.runner.choose("prepare_pass" if high else "prepare_fail")
		main.runner.close()
		main.interact("clue_object")
		var after_clue = runtime.snapshot()
		main.interact("clue_object")
		check(runtime.snapshot() == after_clue and not main.world.has_interactable("clue_object"), "clue collected once and disappears")
		main.interact("npc_a")
		main.runner.choose("private_check")
		check(runtime.snapshot().task_states.task_a == "active", "Main keeps errand active after inquiry high=%s" % high)
		main.runner.close()
		main.interact("phase_switch")
		check(runtime.snapshot().phase_id == "phase_b" and main.world.room.get_node("Actors").get_child_count() == 0, "phase removes NPC_A from A")
		check(main.player.current_target.is_empty() and main.player.candidates.is_empty(), "phase clears stale interaction targets")
		var after_phase = runtime.snapshot()
		main.interact("phase_switch")
		check(runtime.snapshot() == after_phase, "phase switch only once")
		main.interact("door_to_b")
		check(runtime.snapshot().room_id == "room_b" and main.world.room.get_node("Actors").get_child_count() == 2, "B contains two NPCs in phase_b")
		for npc in main.world.room.get_node("Actors").get_children():
			var location = main.content.data.phases.phase_b.npcs[npc.interactable_id]
			check(npc.position == main.world.room.get_node("Markers/" + location.marker_id).position, "NPC positioned at configured marker " + npc.interactable_id)
		main.world.refresh_actors("phase_b")
		main.world.refresh_actors("phase_b")
		check(main.world.room.get_node("Actors").get_child_count() == 2, "repeated actor refresh never duplicates")
		main.interact("npc_b")
		main.runner.choose("greet_b")
		main.runner.close()
		main.interact("door_to_a")
		check(runtime.snapshot().room_id == "room_a" and not main.world.has_interactable("npc_a") and not main.world.has_interactable("clue_object"), "return preserves moved NPC and collected clue")
		check(runtime.snapshot().affinities == {"npc_a":20,"npc_b":5} and runtime.snapshot().task_states.task_a == "active", "room travel retains affinities/task")
		main.interact("door_to_b")
		main.interact("outcome_terminal")
		check(main.runner.active and not main.result_panel.visible, "cabinet opens an interaction, not settlement")
		check(not main.conditions.evaluate(main.content.data.outcomes.outcome_a.condition, runtime.snapshot()).ok, "knowing the truth never grants delivery outcome")
		var token = main.runner.token
		check(main.runner.choose("search_cabinet"), "search finds hidden packet without taking")
		token = main.runner.token
		check(main.runner.choose("take_poppy", token), "take packet as a separate world action high=%s" % high)
		check(runtime.snapshot().flags.poppy_held and not runtime.snapshot().flags.get("poppy_delivered", false) and runtime.snapshot().selected_outcome == null, "taking records possession without handing over or ending")
		check(not main.runner.choose("take_poppy", token), "double-click take is rejected")
		main.runner.close()
		check(not main.player.locked, "player can walk away after taking")
		main.interact("outcome_terminal")
		var taken = runtime.snapshot()
		check(not main.runner.choose("take_poppy") and world_state(runtime.snapshot()) == world_state(taken), "reopen cabinet cannot take again")
		main.runner.close()
		main.interact("npc_a")
		check(main.runner.choose("hand_over" if high else "end_request"), "delivery and final refusal happen at NPC")
		check(runtime.snapshot().selected_outcome == null, "NPC action is visible before final goodbye")
		if high:
			check(runtime.snapshot().flags.poppy_delivered and not runtime.snapshot().flags.poppy_held, "handover removes held packet and records delivery")
			check(runtime.snapshot().affinities == {"npc_a":25,"npc_b":5}, "delivery grants configured fixed affinity only to recipient")
		else:
			check(runtime.snapshot().flags.poppy_held and not runtime.snapshot().flags.get("poppy_delivered", false), "final refusal never auto-delivers the packet")
		token = main.runner.token
		check(main.runner.choose("finish_delivery" if high else "finish_refusal", token), "both paths settle through NPC goodbye")
		check(not main.runner.choose("finish_delivery", token), "stale final callback rejected")
		check(main.player.locked and runtime.snapshot().selected_outcome == ("outcome_a" if high else "outcome_b") and runtime.snapshot().task_states.task_a == "complete", "goodbye completes errand and locks settled world")
		main.reset_game()
		check(runtime.snapshot() == main.content.data.initial_state and not main.result_panel.visible and not main.runner.active, "full reset persistent state and open panels")
		check(main.logs.is_empty() and main.recent_check.is_empty() and main.world.has_interactable("clue_object") and main.world.has_interactable("npc_a"), "reset restores clue/NPC and clears logs/check")
	agency_tests(main, runtime)
	world_done = true
	if not "--m2" in OS.get_cmdline_user_args(): await persistence_tests(main, runtime)
	main.queue_free()
	await process_frame
	await process_frame

func agency_tests(main, runtime) -> void:
	# Same physical outcome from an initial refusal and a failed private inquiry.
	for response in ["refuse_help", "prepare_fail"]:
		main.reset_game()
		main.interact("npc_a")
		check(not main.runner.choose("hand_over"), "cannot hand over a packet not held")
		check(main.runner.choose(response), "initial spoken response " + response)
		check(runtime.snapshot().selected_outcome == null and runtime.snapshot().task_states.task_a == "active", "early response does not settle or complete the errand")
		if response == "refuse_help":
			check(runtime.snapshot().flags.refused_help and not runtime.snapshot().flags.get("promised_help", false), "refusal is recorded independently of action")
			check(runtime.snapshot().affinities.npc_a == 0, "refusal grants no unrelated reward")
		main.runner.close()
		if response == "prepare_fail":
			main.interact("clue_object")
			main.interact("npc_a")
			check(main.runner.choose("private_check") and not runtime.snapshot().flags.check_passed, "low trait can choose and fail inquiry")
			main.runner.close()
		main.interact("phase_switch")
		check(runtime.snapshot().phase_id == "phase_b", "phase does not require agreeing or a successful check")
		main.interact("door_to_b")
		main.interact("npc_a")
		check(main.runner.choose("end_request"), "final refusal can be considered separately from opening")
		check(main.runner.choose("back") and runtime.snapshot().selected_outcome == null, "back out of final refusal and keep exploring")
		main.runner.close()
		main.interact("outcome_terminal")
		check(main.runner.choose("search_cabinet"), "refused/failed player can locate hidden packet")
		check(main.runner.choose("take_poppy"), "refused/failed player can actually take packet")
		main.runner.close()
		main.interact("door_to_a")
		main.interact("door_to_b")
		check(runtime.snapshot().flags.poppy_held and not main.player.locked, "held packet survives room travel")
		main.interact("npc_a")
		check(main.runner.choose("hand_over"), "refused/failed player can hand over packet")
		if response == "refuse_help":
			check(main.runner.current_view().text.contains("不是说不帮我"), "recipient reacts to words followed by different action")
		var delivered = runtime.snapshot()
		main.runner.close()
		main.interact("npc_a")
		check(not main.runner.choose("hand_over") and world_state(runtime.snapshot()) == world_state(delivered), "reopening NPC cannot repeat delivery reward")
		check(main.runner.choose("resume_delivery"), "interrupted goodbye resumes after physical delivery")
		check(main.runner.choose("finish_delivery") and runtime.snapshot().selected_outcome == "outcome_a", "refused/failed route can finish with actual delivery")
	# Explore before replying: no hidden dependency on spoken agreement.
	main.reset_game()
	main.interact("door_to_b")
	main.interact("outcome_terminal")
	check(not main.runner.choose("take_poppy"), "before evening opportunity cabinet can be inspected but not taken")
	main.runner.close()
	main.interact("door_to_a")
	main.interact("phase_switch")
	main.interact("door_to_b")
	main.interact("outcome_terminal")
	check(main.runner.choose("search_cabinet"), "can locate hidden packet before replying")
	check(main.runner.choose("take_poppy"), "can take before choosing a spoken response")
	main.runner.close()
	main.interact("npc_a")
	check(main.runner.choose("hand_over") and main.runner.choose("finish_delivery"), "taking and delivery do not require intro, clue or inquiry")
	# A promise is not automatic completion; settle without taking anything.
	main.reset_game()
	main.interact("npc_a")
	main.runner.choose("prepare_pass")
	main.runner.close()
	main.interact("clue_object")
	main.interact("npc_a")
	main.runner.choose("private_check")
	main.runner.close()
	main.interact("phase_switch")
	main.interact("door_to_b")
	main.interact("npc_a")
	check(main.runner.choose("end_request") and main.runner.choose("finish_refusal"), "successful inquiry still permits declining physical action")
	check(runtime.snapshot().selected_outcome == "outcome_b" and not runtime.snapshot().flags.get("poppy_taken", false), "promise and successful check do not fabricate taking or delivery")
	main.reset_game()

func persistence_tests(main, runtime) -> void:
	# Never touch the user's actual save slot.
	var path = "user://whitebox_core_test.json"
	var service = Save.new(path)
	main.saves = service
	main.reset_game()
	check(service.save(runtime.snapshot()).ok, "single slot initial write")
	main.interact("npc_a")
	main.runner.choose("prepare_pass")
	main.runner.close()
	main.interact("clue_object")
	main.interact("npc_a")
	main.runner.choose("private_check")
	main.runner.close()
	main.interact("phase_switch")
	main.interact("door_to_b")
	main.interact("npc_b")
	main.runner.choose("greet_b")
	main.runner.close()
	main.interact("outcome_terminal")
	main.runner.choose("search_cabinet")
	main.runner.choose("take_poppy")
	main.runner.close()
	var saved = runtime.snapshot()
	main.save_game()
	var roundtrip = service.load_validated(db)
	check(roundtrip.ok and roundtrip.state == saved, "overwrite and JSON roundtrip exact equality with integers")
	main.debug_edit("traits", "mercy", -77)
	main.debug_phase("phase_a")
	main.change_room("room_a", "spawn_start")
	main.load_game()
	check(runtime.snapshot() == saved and main.world.loaded_room == "room_b" and main.world.loaded_phase == "phase_b", "Main save/change/read restores all state and world")
	check(main.player.position == main.world.room.get_node("Markers/" + saved.spawn_id).position, "load uses saved spawn rather than pixel position")
	main.load_game()
	main.interact("outcome_terminal")
	check(not main.runner.choose("take_poppy") and runtime.snapshot().flags.poppy_held, "load preserves possession and consumed cabinet key")
	main.runner.close()
	main.interact("npc_b")
	check(not main.runner.choose("greet_b"), "repeat load and reopen cannot repeat NPC reward")
	main.runner.close()
	main.interact("npc_a")
	check(not main.runner.choose("prepare_pass") and not main.runner.choose("private_check"), "loaded once keys protect intro and private check")
	var before = runtime.snapshot()
	main.load_game()
	main.save_game()
	check(runtime.snapshot() == before and main.notice.text == "请先结束对话", "save/load API blocks active dialogue")
	main.reset_game()
	check(runtime.snapshot() == db.data.initial_state and FileAccess.file_exists(path), "reset while dialogue active keeps disk save")
	main.load_game()
	check(runtime.snapshot() == saved, "load after full reset restores saved progress")
	check(not saved.narrative.ink_state.is_empty(), "save includes actual Ink cursor, visit counts and random state")
	# Save after actual delivery, interrupt before goodbye, restore without replaying reward.
	main.interact("npc_a")
	check(main.runner.choose("hand_over"), "loaded held packet can be delivered")
	main.runner.close()
	var handed_over = runtime.snapshot()
	main.save_game()
	main.reset_game()
	main.load_game()
	check(runtime.snapshot() == handed_over and not runtime.snapshot().flags.poppy_held, "load restores already delivered state")
	main.interact("npc_a")
	check(not main.runner.choose("hand_over") and runtime.snapshot().affinities.npc_a == 25, "loaded delivery cannot repeat fixed reward")
	check(main.runner.choose("resume_delivery") and main.runner.choose("finish_delivery"), "loaded delivery can finish goodbye")
	check(service.save(saved).ok, "restore earlier held-packet save for alternate ending")
	main.load_game()
	main.interact("npc_a")
	check(main.runner.choose("end_request") and main.runner.choose("finish_refusal"), "successful check may voluntarily end without delivery")
	var settled = runtime.snapshot()
	main.save_game()
	main.reset_game()
	main.load_game()
	check(runtime.snapshot() == settled and main.result_panel.visible and main.player.locked, "saved outcome restores result panel and input lock")
	check(service.save(saved).ok, "save can overwrite settled slot")
	main.load_game()
	check(not main.result_panel.visible and not main.player.locked, "pre-result save reopens world without stale result UI")
	# Narrative corruption/version errors must not reach the Ink deserializer.
	for pair in [["story_id","wrong"],["build_id","wrong"],["ink_state","{broken"],["state_hash","wrong"],["result_text",5]]:
		var invalid_narrative = saved.duplicate(true)
		invalid_narrative.narrative[pair[0]] = pair[1]
		check(not service.validate_snapshot(invalid_narrative, db).ok, "save rejects invalid Ink field " + pair[0])
	var missing_ink = saved.duplicate(true)
	missing_ink.erase("narrative")
	check(not service.validate_snapshot(missing_ink, db).ok, "old saves without Ink state rejected explicitly")
	var changed_ink = saved.duplicate(true)
	changed_ink.narrative.ink_state = '{"inkSaveVersion":10}'
	changed_ink.narrative.state_hash = changed_ink.narrative.ink_state.sha256_text()
	check(not service.validate_snapshot(changed_ink, db).ok, "incomplete Ink state rejected even with recomputed checksum")
	var invalid_cases = []
	for key in ["schema_version", "content_version", "room_id", "spawn_id", "phase_id", "traits", "affinities", "flags", "clues", "task_states", "consumed_once_keys", "selected_outcome", "narrative"]:
		var missing = saved.duplicate(true)
		missing.erase(key)
		invalid_cases.append(["missing " + key, missing])
	for pair in [["schema_version",3],["content_version","wrong"],["content_version","demo-v1"],["room_id","unknown"],["spawn_id","unknown"],["phase_id","unknown"],["traits",[]],["affinities",[]],["flags",[]],["clues",{}],["task_states",[]],["consumed_once_keys",{}],["selected_outcome","unknown"]]:
		var invalid = saved.duplicate(true)
		invalid[pair[0]] = pair[1]
		invalid_cases.append(["invalid " + pair[0], invalid])
	for value in [0.5, "20", true, INF, NAN]:
		var invalid = saved.duplicate(true)
		invalid.traits.mercy = value
		invalid_cases.append(["noninteger trait " + str(value), invalid])
	for pair in [["traits","unknown",0],["affinities","unknown",20],["flags","unknown",true],["flags","intro_done",1],["task_states","task_a","complete"]]:
		var invalid = saved.duplicate(true)
		invalid[pair[0]][pair[1]] = pair[2]
		invalid_cases.append(["bad reference/type " + str(pair), invalid])
	for pair in [["clues","unknown"],["consumed_once_keys","unknown"]]:
		var invalid = saved.duplicate(true)
		invalid[pair[0]].append(pair[1])
		invalid_cases.append(["bad collection reference " + pair[0], invalid])
	for entry in invalid_cases:
		check(not service.validate_snapshot(entry[1], db).ok, "save validator rejects " + entry[0])
	var duplicates = saved.duplicate(true)
	duplicates.clues.append("clue_a")
	duplicates.consumed_once_keys.append("npc_a_intro")
	var deduped = service.validate_snapshot(duplicates, db)
	check(deduped.ok and deduped.state == saved, "load deduplicates clue and once collections")
	for bad_text in ["{ broken", "[]", JSON.stringify(invalid_cases[12][1])]:
		var file = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(bad_text)
		file.close()
		var prior = runtime.snapshot()
		main.load_game()
		check(runtime.snapshot() == prior and FileAccess.get_file_as_string(path) == bad_text, "bad JSON/version leaves state and disk untouched")
	var missing_service = Save.new("user://does_not_exist_whitebox/no_save.json")
	check(not missing_service.load_validated(db).ok, "missing file returns an error")
	check(not missing_service.save(saved).ok, "write open failure returns an error")
	var prior = runtime.snapshot()
	var malformed = prior.duplicate(true)
	malformed.affinities["unknown"] = 10
	check(not main.commit_snapshot(malformed, "bad") and runtime.snapshot() == prior, "Main rejects invalid state atomically")
	# Both stale menu tokens and input locks reset in the same operation.
	main.interact("npc_a")
	var token = main.runner.token
	main.reset_game()
	main.interact("npc_a")
	check(not main.runner.choose("prepare_pass", token) and world_state(runtime.snapshot()) == world_state(db.data.initial_state), "pre-reset menu token cannot award on new run")
	main.reset_game()
	# Two overlapping targets at equal distance must sort by stable ID.
	var actor_scene = load("res://scenes/interactable.tscn")
	var near_a = actor_scene.instantiate()
	var near_b = actor_scene.instantiate()
	near_a.interactable_id = "npc_a"
	near_b.interactable_id = "clue_object"
	near_a.position = main.player.position + Vector2(10, 0)
	near_b.position = main.player.position - Vector2(10, 0)
	main.world.room.get_node("Objects").add_child(near_a)
	main.world.room.get_node("Objects").add_child(near_b)
	for i in range(4): await physics_frame
	main.player.refresh_target()
	check(main.player.current_target == "clue_object", "overlapping equal-distance candidates use stable ID")
	near_a.queue_free()
	near_b.queue_free()
	main.player.clear_target()
	for i in range(3): await physics_frame
	check(main.player.candidates.is_empty(), "removed candidates leave no stale references")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if FileAccess.file_exists(path + ".tmp"): DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))

	persistence_done = true

func registry_tests() -> void:
	var fixture = DB.new()
	check(fixture.load_content().ok, "load independent registry fixture")
	for i in range(24):
		var id = "fixture_%02d" % i
		fixture.data.characters[id] = {"label":"测试人物%02d" % i,"kind":"npc","initial_affinity":i,"dialogue_id":"fixture_dialogue","portrait":""}
	fixture.data.dialogue_routes.fixture_dialogue = [{"entry":"ambient_greeting","condition":{}}]
	fixture.assemble_characters()
	check(fixture.validate_content().ok and fixture.data.npcs.size() == 26, "26 NPCs register through data without new scripts")
	var fixture_state = State.new()
	root.add_child(fixture_state)
	fixture_state.reset(fixture.data.initial_state)
	var fixture_runner = Runner.new()
	root.add_child(fixture_runner)
	fixture_runner.setup(fixture, conditions, Effects.new(fixture, conditions), fixture_state, func(next, _reason):
		fixture_state.replace_state(next)
		return true)
	var start_time = Time.get_ticks_msec()
	for i in range(24):
		var id = "fixture_%02d" % i
		check(fixture_runner.start("fixture_dialogue", id) and fixture_runner.current_view().speaker == fixture.data.characters[id].label, "shared Ink entry resolves explicit speaker " + id)
		fixture_runner.choose("leave")
	print("REGISTRY: 24 Ink conversations in %s ms" % (Time.get_ticks_msec() - start_time))
	var applied = Effects.new(fixture, conditions).apply([{"type":"add_affinity","id":"fixture_07","amount":5}], fixture_state.snapshot())
	check(applied.ok and applied.state.affinities.fixture_07 == 12 and applied.state.affinities.fixture_08 == 8 and applied.state.affinities.npc_a == 0, "26-character affinity rewards remain independent")
	fixture_state.replace_state(applied.state)
	var service = Save.new("user://registry_ink_test.json")
	check(service.save(fixture_state.snapshot()).ok, "save expanded registry and Ink together")
	var restored = service.load_validated(fixture)
	check(restored.ok and restored.state == fixture_state.snapshot(), "expanded registry and Ink roundtrip exactly: " + restored.get("error", ""))
	var panel = preload("res://scripts/ui/relationships_panel.gd").new()
	root.add_child(panel)
	panel.setup(fixture)
	panel.refresh(fixture_state.snapshot())
	panel.show()
	await process_frame
	check(panel.rows.size() == 26, "relationships panel creates all 26 rows")
	panel.search.text = "测试人物07"
	panel._filter(panel.search.text)
	check(panel.rows.values().filter(func(row): return row.visible).size() == 1 and panel.rows.fixture_07.visible, "relationship search handles many characters")
	fixture_state.reset(fixture.data.initial_state)
	check(fixture_state.snapshot().affinities.fixture_07 == 7 and fixture_state.snapshot().narrative.ink_state.is_empty(), "reset expanded registry and Ink")
	panel.queue_free()
	fixture_runner.queue_free()
	fixture_state.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(service.path))
	await process_frame
	registry_done = true
