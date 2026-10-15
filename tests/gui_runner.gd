extends SceneTree
## Graphical integration: inject keyboard/mouse events into the real viewport.
## Requires a display. Does not write the user's save slot.
var main
var count: int = 0
var failures: int = 0
var runtime
var artifact_dir: String = "res://tests/artifacts"

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	count += 1
	if value: print("GUI PASS: " + message)
	else:
		failures += 1
		printerr("GUI FAIL: " + message)

func frames(n: int = 4) -> void:
	for i in range(n): await process_frame

func key(code: Key, down: bool) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func tap(code: Key) -> void:
	key(code, true)
	await frames(2)
	key(code, false)
	await frames(3)

func move_to(x: float) -> void:
	var direction = KEY_D if main.player.position.x < x else KEY_A
	key(direction, true)
	for i in range(500):
		await physics_frame
		if abs(main.player.position.x - x) < 7: break
		# Window focus changes can clear synthetic held keys. Reassert the
		# intended key, without moving/teleporting the player through test code.
		if not Input.is_key_pressed(direction): key(direction, true)
	key(direction, false)
	await physics_frame
	await physics_frame
	check(abs(main.player.position.x - x) < 12, "keyboard movement to x=%s" % x)

func mouse_click(button: Button) -> void:
	await frames()
	if button == null:
		check(false, "expected clickable button exists")
		return
	var center = button.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = center
	root.push_input(motion, true)
	for down in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = center
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await frames(2)

func find_button(parent: Node, prefix: String) -> Button:
	if parent is Button and parent.text.begins_with(prefix): return parent
	for child in parent.get_children():
		var found = find_button(child, prefix)
		if found != null: return found
	return null

func find_action(parent: Node, key: String, id: String) -> Button:
	if parent is Button and parent.get_meta(key, "") == id: return parent
	for child in parent.get_children():
		var found = find_action(child, key, id)
		if found != null: return found
	return null

