extends SceneTree
const Effect = preload("res://scripts/water_sort/art/level_complete_effect.gd")
var checks := 0
var failures: Array[String] = []
var events: Array = []
var effect: Control

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func begin(key: String, seed_value := Effect.DEFAULT_SEED) -> bool:
	var accepted: bool = effect.play_once(key, seed_value)
	effect.set_process(false)
	return accepted

func run() -> void:
	root.size = Vector2i(1080, 1920)
	effect = Effect.new()
	effect.size = Vector2(1080, 1920)
	root.add_child(effect)
	effect.presentation_ready.connect(func(key: String): events.append(["ready", key]))
	effect.finished.connect(func(key: String, cancelled: bool): events.append(["finished", key, cancelled]))
	verify(not effect.busy and not effect.visible and not effect.is_processing(), "fresh effect is invisible and has no idle process")
	verify(effect.mouse_filter == Control.MOUSE_FILTER_IGNORE and effect.focus_mode == Control.FOCUS_NONE, "effect cannot intercept pointer or keyboard focus")
	verify(Effect.PRESENTATION_DELAY >= 0.35 and Effect.PRESENTATION_DELAY <= 0.5 and Effect.DURATION <= 1.2, "short presentation and tail budgets")
	verify(not begin(""), "empty attempt keys are rejected")
	verify(begin("normal"), "first completed attempt starts")
	verify(not begin("normal") and not begin("other-while-busy"), "busy effect rejects duplicate and concurrent requests")
	verify(effect.visible and effect.busy, "accepted effect becomes visible")
	effect.advance(0.419)
	verify(events.is_empty(), "result does not appear before presentation delay")
	effect.advance(0.0011)
	verify(events == [["ready", "normal"]] and effect.busy, "presentation releases exactly once while tail continues")
	effect.advance(0.11)
	verify(events.size() == 1, "further tail updates cannot repeat ready callback")
	effect.advance(5.0)
	verify(events == [["ready", "normal"], ["finished", "normal", false]], "oversize final frame ends one ready and one finish")
	verify(not effect.busy and not effect.visible and not effect.is_processing() and effect._particles.is_empty(), "tail frees particles and automatic processing")
	verify(not begin("normal"), "same attempt cannot replay after finishing")
	verify(not effect.skip() and not effect.cancel(), "repeated terminal operations are no-ops")
	events.clear()
	verify(begin("paused"), "independent attempt starts")
	effect.advance(0.17)
	var before: Array = effect.sample_particles(effect.elapsed)
	effect.set_paused(true)
	effect.advance(2.0)
	verify(is_equal_approx(effect.elapsed, 0.17) and effect.sample_particles(effect.elapsed) == before and events.is_empty(), "pause freezes time and exact particle samples")
	verify(not effect.is_processing(), "paused effect has no persistent process")
	effect.set_paused(false)
	verify(effect.is_processing(), "resume reinstates automatic processing")
	effect.set_process(false)
	effect.advance(0.25)
	verify(events == [["ready", "paused"]], "resumed effect continues same ready threshold")
	effect.cancel()
	verify(events == [["ready", "paused"], ["finished", "paused", true]], "cancel after ready adds no duplicate presentation")
	events.clear()
	verify(begin("skip-before"), "skip fixture starts")
	effect.advance(0.06)
	verify(effect.skip(), "user may skip before result threshold")
	verify(events == [["ready", "skip-before"], ["finished", "skip-before", false]], "skip never loses readiness or emits it twice")
	effect.advance(9.0); effect.skip(); effect.cancel()
	verify(events.size() == 2 and not effect.is_processing(), "skip leaves no delayed callback or background process")
	events.clear()
	begin("skip-after"); effect.advance(0.5); effect.skip()
	verify(events == [["ready", "skip-after"], ["finished", "skip-after", false]], "skip after readiness also emits one ready only")
	events.clear()
	begin("leave"); effect.advance(0.10); effect.cancel(); effect.advance(5.0)
	verify(events == [["finished", "leave", true]], "owner navigation cancels without stale result callback")
	verify(not begin("leave"), "navigation cannot accidentally replay the old attempt")
	events.clear()
	begin("release-on-cancel"); effect.cancel(true)
	verify(events == [["ready", "release-on-cancel"], ["finished", "release-on-cancel", true]], "explicit release-on-cancel is available without a lost callback")
	events.clear()
	begin("one-large-frame"); effect.advance(12.0)
	verify(events == [["ready", "one-large-frame"], ["finished", "one-large-frame", false]], "single oversize frame preserves signal order and count")
	events.clear()
	begin("invalid-delta")
	for value in [-1.0, 0.0, INF, NAN]: effect.advance(value)
	verify(effect.elapsed == 0.0 and events.is_empty(), "invalid or nonpositive frame deltas do not advance")
	effect.cancel()
	await sampling_tests()
	await reentrant_tests()
	await tree_pause_tests()
	await pointer_tests()
	await demo_tests()
	var result := {"checks": checks, "failures": failures, "passed": failures.is_empty()}
	var result_file := FileAccess.open("res://tests/water_sort_celebration/native_results.json", FileAccess.WRITE)
	if result_file: result_file.store_string(JSON.stringify(result, "\t") + "\n")
	print("WATER_SORT_CELEBRATION ", JSON.stringify(result))
	effect.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func sampling_tests() -> void:
	begin("seed-a", 31415)
	var a: Array = effect.sample_particles(0.24)
	verify(a.size() >= 20 and a.size() <= Effect.PARTICLE_COUNT, "sparse particle count is visible but bounded")
	effect.cancel()
	begin("seed-b", 31415)
	verify(a == effect.sample_particles(0.24), "same seed and sample time reproduce exact particle geometry")
	effect.cancel()
	begin("seed-c", 92653)
	verify(a != effect.sample_particles(0.24), "different seed changes the geometry")
	for dimensions in [Vector2(1080, 1920), Vector2(540, 960), Vector2(320, 568), Vector2(1920, 1080), Vector2(240, 960)]:
		effect.size = dimensions
		var protected := Rect2(effect.protected_rect_normalized.position * dimensions, effect.protected_rect_normalized.size * dimensions)
		for frame in 67:
			for particle in effect.sample_particles(frame / 60.0):
				var radius: float = particle.radius
				verify(not protected.grow(radius * 1.5).has_point(particle.position), "particle bounds stay outside central text at all aspect ratios")
				verify(Rect2(Vector2.ZERO, dimensions).has_point(particle.position), "visible particles remain inside canvas")
	verify(effect.sample_particles(-1.0).is_empty() and effect.sample_particles(Effect.DURATION).is_empty(), "samples outside lifetime contain no particles")
	effect.size = Vector2.ZERO
	verify(effect.sample_particles(0.2).is_empty(), "zero-size canvas is safe")
	effect.size = Vector2(1080, 1920)
	effect.reset()
	verify(not effect.busy and not effect.visible and not effect.is_processing(), "reset immediately clears active visual")
	verify(begin("normal"), "reset explicitly permits a new de-duplication scope")
	effect.cancel()
	await process_frame

