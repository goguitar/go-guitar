extends Node

class_name GoGuitarAPI

var _audio_mixer: AudioMixer
var _dlc_loader: DlcLoader
var _current_song: Dictionary = {}
var _is_loaded: bool = false

func _ready() -> void:
	_audio_mixer = AudioMixer.new()
	_dlc_loader = DlcLoader.new()
	_is_loaded = true
	print("Go-Guitar API initialized")

func load_dlc(path: String) -> Dictionary:
	var result = _dlc_loader.load_dlc(path)
	if result:
		_current_song = {
			"title": result.title,
			"artist": result.artist,
			"arrangements": result.arrangements.size(),
			"audio_files": result.audio_files.size()
		}
		return _current_song
	return {}

func list_arrangements() -> Array:
	var result = []
	for arr in _current_song.get("arrangements", []):
		result.append({
			"name": arr.name,
			"type": arr.arrangement_type
		})
	return result

func get_audio_mixer() -> AudioMixer:
	return _audio_mixer

func get_dlc_loader() -> DlcLoader:
	return _dlc_loader

func is_ready() -> bool:
	return _is_loaded
