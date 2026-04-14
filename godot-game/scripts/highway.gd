extends Node3D

const FRET_COUNT : int = 24
const STRING_COUNT : int = 6
const SCALE_LENGTH : float = 300.0

const STRING_COLORS: Array[Color] = [
	Color(0.98, 0.26, 0.22, 1.0), # red
	Color(0.98, 0.78, 0.16, 1.0), # yellow
	Color(0.20, 0.80, 0.95, 1.0), # cyan
	Color(1.00, 0.55, 0.10, 1.0), # orange
	Color(0.20, 0.88, 0.30, 1.0), # green
	Color(0.72, 0.38, 0.98, 1.0), # purple
]

const FRET_WORLD_WIDTH : float = 25.0
const STRING_SLOT_HEIGHT : float = 1.2
const STRING_HEIGHT_SCALE : float = 1.0

@onready var _surface: MeshInstance3D = $HighwaySurface
@onready var _fretboard: Node3D = $Fretboard
@onready var _strings: Node3D = $Strings

var _fret_markers: Array[MeshInstance3D] = []
var _string_meshes: Array[MeshInstance3D] = []
var _lane_intensities: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _active_fret_min: int = 0
var _active_fret_max: int = -1

func _ready() -> void:
	_create_fretboard()
	_create_strings()
	set_lane_intensities(_lane_intensities)

static func chart_fret_pos(fret_num: float) -> float:
	return SCALE_LENGTH - (SCALE_LENGTH / pow(2.0, fret_num / 12.0))

static func fret_separator_world_x(fret_num: int) -> float:
	var max_pos: float = chart_fret_pos(float(FRET_COUNT))
	if max_pos <= 0.001:
		return 0.0
	return chart_fret_pos(float(fret_num)) / max_pos * FRET_WORLD_WIDTH

static func fret_mid_world_x(fret_num: int) -> float:
	var max_pos: float = chart_fret_pos(float(FRET_COUNT))
	if max_pos <= 0.001:
		return 0.0
	var curr := chart_fret_pos(float(fret_num))
	var nxt := chart_fret_pos(float(fret_num) + 1.0)
	return (curr + nxt) * 0.5 / max_pos * FRET_WORLD_WIDTH

static func string_world_y(str_idx: int) -> float:
	return (3.0 + float(5 - str_idx) * 4.0) * STRING_HEIGHT_SCALE

static func note_indicator_size(fret_num: int) -> Vector2:
	var max_pos: float = chart_fret_pos(float(FRET_COUNT))
	if max_pos <= 0.001:
		return Vector2(1.0, 0.8)
	var curr := chart_fret_pos(float(fret_num))
	var nxt := chart_fret_pos(float(fret_num) + 1.0)
	var w := (nxt - curr) / max_pos * FRET_WORLD_WIDTH
	var h := STRING_SLOT_HEIGHT * 0.8
	return Vector2(maxf(w, 0.3), maxf(h, 0.6))

func _create_fretboard() -> void:
	var fretboard := CSGBox3D.new()
	fretboard.name = "Fretboard"
	fretboard.size = Vector3(FRET_WORLD_WIDTH + 2, 0.1, 100)
	fretboard.position = Vector3(FRET_WORLD_WIDTH * 0.5, -0.05, 50)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.05, 0.03)
	mat.roughness = 0.9
	fretboard.material = mat
	add_child(fretboard)
	
	var nut := CSGBox3D.new()
	nut.name = "Nut"
	nut.size = Vector3(0.08, 0.15, 8)
	nut.position = Vector3(-0.04, 0.05, 4)
	var nut_mat := StandardMaterial3D.new()
	nut_mat.albedo_color = Color(0.15, 0.12, 0.1)
	nut_mat.metallic = 0.2
	nut.material = nut_mat
	add_child(nut)
	
	for fret in range(1, FRET_COUNT + 1):
		var fret_x := fret_separator_world_x(fret)
		var wire := CSGBox3D.new()
		wire.name = "FretWire_%d" % fret
		wire.size = Vector3(0.03, 0.08, 100)
		wire.position = Vector3(fret_x, 0.04, 50)
		var wire_mat := StandardMaterial3D.new()
		var is_inlay := (fret == 3 or fret == 5 or fret == 7 or fret == 9 or 
		                  fret == 12 or fret == 15 or fret == 17 or fret == 19 or fret == 21)
		if is_inlay:
			wire_mat.albedo_color = Color(0.4, 0.4, 0.5)
		else:
			wire_mat.albedo_color = Color(0.22, 0.23, 0.27)
		wire_mat.metallic = 0.3
		wire.material = wire_mat
		add_child(wire)
		_fret_markers.append(wire)

func _create_strings() -> void:
	for str_idx in range(STRING_COUNT):
		var str_y := string_world_y(str_idx)
		var str := CSGBox3D.new()
		str.name = "String_%d" % str_idx
		str.size = Vector3(FRET_WORLD_WIDTH + 2, 0.015, 0.015)
		str.position = Vector3(FRET_WORLD_WIDTH * 0.5, str_y, 4)
		var str_mat := StandardMaterial3D.new()
		str_mat.albedo_color = STRING_COLORS[str_idx]
		str_mat.metallic = 0.8
		str_mat.roughness = 0.3
		str.material = str_mat
		add_child(str)
		_string_meshes.append(str)

func set_lane_intensities(values: Array[float]) -> void:
	_lane_intensities = values
	for i in range(mini(values.size(), STRING_COUNT)):
		var str_mesh = _string_meshes[i] if i < _string_meshes.size() else null
		if str_mesh and str_mesh is CSGBox3D:
			var base_color := STRING_COLORS[i]
			var intensity := clampf(values[i], 0.0, 1.0)
			if intensity > 0.1:
				var mat := StandardMaterial3D.new()
				mat.albedo_color = base_color
				mat.emission_enabled = true
				mat.emission = base_color
				mat.emission_energy_multiplier = intensity * 1.5
				str_mesh.material = mat
			else:
				var mat := StandardMaterial3D.new()
				mat.albedo_color = base_color.darkened(0.7)
				mat.metallic = 0.8
				mat.roughness = 0.3
				str_mesh.material = mat

func set_active_fret_range(min_fret: int, max_fret: int) -> void:
	_active_fret_min = min_fret
	_active_fret_max = max_fret
	
	for i in range(_fret_markers.size()):
		var fret := i + 1
		var marker = _fret_markers[i] if i < _fret_markers.size() else null
		if marker and marker is CSGBox3D:
			var is_active := (fret >= min_fret and fret <= max_fret)
			var mat := StandardMaterial3D.new()
			if is_active:
				mat.albedo_color = Color(0.5, 0.55, 0.6)
				mat.emission_enabled = true
				mat.emission = Color(0.3, 0.35, 0.4)
				mat.emission_energy_multiplier = 0.5
			else:
				var is_inlay := (fret == 3 or fret == 5 or fret == 7 or fret == 9 or 
				                  fret == 12 or fret == 15 or fret == 17 or fret == 19 or fret == 21)
				if is_inlay:
					mat.albedo_color = Color(0.4, 0.4, 0.5)
				else:
					mat.albedo_color = Color(0.22, 0.23, 0.27)
			marker.material = mat
