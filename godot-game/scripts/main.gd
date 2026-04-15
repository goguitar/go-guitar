extends Node3D

const NUM_STRINGS := 6
const NUM_FRETS := 24
const STRING_COLORS := [
	Color(0.98, 0.26, 0.22, 1.0),
	Color(0.98, 0.78, 0.16, 1.0),
	Color(0.20, 0.80, 0.95, 1.0),
	Color(1.00, 0.55, 0.10, 1.0),
	Color(0.20, 0.88, 0.30, 1.0),
	Color(0.72, 0.38, 0.98, 1.0),
]

var highway_node: Node3D
var note_manager_node: Node3D
var chord_manager_node: Node3D
var game_controller_node: Node3D
var ui_controller: CanvasLayer
var camera: Camera3D

var current_fret := 0

func _ready() -> void:
	highway_node = $Highway
	note_manager_node = $NoteManager
	chord_manager_node = $ChordManager
	game_controller_node = $GameController
	ui_controller = $UIController
	camera = $Camera3D

func _process(delta: float) -> void:
	handle_input()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("play_pause"):
		game_controller_node.toggle_play()

func handle_input() -> void:
	if Input.is_action_just_pressed("fret_up"):
		current_fret = min(current_fret + 1, NUM_FRETS - 1)
	elif Input.is_action_just_pressed("fret_down"):
		current_fret = max(current_fret - 1, 0)
	
	for i in range(NUM_STRINGS):
		if Input.is_action_just_pressed("note_string_%d" % i):
			check_note_hit(i, current_fret)

func check_note_hit(string: int, fret: int) -> void:
	var controller = game_controller_node
	if controller and controller.has_method("note_hit"):
		controller.note_hit()
	
	if ui_controller and ui_controller.has_method("show_hit_effect"):
		ui_controller.show_hit_effect(string, fret)