func screenshot(name: String) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	var error = root.get_texture().get_image().save_png(artifact_dir + "/" + name + ".png")
	check(error == OK, "capture " + name)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Graphical tests require a display; not executed.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(artifact_dir))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	runtime = root.get_node("GameState")
	main.saves = load("res://scripts/save_service.gd").new("user://whitebox_gui_test.json")
	await frames(12)
	await screenshot("01_room_a")
	# Left/right boundaries and nearest target are tested with real physics frames.
	key(KEY_A, true)
	await create_timer(0.6).timeout
	key(KEY_A, false)
	check(main.player.position.x >= 32, "left collision boundary")
	await move_to(1235)
	key(KEY_D, true)
	await create_timer(0.2).timeout
	key(KEY_D, false)
	check(main.player.position.x <= 1248, "right collision boundary")
	for response in ["prepare_pass", "prepare_fail", "refuse_help"]:
		var high = response == "prepare_pass"
		var refused = response == "refuse_help"
		main.reset_game()
		await frames()
		await move_to(260)
		check(main.player.current_target == "npc_a", "nearest NPC hint")
		await tap(KEY_E)
		check(main.runner.active and main.dialogue_panel.visible, "E opens dialogue")
		if high: await screenshot("00_story_opening")
		var start = main.player.position
		key(KEY_D, true)
		await create_timer(0.15).timeout
		key(KEY_D, false)
		check(main.player.position == start, "dialogue blocks movement")
		if high or refused:
			await mouse_click(find_action(main.dialogue_panel, "choice_id", response))
		else:
			await tap(KEY_TAB)
			await tap(KEY_ENTER)
		check(runtime.snapshot().traits.mercy == (20 if high else 0) and runtime.snapshot().affinities.npc_a == (0 if refused else 20), "mouse/keyboard selects correct intro")
		await tap(KEY_ESCAPE)
		check(runtime.snapshot().selected_outcome == null, "initial spoken refusal or promise never ends game")
		if not refused:
			await move_to(475)
			await tap(KEY_E)
			check(runtime.snapshot().clues == ["clue_a"], "E collects clue")
			await move_to(345)
			await tap(KEY_E)
			var private_button = find_action(main.dialogue_panel, "choice_id", "private_check")
			check(private_button != null and not private_button.disabled, "private option enabled including low trait")
			await screenshot("02_high_choice" if high else "05_low_choice")
			await mouse_click(private_button)
			check(runtime.snapshot().flags.get("check_passed") == high, "visible dialogue check result")
			await screenshot("03_pass" if high else "06_fail")
			await tap(KEY_ESCAPE)
		await move_to(715)
		await tap(KEY_E)
		check(runtime.snapshot().phase_id == "phase_b", "E advances phase after pass or fail")
		await move_to(1090)
		await tap(KEY_E)
		check(runtime.snapshot().room_id == "room_b" and main.world.room.get_node("Actors").get_child_count() == 2, "E door changes room and NPC placement")
		await move_to(995)
		await tap(KEY_E)
		check(main.runner.active and not main.result_panel.visible, "E opens cabinet without ending game")
		await screenshot("11_cabinet")
		check(find_action(main.dialogue_panel, "choice_id", "take_poppy") == null, "hidden drug must be located before taking")
		await mouse_click(find_action(main.dialogue_panel, "choice_id", "search_cabinet"))
		check(runtime.snapshot().flags.get("cabinet_searched", false) and not runtime.snapshot().flags.get("poppy_held", false), "search discovers stash without taking it")
		await screenshot("14_hidden_packet")
		await mouse_click(find_action(main.dialogue_panel, "choice_id", "take_poppy"))
		check(runtime.snapshot().flags.get("poppy_held", false) and runtime.snapshot().selected_outcome == null, "mouse takes packet without automatic delivery")
		await mouse_click(find_action(main.dialogue_panel, "choice_id", "leave"))
		check(not main.player.locked and main.task_line.text.contains("随身携带"), "carried packet is visible in HUD and world stays playable")
		if refused:
			await screenshot("12_packet_held")
			await mouse_click(main.save_button)
			await mouse_click(find_button(main.get_node("UI/HUD"), "重置"))
			await mouse_click(main.load_button)
			check(runtime.snapshot().flags.get("poppy_held", false) and runtime.snapshot().flags.get("refused_help", false), "GUI save/reset/load preserves refusal and held packet")
		await move_to(660)
		check(main.player.current_target == "npc_a", "walk back from cupboard to Rodrigo")
		await tap(KEY_E)
		var handover = find_action(main.dialogue_panel, "choice_id", "hand_over")
		check(handover != null and not handover.disabled, "handover selectable regardless of opening or failed check")
		await mouse_click(handover)
		check(runtime.snapshot().flags.get("poppy_delivered", false) and not runtime.snapshot().flags.poppy_held, "mouse hands packet over and clears possession")
		check(runtime.snapshot().selected_outcome == null, "delivery shows recipient reply before goodbye")
		if refused:
			check(main.runner.current_view().text.contains("不是说不帮我"), "visible reaction to initial refusal followed by delivery")
			await screenshot("13_refused_then_delivered")
		await mouse_click(find_action(main.dialogue_panel, "choice_id", "finish_delivery"))
		check(runtime.snapshot().selected_outcome == "outcome_a" and main.result_panel.visible, "goodbye settles actual delivery")
		if high: await screenshot("04_outcome_a")
		await mouse_click(find_button(main.result_panel, "完整重置"))
		if runtime.snapshot() != main.content.data.initial_state or main.player.locked:
			print("RESET DIAGNOSTIC: locked=%s result=%s state=%s" % [main.player.locked, main.result_panel.visible, JSON.stringify(runtime.snapshot())])
		check(runtime.snapshot() == main.content.data.initial_state and not main.player.locked, "result reset button rebuilds initial world")
	# A promise can instead end without taking or delivering.
	await move_to(260)
	await tap(KEY_E)
	await mouse_click(find_action(main.dialogue_panel, "choice_id", "prepare_fail"))
	await tap(KEY_ESCAPE)
	await move_to(715)
	await tap(KEY_E)
	await move_to(1090)
	await tap(KEY_E)
	await move_to(660)
	await tap(KEY_E)
	await mouse_click(find_action(main.dialogue_panel, "choice_id", "end_request"))
	check(runtime.snapshot().selected_outcome == null, "final refusal has an opportunity to reconsider")
	await mouse_click(find_action(main.dialogue_panel, "choice_id", "back"))
	check(find_action(main.dialogue_panel, "choice_id", "end_request") != null, "back button returns to conversation")
	await mouse_click(find_action(main.dialogue_panel, "choice_id", "end_request"))
	await mouse_click(find_action(main.dialogue_panel, "choice_id", "finish_refusal"))
	check(runtime.snapshot().selected_outcome == "outcome_b" and not runtime.snapshot().flags.get("poppy_taken", false), "promise can end without taking any packet")
	await screenshot("07_outcome_b")
	await mouse_click(find_button(main.result_panel, "完整重置"))
	await mouse_click(find_button(main.get_node("UI/HUD"), "人物关系"))
	check(main.relationships_panel.visible and main.player.locked, "relationships button opens scrollable cast and locks walking")
	await screenshot("15_relationships")
	await mouse_click(find_button(main.relationships_panel, "Esc"))
	check(not main.relationships_panel.visible and not main.player.locked, "closing relationships returns to world")
	await large_cast_ui()
	await tap(KEY_F3)
	check(main.debug_panel.visible, "F3 opens debug")
	var spin = main.debug_panel.fields["traits:mercy"]
	spin.value = -12
	await mouse_click(find_button(spin.get_parent(), "设定"))
	check(runtime.snapshot().traits.mercy == -12, "debug Apply button commits integer")
	await mouse_click(find_button(main.debug_panel, "保存单槽"))
	spin.value = 47
	await mouse_click(find_button(spin.get_parent(), "设定"))
	await mouse_click(find_button(main.debug_panel, "读取单槽"))
	check(runtime.snapshot().traits.mercy == -12 and not main.debug_panel.visible, "debug save/edit/load buttons restore snapshot")
	await tap(KEY_F3)
	await screenshot("08_debug")
	# Canvas stretch must retain readable panels at the minimum supported window.
	root.size = Vector2i(960, 540)
	await screenshot("09_debug_960x540")
	await tap(KEY_F3)
	await move_to(265)
	await tap(KEY_E)
	await screenshot("10_dialogue_960x540")
	await tap(KEY_F3)
	check(main.debug_panel.lock_reason.text == "请先结束对话", "debug save/load/phase controls visibly locked during dialogue")
	await mouse_click(find_button(main.debug_panel, "完整重置"))
	check(runtime.snapshot() == main.content.data.initial_state and not main.runner.active and not main.debug_panel.visible, "reset from debug cancels dialogue")
	var test_path = ProjectSettings.globalize_path(main.saves.path)
	DirAccess.remove_absolute(test_path)
	if count < 100: check(false, "graphical suite aborted early")
	print("GUI TOTAL: %d assertions / %d failures" % [count, failures])
	main.queue_free()
	await frames(2)
	quit(0 if failures == 0 else 1)