func reentrant_tests() -> void:
	events.clear()
	var ready_skip := func(key: String):
		if key == "reentrant-skip": effect.skip()
	effect.presentation_ready.connect(ready_skip)
	begin("reentrant-skip"); effect.advance(0.5); effect.advance(4.0)
	verify(events == [["ready", "reentrant-skip"], ["finished", "reentrant-skip", false]], "ready callback may skip without duplicate terminal signals")
	effect.presentation_ready.disconnect(ready_skip)
	events.clear()
	var ready_replace := func(key: String):
		if key == "old-run":
			effect.cancel()
			effect.play_once("new-run", 6)
			effect.set_process(false)
	effect.presentation_ready.connect(ready_replace)
	begin("old-run"); effect.advance(0.5)
	verify(effect.busy and effect.completion_key == "new-run" and effect.elapsed == 0.0, "reentrant owner replacement retains fresh timeline")
	verify(events == [["ready", "old-run"], ["finished", "old-run", true]], "reentrant replacement closes only its old run")
	effect.advance(0.5); effect.advance(2.0)
	verify(events == [["ready", "old-run"], ["finished", "old-run", true], ["ready", "new-run"], ["finished", "new-run", false]], "replacement receives its own callbacks exactly once")
	effect.presentation_ready.disconnect(ready_replace)
	# An owner can queue_free the page from readiness, including on an oversize frame.
	# Godot locks signal emitters against immediate free(); queue_free is its safe API.
	for delta in [0.5, 5.0]:
		var temporary := Effect.new()
		temporary.size = Vector2(1080, 1920)
		root.add_child(temporary)
		temporary.presentation_ready.connect(func(_key: String): temporary.queue_free())
		temporary.play_once("free-owner")
		temporary.advance(delta)
		verify(temporary.is_queued_for_deletion(), "owner may queue removal from ready callback")
		await process_frame
		verify(not is_instance_valid(temporary), "queued owner removal completes safely")
	await process_frame

