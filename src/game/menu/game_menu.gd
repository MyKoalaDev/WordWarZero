@tool
extends Control

const GameMenuName: = preload("game_menu_name.gd")

const TWEEN_IN_DURATION: float = 0.125
const TWEEN_OUT_DURATION: float = 0.125

signal submitted_name(player_name: String)
signal submitted_play()
signal submitted_play_offline()
signal submitted_join_custom(address: String, port: int)
signal submitted_host(port: int)

@onready
var _color_rect: ColorRect = $color_rect as ColorRect
@onready
var _menu_name: GameMenuName = $menu_name as GameMenuName

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_menu_name.submitted_name.connect(submitted_name.emit)