func large_cast_ui() -> void:
	var fixture = preload("res://scripts/content_db.gd").new()
	check(fixture.load_content().ok, "load large-cast UI fixture")
	for i in range(24):
		fixture.data.characters["fixture_%02d" % i] = {"kind":"npc", "label":"测试人物 %02d" % i, "initial_affinity":i, "dialogue_id":"dialogue_a", "portrait":""}
	fixture.assemble_characters()
	var panel = preload("res://scripts/ui/relationships_panel.gd").new()
	main.get_node("UI").add_child(panel)
	panel.theme = main.relationships_panel.theme
	panel.setup(fixture)
	panel.refresh(fixture.data.initial_state)
	panel.show()
	await frames(8)
	var scroll = panel.rows.fixture_23.get_parent().get_parent() as ScrollContainer
	for i in range(5):
		var event = InputEventMouseButton.new()
		event.position = scroll.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_WHEEL_DOWN
		event.pressed = true
		root.push_input(event, true)
		await frames(2)
	check(panel.rows.size() == 26 and scroll.scroll_vertical > 0, "26 characters fit scrollable list; mouse wheel scrolls")
	await screenshot("16_relationships_26")
	panel.search.grab_focus()
	for character in "fixture_23":
		var event = InputEventKey.new()
		event.unicode = character.unicode_at(0)
		event.pressed = true
		root.push_input(event, true)
	await frames(6)
	check(panel.rows.values().filter(func(row): return row.visible).size() == 1 and panel.rows.fixture_23.visible, "typing into cast search finds one of 26 characters")
	await screenshot("17_relationships_search")
	panel.queue_free()
	await frames()
