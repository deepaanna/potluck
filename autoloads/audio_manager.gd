## Audio system with pooled SFX players and music crossfade.
## Routes SFX to the SFX bus and music to the Music bus.
extends Node

const SFX_POOL_SIZE: int = 8
const CROSSFADE_DURATION: float = 0.5
const SFX_BUS: StringName = &"SFX"
const MUSIC_BUS: StringName = &"Music"

var _sfx_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _music_player_fade: AudioStreamPlayer
var _current_music_path: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_sfx_pool()
	_create_music_players()
	_apply_saved_settings()


## Play a sound effect from a resource path or AudioStream
func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if stream == null:
		push_warning("AudioManager: Attempted to play null SFX stream")
		return
	if not _is_sfx_enabled():
		return

	var player: AudioStreamPlayer = _get_available_sfx_player()
	if player == null:
		push_warning("AudioManager: All SFX players are busy")
		return

	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


## Play a sound effect with heat-based pitch scaling.
## Pitch = 1.0 + current_heat / 200.0 (e.g. heat 100 → pitch 1.5)
func play_sfx_heated(stream: AudioStream, volume_db: float = 0.0) -> void:
	var heat_pitch: float = 1.0 + GameManager.current_heat / 200.0
	play_sfx(stream, volume_db, heat_pitch)


## Play a sound effect from a file path with heat-based pitch scaling.
func play_sfx_path_heated(path: String, volume_db: float = 0.0) -> void:
	var heat_pitch: float = 1.0 + GameManager.current_heat / 200.0
	play_sfx_path(path, volume_db, heat_pitch)


## Play a sound effect from a file path
func play_sfx_path(path: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		push_error("AudioManager: Failed to load SFX at path: %s" % path)
		return
	play_sfx(stream, volume_db, pitch)


## Play music with optional crossfade
func play_music(stream: AudioStream, volume_db: float = 0.0, crossfade: bool = true) -> void:
	if stream == null:
		push_warning("AudioManager: Attempted to play null music stream")
		return
	if not _is_music_enabled():
		return

	if crossfade and _music_player.playing:
		_crossfade_to(stream, volume_db)
	else:
		_music_player.stream = stream
		_music_player.volume_db = volume_db
		_music_player.play()


## Play music from a file path
func play_music_path(path: String, volume_db: float = 0.0, crossfade: bool = true) -> void:
	if path == _current_music_path and _music_player.playing:
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		push_error("AudioManager: Failed to load music at path: %s" % path)
		return
	_current_music_path = path
	play_music(stream, volume_db, crossfade)


## Stop currently playing music
func stop_music(fade_out: bool = true) -> void:
	_current_music_path = ""
	if fade_out and _music_player.playing:
		var tween: Tween = create_tween()
		tween.tween_property(_music_player, "volume_db", -80.0, CROSSFADE_DURATION)
		tween.tween_callback(_music_player.stop)
	else:
		_music_player.stop()


## Set SFX enabled state and update bus
func set_sfx_enabled(enabled: bool) -> void:
	SaveManager.set_value("settings.sfx_enabled", enabled)
	var bus_index: int = AudioServer.get_bus_index(SFX_BUS)
	if bus_index >= 0:
		AudioServer.set_bus_mute(bus_index, not enabled)


## Set music enabled state and update bus
func set_music_enabled(enabled: bool) -> void:
	SaveManager.set_value("settings.music_enabled", enabled)
	var bus_index: int = AudioServer.get_bus_index(MUSIC_BUS)
	if bus_index >= 0:
		AudioServer.set_bus_mute(bus_index, not enabled)
	if not enabled:
		stop_music(false)


func _is_sfx_enabled() -> bool:
	return SaveManager.get_value("settings.sfx_enabled", true) as bool


func _is_music_enabled() -> bool:
	return SaveManager.get_value("settings.music_enabled", true) as bool


func _create_sfx_pool() -> void:
	for i: int in range(SFX_POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = SFX_BUS
		player.name = "SFXPlayer_%d" % i
		add_child(player)
		_sfx_players.append(player)


func _create_music_players() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	_music_player.name = "MusicPlayer"
	add_child(_music_player)

	_music_player_fade = AudioStreamPlayer.new()
	_music_player_fade.bus = MUSIC_BUS
	_music_player_fade.name = "MusicPlayerFade"
	add_child(_music_player_fade)


func _get_available_sfx_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _sfx_players:
		if not player.playing:
			return player
	return null


func _crossfade_to(stream: AudioStream, volume_db: float) -> void:
	_music_player_fade.stream = _music_player.stream
	_music_player_fade.volume_db = _music_player.volume_db
	_music_player_fade.play(_music_player.get_playback_position())
	_music_player.stop()

	_music_player.stream = stream
	_music_player.volume_db = -80.0
	_music_player.play()

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_music_player, "volume_db", volume_db, CROSSFADE_DURATION)
	tween.tween_property(_music_player_fade, "volume_db", -80.0, CROSSFADE_DURATION)
	tween.set_parallel(false)
	tween.tween_callback(_music_player_fade.stop)


func _apply_saved_settings() -> void:
	var sfx_bus_index: int = AudioServer.get_bus_index(SFX_BUS)
	var music_bus_index: int = AudioServer.get_bus_index(MUSIC_BUS)

	if sfx_bus_index >= 0:
		AudioServer.set_bus_mute(sfx_bus_index, not _is_sfx_enabled())
	if music_bus_index >= 0:
		AudioServer.set_bus_mute(music_bus_index, not _is_music_enabled())
