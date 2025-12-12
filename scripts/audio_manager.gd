# audio_manager.gd
# Manages all game audio - sound effects and music
# Designed to be gentle and non-anxiety-inducing for young learners

extends Node

# === AUDIO PLAYERS ===

var _sfx_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer = null

const MAX_SFX_PLAYERS: int = 8

# === SOUND EFFECT DEFINITIONS ===
# These will be loaded from files when available
# For now, we generate simple procedural sounds

var _sounds: Dictionary = {}

# === LIFECYCLE ===

func _ready() -> void:
	# Create SFX player pool
	for i in range(MAX_SFX_PLAYERS):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_players.append(player)
	
	# Create music player
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	
	# Generate placeholder sounds
	_generate_placeholder_sounds()


func _generate_placeholder_sounds() -> void:
	"""
	Generate simple procedural sounds as placeholders.
	These can be replaced with actual audio files later.
	"""
	# For now, sounds are just markers - actual audio files would go in assets/audio/
	_sounds = {
		"place": null,      # Pop sound when placing organism
		"eat": null,        # Crunch sound during simulation
		"starve": null,     # Low whistle for dying organism
		"success": null,    # Cheerful sound for healthy ecosystem
		"click": null,      # UI click
		"day_start": null,  # New day sound
		"win": null,        # Victory sound
		"hover": null       # Subtle hover sound
	}


# === PUBLIC API ===

func play_sound(sound_name: String, volume_db: float = 0.0) -> void:
	"""Play a sound effect by name."""
	if not _sounds.has(sound_name):
		push_warning("Unknown sound: " + sound_name)
		return
	
	var sound: AudioStream = _sounds[sound_name]
	if sound == null:
		# Placeholder - no actual sound loaded yet
		return
	
	# Find available player
	for player in _sfx_players:
		if not player.playing:
			player.stream = sound
			player.volume_db = volume_db
			player.play()
			return
	
	# All players busy, use first one
	_sfx_players[0].stream = sound
	_sfx_players[0].volume_db = volume_db
	_sfx_players[0].play()


func play_place_sound() -> void:
	"""Play sound when organism is placed."""
	play_sound("place")


func play_eat_sound() -> void:
	"""Play eating/crunch sound."""
	play_sound("eat")


func play_starve_sound() -> void:
	"""Play gentle sound for organism dying."""
	play_sound("starve")


func play_success_sound() -> void:
	"""Play success/healthy ecosystem sound."""
	play_sound("success")


func play_click_sound() -> void:
	"""Play UI click sound."""
	play_sound("click")


func play_day_start_sound() -> void:
	"""Play new day beginning sound."""
	play_sound("day_start")


func play_win_sound() -> void:
	"""Play victory sound."""
	play_sound("win")


func play_hover_sound() -> void:
	"""Play subtle hover feedback sound."""
	play_sound("hover", -10.0)  # Quieter


func play_music(music_stream: AudioStream, fade_in: float = 1.0) -> void:
	"""Play background music with optional fade in."""
	if music_stream == null:
		return
	
	_music_player.stream = music_stream
	
	if fade_in > 0:
		_music_player.volume_db = -40.0
		_music_player.play()
		var tween: Tween = create_tween()
		tween.tween_property(_music_player, "volume_db", 0.0, fade_in)
	else:
		_music_player.volume_db = 0.0
		_music_player.play()


func stop_music(fade_out: float = 1.0) -> void:
	"""Stop background music with optional fade out."""
	if not _music_player.playing:
		return
	
	if fade_out > 0:
		var tween: Tween = create_tween()
		tween.tween_property(_music_player, "volume_db", -40.0, fade_out)
		tween.tween_callback(_music_player.stop)
	else:
		_music_player.stop()


func set_sfx_volume(volume_linear: float) -> void:
	"""Set SFX volume (0.0 to 1.0)."""
	var db: float = linear_to_db(clamp(volume_linear, 0.0, 1.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), db)


func set_music_volume(volume_linear: float) -> void:
	"""Set music volume (0.0 to 1.0)."""
	var db: float = linear_to_db(clamp(volume_linear, 0.0, 1.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), db)


# === LOAD SOUNDS FROM FILES ===

func load_sound(sound_name: String, file_path: String) -> void:
	"""Load a sound from a file path."""
	if ResourceLoader.exists(file_path):
		var sound: AudioStream = load(file_path)
		_sounds[sound_name] = sound
	else:
		push_warning("Sound file not found: " + file_path)
