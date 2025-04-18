@tool
extends "game_menu_base.gd"

signal submitted_play_online()
signal submitted_play_offline()
signal submitted_quit()

@onready
var _button_play_online: Button = %button_play_online as Button
@onready
var _button_play_offline: Button = %button_play_offline as Button
@onready
var _button_quit: Button = %button_quit as Button

func menu_grab_focus() -> void:
	if active:
		_button_play_online.grab_focus()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_button_play_online.pressed.connect(submitted_play_online.emit)
	_button_play_offline.pressed.connect(submitted_play_offline.emit)
	_button_quit.pressed.connect(submitted_quit.emit)
	
	_update_enabled()
	_update_tween_skipped()

func _update_enabled() -> void:
	if active:
		_button_play_online.focus_mode = Control.FOCUS_ALL
		_button_play_online.disabled = false
		
		_button_play_offline.focus_mode = Control.FOCUS_ALL
		_button_play_offline.disabled = false
		
		_button_quit.focus_mode = Control.FOCUS_ALL
		_button_quit.disabled = false
	else:
		_button_play_online.focus_mode = Control.FOCUS_NONE
		_button_play_online.disabled = true
		
		_button_play_offline.focus_mode = Control.FOCUS_NONE
		_button_play_offline.disabled = true
		
		_button_quit.focus_mode = Control.FOCUS_NONE
		_button_quit.disabled = true
