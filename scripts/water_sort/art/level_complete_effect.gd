extends Control
## Original, view-only level celebration. Add below the result modal, never above it.
## No game rules, progress, rewards, timers, audio, or input handling live here.
signal presentation_ready(completion_key: String)
signal finished(completion_key: String, cancelled: bool)

const PRESENTATION_DELAY := 0.42
const DURATION := 1.10
const DEFAULT_SEED := 741903
const PARTICLE_COUNT := 36
const BottleVisual = preload("res://scripts/water_sort/art/bottle_visual.gd")
const PALETTE := [BottleVisual.DEFAULT_PALETTE.red, BottleVisual.DEFAULT_PALETTE.blue,
	BottleVisual.DEFAULT_PALETTE.yellow, BottleVisual.DEFAULT_PALETTE.green,
	BottleVisual.DEFAULT_PALETTE.purple, BottleVisual.DEFAULT_PALETTE.orange,
	BottleVisual.DEFAULT_PALETTE.pink]

## Normalized text-safe area. Particles touching it are omitted, not drawn over text.
var protected_rect_normalized := Rect2(0.26, 0.27, 0.48, 0.48)
var busy := false
var paused := false
var elapsed := 0.0
var completion_key := ""
var _ready_sent := false
var _generation := 0
var _played_keys: Dictionary = {}
var _particles: Array[Dictionary] = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	visible = false
	set_process(false)

func _ready() -> void:
	# Godot auto-enables _process after _init when a script overrides it.
	set_process(busy and not paused)

## Keys identify a completed attempt, not a level number. Duplicate keys are ignored,
## including after a tail finishes or navigation cancels it. reset() starts a new scope.
## Returns false for a duplicate, empty key, or an already-running effect.
func play_once(key: String, seed_value := DEFAULT_SEED) -> bool:
	if busy or key.is_empty() or _played_keys.has(key):
		return false
	_played_keys[key] = true
	_generation += 1
	completion_key = key
	elapsed = 0.0
	paused = false
	_ready_sent = false
	_particles = _make_particles(seed_value)
	busy = true
	visible = true
	set_process(true)
	queue_redraw()
	return true

func set_paused(value: bool) -> void:
	paused = value if busy else false
	set_process(busy and not paused)

## Owner-driven deterministic clock, if desired. Disable automatic processing when
## using it. An oversize frame still emits ready then finished once, in that order.
func advance(delta: float) -> void:
	if not busy or paused or not is_finite(delta) or delta <= 0.0:
		return
	elapsed = minf(elapsed + delta, DURATION)
	if elapsed >= DURATION:
		_finish(false, true)
		return
	var current_generation := _generation
	if elapsed >= PRESENTATION_DELAY and not _ready_sent:
		_ready_sent = true
		presentation_ready.emit(completion_key)
		# A ready callback may skip, navigate, reset, or start a different run.
		if not is_instance_valid(self) or is_queued_for_deletion() or current_generation != _generation or not busy:
			return
	queue_redraw()

## Reduced-motion/user skip: release presentation exactly once and clear the tail.
func skip() -> bool:
	if not busy:
		return false
	_finish(false, true)
	return true

## Next/Home should use cancel() (no ready callback into a page being discarded).
## cancel(true) is only for an owner that deliberately wants pending presentation.
func cancel(release_presentation := false) -> bool:
	if not busy:
		return false
	_finish(true, release_presentation)
	return true

## Clear the de-duplication scope for a fresh board/attempt owner. Never call this
## on routine HUD refresh, or a repeated win notification could replay the effect.
func reset() -> void:
	_played_keys.clear()
	cancel(false)

func _finish(cancelled: bool, release_presentation: bool) -> void:
	var key := completion_key
	var should_announce := release_presentation and not _ready_sent
	_generation += 1
	busy = false
	paused = false
	visible = false
	_ready_sent = _ready_sent or should_announce
	_particles.clear()
	set_process(false)
	queue_redraw()
	# Terminal state is set before callbacks, so reentrant skips cannot emit twice.
	if should_announce:
		presentation_ready.emit(key)
		if not is_instance_valid(self):
			return
	finished.emit(key, cancelled)

