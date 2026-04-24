extends CanvasLayer

var game_controller: Node3D

var score_label: Label
var combo_label: Label
var progress_bar: ProgressBar
var play_button: Button
var instructions_label: Label
var hit_effect_container: VBoxContainer
var notes_label: Label

var string_names := ["E", "A", "D", "G", "B", "e"]

func _ready() -> void:
	setup_ui()

func setup_ui() -> void:
	var main_panel = PanelContainer.new()
	main_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_panel.modulate = Color(1, 1, 1, 0.9)
	add_child(main_panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.custom_minimum_size = Vector2(0, 720)
	vbox.add_theme_constant_override("separation", 10)
	main_panel.add_child(vbox)
	
	setup_top_bar(vbox)
	setup_center_info(vbox)
	setup_bottom_bar(vbox)
	setup_hit_effects(vbox)
	setup_instructions(vbox)

func setup_top_bar(parent: VBoxContainer) -> void:
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 60)
	hbox.add_theme_constant_override("separation", 20)
	parent.add_child(hbox)
	
	var title_label = Label.new()
	title_label.text = "ChartPlayer Godot"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hbox.add_child(title_label)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)
	
	score_label = Label.new()
	score_label.text = "Score: 0"
	score_label.add_theme_font_size_override("font_size", 20)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(score_label)
	
	combo_label = Label.new()
	combo_label.text = "Combo: 0"
	combo_label.add_theme_font_size_override("font_size", 18)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_label.modulate = Color(1, 0.8, 0)
	hbox.add_child(combo_label)
	
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(200, 20)
	progress_bar.max_value = 100
	progress_bar.value = 0
	hbox.add_child(progress_bar)

func setup_center_info(parent: VBoxContainer) -> void:
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)
	
	hit_effect_container = VBoxContainer.new()
	hit_effect_container.alignment = BoxContainer.ALIGNMENT_CENTER
	hit_effect_container.custom_minimum_size = Vector2(0, 100)
	parent.add_child(hit_effect_container)

func setup_bottom_bar(parent: VBoxContainer) -> void:
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 80)
	hbox.add_theme_constant_override("separation", 15)
	parent.add_child(hbox)
	
	play_button = Button.new()
	play_button.text = "PLAY"
	play_button.custom_minimum_size = Vector2(100, 50)
	play_button.add_theme_font_size_override("font_size", 18)
	play_button.pressed.connect(_on_play_pressed)
	hbox.add_child(play_button)
	
	var status_label = Label.new()
	status_label.text = "Press SPACE to play/pause"
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(status_label)
	
	var controls_info = VBoxContainer.new()
	
	var fret_info = Label.new()
	fret_info.text = "W/S: Change Fret"
	fret_info.add_theme_font_size_override("font_size", 12)
	controls_info.add_child(fret_info)
	
	var string_info = Label.new()
	string_info.text = "E F G H J K: Play Strings 1-6"
	string_info.add_theme_font_size_override("font_size", 12)
	controls_info.add_child(string_info)
	
	hbox.add_child(controls_info)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)
	
	notes_label = Label.new()
	notes_label.name = "NotesLabel"
	notes_label.text = "Notes: 0 / 0"
	notes_label.add_theme_font_size_override("font_size", 16)
	notes_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(notes_label)

func setup_hit_effects(parent: VBoxContainer) -> void:
	pass

func setup_instructions(parent: VBoxContainer) -> void:
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)
	
	instructions_label = Label.new()
	instructions_label.text = "[ 3D Guitar Note Highway - Like ChartPlayer ]"
	instructions_label.add_theme_font_size_override("font_size", 12)
	instructions_label.modulate = Color(0.7, 0.7, 0.7)
	instructions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(instructions_label)

func _on_play_pressed() -> void:
	if game_controller:
		game_controller.toggle_play()

func update_score(score: int, combo: int, max_combo: int, notes_hit: int, notes_missed: int) -> void:
	if score_label:
		score_label.text = "Score: %d" % score
	
	if combo_label:
		combo_label.text = "Combo: %d" % combo
		if combo > 10:
			combo_label.modulate = Color(1, 0.5, 0)
		elif combo > 5:
			combo_label.modulate = Color(1, 0.8, 0)
		else:
			combo_label.modulate = Color(1, 0.8, 0)
	
	if progress_bar:
		var total := notes_hit + notes_missed
		if total > 0:
			progress_bar.value = (notes_hit * 100.0) / total
		else:
			progress_bar.value = 0
	
	if notes_label:
		notes_label.text = "Hit: %d | Miss: %d" % [notes_hit, notes_missed]

func update_play_button(is_playing: bool) -> void:
	if play_button:
		play_button.text = "PAUSE" if is_playing else "PLAY"

func show_hit_effect(string: int, fret: int) -> void:
	var label = Label.new()
	label.text = "Hit! %s%d" % [string_names[string], fret]
	label.add_theme_font_size_override("font_size", 24)
	label.modulate = Color(0, 1, 0.5)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 50, 0.5)
	tween.parallel().tween_property(label, "modulate", Color(0, 1, 0.5, 0.0), 0.5)
	tween.tween_callback(label.queue_free)
	
	hit_effect_container.add_child(label)
