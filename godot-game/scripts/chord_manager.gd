extends Node3D

const STRING_COLORS: Array[Color] = [
	Color(0.98, 0.26, 0.22, 1.0),
	Color(0.98, 0.78, 0.16, 1.0),
	Color(0.20, 0.80, 0.95, 1.0),
	Color(1.00, 0.55, 0.10, 1.0),
	Color(0.20, 0.88, 0.30, 1.0),
	Color(0.72, 0.38, 0.98, 1.0),
]

const POOL_SIZE : int = 20
const SPAWN_Z : float = -30.0
const STRIKE_Z : float = 0.0
const TRAVEL_SPEED : float = 8.0
const MISS_HOLD : float = 1.0
const BORDER_FRET_SPAN : int = 4

var _chord_pool: Array[Node3D] = []
var _active_chords: Array = []
var game_controller: Node3D

const FRET_COUNT : int = 24
const SCALE_LENGTH : float = 300.0
const FRET_WORLD_WIDTH : float = 25.0
const STRING_SLOT_HEIGHT : float = 1.2

func _ready() -> void:
	_create_chord_pool()

func _create_chord_pool() -> void:
	for i in range(POOL_SIZE):
		var chord := _create_chord_node()
		chord.visible = false
		add_child(chord)
		_chord_pool.append(chord)

func _create_chord_node() -> Node3D:
	var chord_root := Node3D.new()
	chord_root.name = "Chord"
	
	var frame := Node3D.new()
	frame.name = "Frame"
	chord_root.add_child(frame)
	
	var label := Label3D.new()
	label.name = "Label"
	label.font_size = 64
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(-2, 1, 0.1)
	chord_root.add_child(label)
	
	return chord_root

func spawn_chord(notes: Array, time: float, chord_name: String = "") -> Node3D:
	var chord := _get_pooled_chord()
	if chord == null:
		return null
	
	chord.visible = true
	chord.set_meta("time", time)
	chord.set_meta("hit", false)
	chord.set_meta("miss_time", -1.0)
	chord.set_meta("notes", notes)
	
	var min_fret := 999
	var max_fret := -1
	for note_data in notes:
		var f: int = note_data.get("fret", 0)
		if f < min_fret: min_fret = f
		if f > max_fret: max_fret = f
	
	if min_fret == 999:
		min_fret = 1
	if max_fret < min_fret:
		max_fret = min_fret
	
	var left_x: float = _fret_separator_world_x(min_fret - 1)
	var right_x: float = _fret_separator_world_x(min_fret + BORDER_FRET_SPAN - 1)
	var center_x: float = (left_x + right_x) * 0.5
	var top_y: float = _string_world_y(0)
	var bottom_y: float = _string_world_y(5) - STRING_SLOT_HEIGHT
	var center_y: float = (top_y + bottom_y) * 0.5
	
	chord.position = Vector3(center_x, center_y, SPAWN_Z)
	
	var frame := chord.get_node("Frame") as Node3D
	if frame:
		for child in frame.get_children():
			child.queue_free()
	
	var box_width := right_x - left_x
	var box_height := absf(top_y - bottom_y)
	var thickness := 0.025
	
	var top := _create_frame_segment(box_width, thickness, 0.02)
	top.position = Vector3(0, box_height * 0.5, 0)
	frame.add_child(top)
	
	var bottom := _create_frame_segment(box_width, thickness, 0.02)
	bottom.position = Vector3(0, -box_height * 0.5, 0)
	frame.add_child(bottom)
	
	var left := _create_frame_segment(thickness, box_height, 0.02)
	left.position = Vector3(-box_width * 0.5, 0, 0)
	frame.add_child(left)
	
	var right_seg := _create_frame_segment(thickness, box_height, 0.02)
	right_seg.position = Vector3(box_width * 0.5, 0, 0)
	frame.add_child(right_seg)
	
	for note_data in notes:
		var f: int = note_data.get("fret", 0)
		var s: int = note_data.get("string", 0)
		var x: float = _fret_mid_world_x(f - 1) - center_x
		var y: float = _string_world_y(s) - center_y
		
		var indicator := _create_note_indicator(f, s)
		indicator.position = Vector3(x, y, 0.06)
		frame.add_child(indicator)
	
	var label := chord.get_node("Label") as Label3D
	if label:
		label.text = chord_name
		label.visible = chord_name != ""
	
	_active_chords.append(chord)
	return chord