func _process(delta: float) -> void:
	advance(delta)

func _exit_tree() -> void:
	# Destruction is silent. A removed page must not be reopened by a late callback.
	_generation += 1
	busy = false
	paused = false
	visible = false
	_particles.clear()
	set_process(false)

func _make_particles(seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var result: Array[Dictionary] = []
	for index in PARTICLE_COUNT:
		var side := -1.0 if index % 2 == 0 else 1.0
		var start := rng.randf_range(0.0, 0.10)
		result.append({
			"origin": Vector2(rng.randf_range(0.12, 0.23) if side < 0 else rng.randf_range(0.77, 0.88), rng.randf_range(0.37, 0.51)),
			"velocity": Vector2(side * rng.randf_range(35.0, 150.0), rng.randf_range(-370.0, -190.0)),
			"start": start,
			"life": rng.randf_range(0.66, DURATION - start),
			"radius": rng.randf_range(4.0, 8.0),
			"rotation": rng.randf_range(-PI, PI),
			"spin": rng.randf_range(-5.0, 5.0),
			"phase": rng.randf_range(0.0, TAU),
			"star": index % 4 == 0,
			"color": PALETTE[index % PALETTE.size()]
		})
	return result

## Pure sampling for headless contract tests and frame-exact visual review.
## Returned points already exclude the central text-safe area and canvas edges.
func sample_particles(at_seconds: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not busy or not is_finite(at_seconds) or size.x <= 0.0 or size.y <= 0.0:
		return result
	var unit := minf(size.x / 1080.0, size.y / 1920.0)
	var protected := Rect2(protected_rect_normalized.position * size, protected_rect_normalized.size * size)
	for particle in _particles:
		var age := at_seconds - float(particle.start)
		var life := float(particle.life)
		if age <= 0.0 or age >= life:
			continue
		var point: Vector2 = particle.origin * size + particle.velocity * age * unit + Vector2(0.0, 310.0 * age * age * unit)
		point.x += sin(age * 9.0 + float(particle.phase)) * 8.0 * unit
		var radius := float(particle.radius) * unit
		if protected.grow(radius * 1.5).has_point(point) or not Rect2(Vector2.ZERO, size).grow(-radius).has_point(point):
			continue
		var alpha := minf(age / 0.045, 1.0) * minf((life - age) / 0.24, 1.0) * 0.88
		var color: Color = particle.color
		color.a = maxf(alpha, 0.0)
		result.append({"position": point, "radius": radius, "color": color,
			"rotation": float(particle.rotation) + age * float(particle.spin),
			"flutter": 0.48 + absf(cos(age * 8.0 + float(particle.phase))) * 0.52,
			"star": particle.star})
	return result

func _draw() -> void:
	if not busy:
		return
	var unit := minf(size.x / 1080.0, size.y / 1920.0)
	# Two very low-opacity side blooms, never a white/fullscreen flash.
	var bloom := maxf(0.0, 1.0 - elapsed / 0.36)
	if bloom > 0.0:
		for x in [0.17, 0.83]:
			var origin := Vector2(size.x * x, size.y * 0.43)
			for ring in range(4, 0, -1):
				draw_circle(origin, (30.0 + ring * 13.0 + elapsed * 45.0) * unit, Color(0.90, 0.77, 0.45, 0.012 * bloom))
	for particle in sample_particles(elapsed):
		var radius := float(particle.radius)
		draw_set_transform(particle.position, float(particle.rotation), Vector2(float(particle.flutter), 1.0))
		if particle.star:
			var points := PackedVector2Array([
				Vector2(0, -radius * 1.35), Vector2(radius * 0.30, -radius * 0.30),
				Vector2(radius, 0), Vector2(radius * 0.30, radius * 0.30),
				Vector2(0, radius * 1.35), Vector2(-radius * 0.30, radius * 0.30),
				Vector2(-radius, 0), Vector2(-radius * 0.30, -radius * 0.30)])
			draw_colored_polygon(points, particle.color)
		else:
			draw_rect(Rect2(-radius * 0.42, -radius, radius * 0.84, radius * 2.0), particle.color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