func tree_pause_tests() -> void:
	effect.reset()
	events.clear()
	effect.play_once("scene-tree-pause")
	paused = true
	await create_timer(0.06, true).timeout
	verify(effect.elapsed == 0.0 and events.is_empty(), "normal SceneTree pause freezes effect without a separate timer")
	paused = false
	effect.cancel()
	var temporary := Effect.new()
	root.add_child(temporary)
	var freed_events: Array = []
	temporary.presentation_ready.connect(func(key: String): freed_events.append(key))
	temporary.play_once("removed-page")
	temporary.free()
	await create_timer(0.06).timeout
	verify(freed_events.is_empty(), "removing an owner never leaves timer or deferred ready callbacks")

func click(control: Control) -> void:
	await process_frame
	var point := control.get_global_transform_with_canvas() * (control.size * 0.5)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await process_frame

func pointer_tests() -> void:
	var button := Button.new()
	button.position = Vector2(35, 720)
	button.size = Vector2(240, 110)
	root.add_child(button)
	root.move_child(button, 0)
	var clicks := [0]
	button.pressed.connect(func(): clicks[0] += 1)
	begin("pointer-through-effect")
	effect.advance(0.2)
	await click(button)
	verify(clicks[0] == 1 and effect.busy, "real viewport click passes through active full-screen effect to underlying button")
	effect.cancel()
	button.free()
	await process_frame

func demo_tests() -> void:
	var demo: Control = load("res://scenes/water_sort/level_complete_demo.tscn").instantiate()
	root.add_child(demo)
	demo.effect.set_process(false)
	verify(demo.bottles.size() == 3 and demo.bottles.all(func(bottle): return bottle.sealed and bottle.cork.visible), "standalone demo reuses three approved full corked bottles")
	verify(not demo.result_panel.visible, "demo starts without a covering result panel")
	demo.effect.advance(0.42)
	verify(demo.result_panel.visible and demo.effect.busy, "demo result becomes available before particle tail ends")
	verify(demo.effect.get_index() < demo.result_panel.get_index(), "effect is rendered below the demo modal")
	await click(demo.result_panel.get_children()[2])
	verify(not demo.result_panel.visible and not demo.effect.busy, "demo Next immediately clears particles and old panel")
	demo.effect.advance(4.0)
	verify(not demo.result_panel.visible, "old Next callback cannot reopen result")
	demo.replay(); demo.effect.set_process(false); demo.effect.advance(0.1); demo.skip_effect()
	verify(demo.result_panel.visible and not demo.effect.busy, "demo skip displays result once with no tail")
	demo.replay(); demo.effect.set_process(false); demo.leave_preview(); demo.effect.advance(4.0)
	verify(not demo.result_panel.visible and not demo.effect.busy, "demo Home suppresses result callback")
	demo.free()
	await process_frame
