extends Node3D

const FRET_COUNT : int = 24
const STRING_COUNT : int = 6
const LANE_COUNT : int = 6

var song_time := 0.0
var is_playing := false
var song_duration := 60.0

var score := 0
var combo := 0
var max_combo := 0
var notes_hit := 0
var notes_missed := 0

var highway: Node3D
var note_manager: Node3D
var chord_manager: Node3D
var ui: CanvasLayer

var _song_notes: Array = []
var _next_note_idx: int = 0
var _next_chord_idx: int = 0
var _song_chords: Array = []

func _ready() -> void:
	highway = get_parent().get_node("Highway")
	note_manager = get_parent().get_node("NoteManager")
	chord_manager = get_parent().get_node("ChordManager")
	ui = get_parent().get_node("UIController")
	
	note_manager.game_controller = self
	chord_manager.game_controller = self
	
	_generate_demo_song()
	start_song()

func _process(delta: float) -> void:
	if is_playing:
		song_time += delta
		_update_notes()
		_update_chords()
		_update_highway()
		_check_song_end()
		
		if ui and ui.has_method("update_score"):
			ui.update_score(score, combo, max_combo, notes_hit, notes_missed)

func _update_notes() -> void:
	while _next_note_idx < _song_notes.size():
		var note_data: Dictionary = _song_notes[_next_note_idx]
		var note_time: float = note_data.get("time", 0.0)
		
		if note_time <= song_time + 3.0:
			note_manager.spawn_note(
				note_data.get("fret", 1),
				note_data.get("string", 0),
				note_time,
				note_data.get("duration", 0.25)
			)
			_next_note_idx += 1
		else:
			break

func _update_chords() -> void:
	while _next_chord_idx < _song_chords.size():
		var chord_data: Dictionary = _song_chords[_next_chord_idx]
		var chord_time: float = chord_data.get("time", 0.0)
		
		if chord_time <= song_time + 3.0:
			chord_manager.spawn_chord(
				chord_data.get("notes", []),
				chord_time,
				chord_data.get("name", "")
			)
			_next_chord_idx += 1
		else:
			break

func _update_highway() -> void:
	var next_note_fret := _get_next_note_fret()
	if next_note_fret >= 1:
		var min_fret := next_note_fret - 1
		var max_fret := next_note_fret + 3
		highway.set_active_fret_range(min_fret, maxi(min_fret, max_fret))
		
		var lane_targets: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		for note_data in _song_notes:
			var note_time: float = note_data.get("time", 0.0)
			if note_time > song_time and note_time < song_time + 2.0:
				var note_fret: int = note_data.get("fret", 0)
				var note_string: int = note_data.get("string", 0)
				if note_fret >= min_fret and note_fret <= max_fret:
					lane_targets[note_string] = 1.0
		highway.set_lane_intensities(lane_targets)
	else:
		highway.set_active_fret_range(0, -1)
		highway.set_lane_intensities([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])

func _get_next_note_fret() -> int:
	for i in range(_next_note_idx, _song_notes.size()):
		var note_data: Dictionary = _song_notes[i]
		var note_time: float = note_data.get("time", 0.0)
		if note_time > song_time:
			return note_data.get("fret", 1)
	return 1

func _check_song_end() -> void:
	if song_time >= song_duration:
		stop_song()

func _generate_demo_song() -> void:
	_song_notes.clear()
	_song_chords.clear()
	
	var beat := 0.5
	var time := 2.0
	
	var patterns: Array = [
		[[0, 0], [1, 1], [2, 2], [3, 3]],
		[[2, 0], [3, 1], [4, 2], [5, 3]],
		[[0, 0], [2, 1], [4, 2], [5, 3]],
		[[1, 0], [3, 1], [4, 2], [2, 3]],
	]
	
	for i in range(80):
		var pattern: Array = patterns[i % patterns.size()]
		for note_data in pattern:
			var fret: int = note_data[0]
			var string_idx: int = note_data[1]
			_song_notes.append({
				"fret": fret,
				"string": string_idx,
				"time": time,
				"duration": 0.25
			})
		time += beat
	
	song_duration = time + 5.0

func get_song_time() -> float:
	return song_time

func note_missed() -> void:
	notes_missed += 1
	combo = 0

func chord_missed() -> void:
	notes_missed += 1
	combo = 0

func note_hit() -> void:
	notes_hit += 1
	combo += 1
	max_combo = maxi(max_combo, combo)
	score += 100 * (1 + combo / 10)

func start_song() -> void:
	is_playing = true
	song_time = 0.0
	_next_note_idx = 0
	_next_chord_idx = 0
	score = 0
	combo = 0
	max_combo = 0
	notes_hit = 0
	notes_missed = 0

func stop_song() -> void:
	is_playing = false

func toggle_play() -> void:
	if is_playing:
		stop_song()
	else:
		start_song()