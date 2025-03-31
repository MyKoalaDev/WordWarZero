@tool
extends Control

# TODO: on options menu button, cache last focused control, then focus on options
# on options menu leave, try focus on last control. if invalid, fallback to current menu

const GameMenuName: = preload("game_menu_name.gd")

signal submitted_name(player_name: String)
signal submitted_play()
signal submitted_play_offline()
signal submitted_join(address: String, port: int)
signal submitted_host(port: int)

@onready
var _color_rect: ColorRect = $color_rect as ColorRect

@onready
var _menu_name: GameMenuName = $menu_name as GameMenuName

var name_prompt: bool = true

var _active: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_menu_name.submitted_name.connect(_on_menu_name_submitted_name)
	
	if _active:
		pass
	else:
		pass

func _on_menu_name_submitted_name(player_name: String) -> void:
	submitted_name.emit(player_name)

var _tween: Tween = null

const TRANSITION_IN_DURATION: float = 0.125
const TRANSITION_OUT_DURATION: float = 0.125

func set_active(active: bool) -> void:
	if _active == active:
		return
	_active = active
	
	if is_instance_valid(_tween) && _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	
	if _active:
		pass
		
		_tween.set_parallel(true)
		_tween.set_ease(Tween.EASE_IN)
		_tween.set_trans(Tween.TRANS_CUBIC)
		
		var transition_duration: float = TRANSITION_IN_DURATION * (1.0 - modulate.a)
		_tween.tween_property(self, "modulate:a", 1.0, transition_duration)
	else:
		pass
		
		var transition_duration: float = TRANSITION_OUT_DURATION * modulate.a
		_tween.tween_property(self, "modulate:a", 0.0, transition_duration)
