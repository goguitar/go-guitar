extends Node3D

func _ready() -> void:
	_setup_environment()

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.1, 0.1, 0.15)
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.2
	
	var world_env := $WorldEnvironment as WorldEnvironment
	if world_env:
		world_env.environment = env

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
