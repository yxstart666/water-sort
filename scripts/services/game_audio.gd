class_name GameAudio
extends Node
## Presentation-only audio. Keep one instance owned by main, not per view.
## Async callbacks must capture get_epoch() and pass it as play_event's third arg.

const MUSIC = preload("res://art/reference2-delivery-20261024/music_sunlit_steps_v1/caiping_sunlit_steps_112bpm.ogg")
const EFFECTS := {
	"click": preload("res://assets/audio/click.wav"),
	"pickup": preload("res://assets/audio/pickup.wav"),
	"deposit": preload("res://assets/audio/deposit.wav"),
	"crate_complete": preload("res://assets/audio/crate_complete.wav"),
	"victory": preload("res://assets/audio/victory.wav"),
	"ui_error": preload("res://assets/audio/ui_error.wav"),
}
const VOICE_LIMIT := 6
const MUSIC_DB := -3.0
const SFX_DB := -8.0
var music_enabled := true
var sfx_enabled := true
var gameplay_paused := false
var application_active := true
var _application_suspended := false
var _application_focused := true
var _epoch := 0
var _seen: Dictionary = {}
var _music: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _music_position := 0.0
var _voice_cursor := 0
var played_events := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new()
	_music.name = "QuietMusic"
	var loop: AudioStreamOggVorbis = MUSIC.duplicate()
	loop.loop=true
	loop.loop_offset=0.0
	loop.bpm=112
	_music.stream = loop
	_music.volume_db = MUSIC_DB
	add_child(_music)
	for i in range(VOICE_LIMIT):
		var player := AudioStreamPlayer.new()
		player.name = "Effect%d" % i
		player.volume_db = SFX_DB
		add_child(player)
		_voices.append(player)
	_sync_music()

func set_preferences(enable_music: bool, enable_sfx: bool) -> void:
	music_enabled = enable_music
	sfx_enabled = enable_sfx
	if not sfx_enabled:
		_stop_effects()
	_sync_music()

func set_gameplay_paused(paused: bool) -> void:
	gameplay_paused = paused
	if paused:
		# Stop existing gameplay voices too; UI confirmation can then play normally.
		_stop_effects()

func get_epoch() -> int:
	return _epoch

func reset_epoch() -> int:
	_epoch += 1
	_seen.clear()
	_stop_effects()
	return _epoch

func play_event(kind: String, event_id: Variant, source_epoch: int = -1) -> bool:
	if not EFFECTS.has(kind) or event_id == null or str(event_id).is_empty():
		return false
	if source_epoch != -1 and source_epoch != _epoch:
		return false
	# Consume muted/paused events as well: enabling audio must not replay history.
	var key := str(event_id)
	if _seen.has(key):
		return false
	_seen[key] = true
	var is_ui := kind == "click" or kind == "ui_error"
	if not sfx_enabled or not application_active or _voices.is_empty():
		return false
	if (gameplay_paused or get_tree().paused) and not is_ui:
		return false
	var voice := _voices[_voice_cursor]
	_voice_cursor = (_voice_cursor + 1) % VOICE_LIMIT
	voice.stop()
	voice.stream = EFFECTS[kind]
	voice.play()
	played_events += 1
	return true

func set_application_active(active: bool) -> void:
	application_active = active
	if not active:
		_stop_effects()
	_sync_music()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_application_suspended = true
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_application_suspended = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_application_focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_application_focused = true
	else:
		return
	set_application_active(not _application_suspended and _application_focused)

func _sync_music() -> void:
	if not is_instance_valid(_music):
		return
	if music_enabled and application_active:
		if not _music.playing:
			_music.play(_music_position)
	elif _music.playing:
		_music_position = fmod(_music.get_playback_position(), _music.stream.get_length())
		_music.stop()

func _stop_effects() -> void:
	for voice in _voices:
		voice.stop()

func get_audio_state() -> Dictionary:
	return {"epoch": _epoch, "music_enabled": music_enabled, "sfx_enabled": sfx_enabled,
		"music_playing": is_instance_valid(_music) and _music.playing,
		"music_position": _music.get_playback_position() if is_instance_valid(_music) and _music.playing else _music_position,
		"active_voices": _voices.filter(func(v): return v.playing).size(),
		"played_events": played_events, "seen_events": _seen.size(), "application_active": application_active}
