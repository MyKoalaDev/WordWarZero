@tool
extends "game_menu_base.gd"

signal submitted_refresh()
signal submitted_disconnect()
signal submitted_join_instance(game_instance_id: int)

@onready
var _button_create: Button = %button_create as Button
@onready
var _button_refresh: Button = %button_refresh as Button
@onready
var _button_disconnect: Button = %button_disconnect as Button

func menu_grab_focus() -> void:
	_button_refresh.grab_focus()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_button_refresh.pressed.connect(submitted_refresh.emit)
	_button_disconnect.pressed.connect(submitted_disconnect.emit)
	
	_update_enabled()
	_update_tween_skipped()

func _update_enabled() -> void:
	if active:
		_button_create.focus_mode = Control.FOCUS_ALL
		_button_create.disabled = false
		
		_button_refresh.focus_mode = Control.FOCUS_ALL
		_button_refresh.disabled = false
		
		_button_disconnect.focus_mode = Control.FOCUS_ALL
		_button_disconnect.disabled = false
	else:
		_button_create.focus_mode = Control.FOCUS_NONE
		_button_create.disabled = true
		
		_button_refresh.focus_mode = Control.FOCUS_NONE
		_button_refresh.disabled = true
		
		_button_disconnect.focus_mode = Control.FOCUS_NONE
		_button_disconnect.disabled = true
