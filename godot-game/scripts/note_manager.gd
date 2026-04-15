extends Node3D

const STRING_COLORS: Array[Color] = [
	Color(0.98, 0.26, 0.22, 1.0),
	Color(0.98, 0.78, 0.16, 1.0),
	Color(0.20, 0.80, 0.95, 1.0),
	Color(1.00, 0.55, 0.10, 1.0),
	Color(0.20, 0.88, 0.30, 1.0),
	Color(0.72, 0.38, 0.98, 1.0),
]

const POOL_SIZE : int = 50
const SPAWN_Z : float = -30.0
const STRIKE_Z : float = 0.0
const TRAVEL_SPEED : float = 8.0
const MISS_HOLD : float = 1.0

var _note_pool: Array[Node3D] = []
var _active_notes: Array = []

var game_controller: Node3D
var highway_node: Node3D

const FRET_COUNT : int = 24
const SCALE_LENGTH : float = 300.0
const FRET_WORLD_WIDTH : float = 25.0
const STRING_SLOT_HEIGHT : float = 1.2

func _ready() -> void:
	highway_node = get_parent().get_node("Highway")
	_create_note_pool()

func _create_note_pool() -> void:
	for i in range(POOL_SIZE):
		var note := _create_note_node()
		note.visible = false
		add_child(note)
		_note_pool.append(note)

func _create_note_node() -> Node3D:
	var note_root := Node3D.new()
	note_root.name = "Note"
	
	var finger := MeshInstance3D.new()
	finger.name = "Finger"
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 0.8, 0.15)
	finger.mesh = box
	finger.position = Vector3(0, 0, 0.075)
	note_root.add_child(finger)
	
	var tail := MeshInstance3D.new()
	tail.name = "Tail"
	var tail_box := BoxMesh.new()
	tail_box.size = Vector3(0.1, 0.1, 1.0)
	tail.mesh = tail_box
	tail.position = Vector3(0, 0, 0.5)
	note_root.add_child(tail)
	
	var marker := MeshInstance3D.new()
	marker.name = "Marker"
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	marker.mesh = sphere
	marker.position = Vector3(0, 0, STRIKE_Z)
	note_root.add_child(marker)
	
	var label := Label3D.new()
	label.name = "Label"
	label.font_size = 48
	label.pixel_size = 0.003
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 0, 0.15)
	note_root.add_child(label)
	
	return note_root

func spawn_note(fret: int, string_idx: int, time: float, duration: float = 0.25) -> Node3D:
	var note := _get_pooled_note()
	if note == null:
		return null
	
	note.visible = true
	note.set_meta("fret", fret)
	note.set_meta("string_idx", string_idx)
	note.set_meta("time", time)
	note.set_meta("duration", duration)
	note.set_meta("hit", false)
	note.set_meta("miss_time", -1.0)
	
	var x: float = _fret_mid_world_x(fret - 1)
	var y: float = _string_world_y(string_idx)
	note.position = Vector3(x, y, SPAWN_Z)
	
	var finger := note.get_node("Finger") as MeshInstance3D
	if finger:
		var size: Vector2 = _note_indicator_size(fret)
		var box := finger.mesh as BoxMesh
		if box:
			box.size = Vector3(size.x, size.y, 0.15)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = STRING_COLORS[string_idx]
		mat.emission_enabled = true
		mat.emission = STRING_COLORS[string_idx]
		mat.emission_energy_multiplier = 1.0
		finger.set_surface_override_material(0, mat)
	
	var tail := note.get_node("Tail") as MeshInstance3D
	if tail:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = STRING_COLORS[string_idx]
		mat.emission_enabled = true
		mat.emission = STRING_COLORS[string_idx]
		mat.emission_energy_multiplier = 0.5
		tail.set_surface_override_material(0, mat)
	
	var marker := note.get_node("Marker") as MeshInstance3D
	if marker:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = STRING_COLORS[string_idx]
		mat.emission_enabled = true
		mat.emission = STRING_COLORS[string_idx]
		mat.emission_energy_multiplier = 1.5
		marker.set_surface_override_material(0, mat)
	
	var label := note.get_node("Label") as Label3D
	if label:
		label.text = str(fret)
		label.modulate = Color.WHITE
	
	_active_notes.append(note)
	return note

func _get_pooled_note() -> Node3D:
	for note in _note_pool:
		if not note.visible:
			return note
	return null

func _process(delta: float) -> void:
	var song_time := 0.0
	if game_controller and game_controller.has_method("get_song_time"):
		song_time = game_controller.get_song_time()
	
	var notes_to_remove: Array = []
	
	for note in _active_notes:
		var note_time: float = note.get_meta("time", 0.0)
		var z := STRIKE_Z - (note_time - song_time) * TRAVEL_SPEED
		note.position.z = z
		
		var finger := note.get_node("Finger") as MeshInstance3D
		var tail := note.get_node("Tail") as MeshInstance3D
		
		var hit: bool = note.get_meta("hit", false)
		var miss_time: float = note.get_meta("miss_time", -1.0)
		
		if not hit and z <= STRIKE_Z:
			note.set_meta("miss_time", song_time)
			if game_controller and game_controller.has_method("note_missed"):
				game_controller.note_missed()
		
		if miss_time >= 0.0 and (song_time - miss_time) > MISS_HOLD:
			notes_to_remove.append(note)
		
		if hit:
			var hit_start: float = note.get_meta("hit_time", song_time)
			var t := song_time - hit_start
			if t > 0.3:
				notes_to_remove.append(note)
			elif finger:
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color.WHITE
				mat.emission_enabled = true
				mat.emission = Color.WHITE
				mat.emission_energy_multiplier = 2.5 - t * 8.0
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color.a = maxf(0.0, 1.0 - t * 3.0)
				finger.set_surface_override_material(0, mat)
		
		if tail:
			var tail_length := maxf(0.0, z - STRIKE_Z)
			var tail_box := tail.mesh as BoxMesh
			if tail_box:
				tail_box.size = Vector3(0.1, 0.1, tail_length)
			tail.position.z = STRIKE_Z + tail_length * 0.5
			tail.visible = tail_length > 0.1 and not hit
	
	for note in notes_to_remove:
		_return_note(note)

func hit_note(note: Node3D) -> void:
	note.set_meta("hit", true)
	note.set_meta("hit_time", 0.0)
	if game_controller and game_controller.has_method("get_song_time"):
		note.set_meta("hit_time", game_controller.get_song_time())

func _return_note(note: Node3D) -> void:
	var idx := _active_notes.find(note)
	if idx >= 0:
		_active_notes.remove_at(idx)
	note.visible = false
	note.set_meta("hit", false)
	note.set_meta("miss_time", -1.0)

static func chart_fret_pos(fret_num: float) -> float:
	return SCALE_LENGTH - (SCALE_LENGTH / pow(2.0, fret_num / 12.0))

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