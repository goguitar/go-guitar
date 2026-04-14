extends CanvasLayer

var score_label: Label
var combo_label: Label
var info_label: Label
var play_button: Button

func _ready() -> void:
	_setup_ui()

func _setup_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.modulate = Color(1, 1, 1, 0.95)
	add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vbox)
	
	var top_bar := HBoxContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 50)
	top_bar.add_theme_constant_override("separation", 20)
	vbox.add_child(top_bar)
	
	var title := Label.new()
	title.text = "Go-Guitar"
	title.add_theme_font_size_override("font_size", 24)
	top_bar.add_child(title)
	
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)
	
	score_label = Label.new()
	score_label.text = "Score: 0"
	score_label.add_theme_font_size_override("font_size", 20)
	top_bar.add_child(score_label)
	
	combo_label = Label.new()
	combo_label.text = "Combo: 0"
	combo_label.add_theme_font_size_override("font_size", 18)
	combo_label.modulate = Color(1, 0.8, 0)
	top_bar.add_child(combo_label)
	
	var center_spacer := Control.new()
	center_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(center_spacer)
	
	var bottom_bar := HBoxContainer.new()
	bottom_bar.custom_minimum_size = Vector2(0, 60)
	bottom_bar.add_theme_constant_override("separation", 15)
	vbox.add_child(bottom_bar)
	
	play_button = Button.new()
	play_button.text = "PLAY"
	play_button.custom_minimum_size = Vector2(100, 40)
	play_button.add_theme_font_size_override("font_size", 16)
	play_button.pressed.connect(_on_play_pressed)
	bottom_bar.add_child(play_button)
	
	var status := Label.new()
	status.text = "Press SPACE or click PLAY to start"
	status.add_theme_font_size_override("font_size", 14)
	bottom_bar.add_child(status)
	
	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_bar.add_child(spacer2)
	
	info_label = Label.new()
	info_label.text = "[ Go-Guitar - 3D Guitar Game ]"
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(info_label)

func _on_play_pressed() -> void:
	var game := get_parent().get_node("GameController")
	if game and game.has_method("toggle_play"):
		game.toggle_play()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("play_pause"):
		_on_play_pressed()

func update_score(score: int, combo: int, max_combo: int, hit: int, missed: int) -> void:
	if score_label:
		score_label.text = "Score: %d" % score
	
	if combo_label:
		combo_label.text = "Combo: %d" % combo
		if combo > 20:
			combo_label.modulate = Color(1, 0.3, 0.3)
		elif combo > 10:
			combo_label.modulate = Color(1, 0.6, 0)
		elif combo > 5:
			combo_label.modulate = Color(1, 0.9, 0)
		else:
			combo_label.modulate = Color(1, 0.8, 0)
	
	if play_button:
		var game := get_parent().get_node("GameController")
		if game and game.has_method("is_playing"):
			play_button.text = "PAUSE" if game.is_playing else "PLAY"