func _create_frame_segment(w: float, h: float, d: float) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(w, h, d)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.95, 1.0, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.95, 1.0, 1.0)
	mat.emission_energy_multiplier = 1.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.set_surface_override_material(0, mat)
	return mesh

func _create_note_indicator(fret: int, string_idx: int) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var size: Vector2 = _note_indicator_size(fret)
	var box := BoxMesh.new()
	box.size = Vector3(size.x, size.y, 0.1)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = STRING_COLORS[string_idx]
	mat.emission_enabled = true
	mat.emission = STRING_COLORS[string_idx]
	mat.emission_energy_multiplier = 1.0
	mesh.set_surface_override_material(0, mat)
	return mesh

func _get_pooled_chord() -> Node3D:
	for chord in _chord_pool:
		if not chord.visible:
			return chord
	return null

func _process(delta: float) -> void:
	var song_time := 0.0
	if game_controller and game_controller.has_method("get_song_time"):
		song_time = game_controller.get_song_time()
	
	var chords_to_remove: Array = []
	
	for chord in _active_chords:
		var chord_time: float = chord.get_meta("time", 0.0)
		var z := STRIKE_Z - (chord_time - song_time) * TRAVEL_SPEED
		chord.position.z = z
		
		var hit: bool = chord.get_meta("hit", false)
		var miss_time: float = chord.get_meta("miss_time", -1.0)
		
		if not hit and z <= STRIKE_Z:
			chord.set_meta("miss_time", song_time)
			if game_controller and game_controller.has_method("chord_missed"):
				game_controller.chord_missed()
		
		if miss_time >= 0.0 and (song_time - miss_time) > MISS_HOLD:
			chords_to_remove.append(chord)
		
		if hit:
			var hit_start: float = chord.get_meta("hit_time", song_time)
			var t := song_time - hit_start
			if t > 0.3:
				chords_to_remove.append(chord)
	
	for chord in chords_to_remove:
		_return_chord(chord)

func hit_chord(chord: Node3D) -> void:
	chord.set_meta("hit", true)
	chord.set_meta("hit_time", 0.0)
	if game_controller and game_controller.has_method("get_song_time"):
		chord.set_meta("hit_time", game_controller.get_song_time())

func _return_chord(chord: Node3D) -> void:
	var idx := _active_chords.find(chord)
	if idx >= 0:
		_active_chords.remove_at(idx)
	chord.visible = false
	chord.set_meta("hit", false)
	chord.set_meta("miss_time", -1.0)
	
	var frame := chord.get_node("Frame") as Node3D
	if frame:
		for child in frame.get_children():
			child.queue_free()

static func chart_fret_pos(fret_num: float) -> float:
	return SCALE_LENGTH - (SCALE_LENGTH / pow(2.0, fret_num / 12.0))

func _fret_separator_world_x(fret_num: int) -> float:
	var max_pos: float = chart_fret_pos(float(FRET_COUNT))
	if max_pos <= 0.001:
		return 0.0
	return chart_fret_pos(float(fret_num)) / max_pos * FRET_WORLD_WIDTH

func _fret_mid_world_x(fret_num: int) -> float:
	var max_pos: float = chart_fret_pos(float(FRET_COUNT))
	if max_pos <= 0.001:
		return 0.0
	var curr := chart_fret_pos(float(fret_num))
	var nxt := chart_fret_pos(float(fret_num) + 1.0)
	return (curr + nxt) * 0.5 / max_pos * FRET_WORLD_WIDTH

func _string_world_y(str_idx: int) -> float:
	return (3.0 + float(5 - str_idx) * 4.0)

func _note_indicator_size(fret_num: int) -> Vector2:
	var max_pos: float = chart_fret_pos(float(FRET_COUNT))
	if max_pos <= 0.001:
		return Vector2(1.0, 0.8)
	var curr := chart_fret_pos(float(fret_num))
	var nxt := chart_fret_pos(float(fret_num) + 1.0)
	var w := (nxt - curr) / max_pos * FRET_WORLD_WIDTH
	var h := STRING_SLOT_HEIGHT * 0.8
	return Vector2(maxf(w, 0.3), maxf(h, 0.6))