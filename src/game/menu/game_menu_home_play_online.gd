@tool
extends "game_menu_base.gd"

signal submitted_join_official()
signal submitted_join_custom()
signal submitted_host_custom()
signal submitted_return()

@onready
var _button_join_official: Button = %button_join_official as Button
@onready
var _button_join_custom: Button = %button_join_custom as Button
@onready
var _button_host_custom: Button = %button_host_custom as Button
@onready
var _button_return: Button = %button_return as Button

func menu_grab_focus() -> void:
	if active:
		_button_join_official.grab_focus()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_button_join_official.pressed.connect(submitted_join_official.emit)
	_button_join_custom.pressed.connect(submitted_join_custom.emit)
	_button_host_custom.pressed.connect(submitted_host_custom.emit)
	_button_return.pressed.connect(submitted_return.emit)
	
	_update_enabled()
	_update_tween_skipped()

func _update_enabled() -> void:
	if active:
		_button_join_official.focus_mode = Control.FOCUS_ALL
		_button_join_official.disabled = false
		
		_button_join_custom.focus_mode = Control.FOCUS_ALL
		_button_join_custom.disabled = false
		
		_button_host_custom.focus_mode = Control.FOCUS_ALL
		_button_host_custom.disabled = false
		
		_button_return.focus_mode = Control.FOCUS_ALL
		_button_return.disabled = false
	else:
		_button_join_official.focus_mode = Control.FOCUS_NONE
		_button_join_official.disabled = true
		
		_button_join_custom.focus_mode = Control.FOCUS_NONE
		_button_join_custom.disabled = true
		
		_button_host_custom.focus_mode = Control.FOCUS_NONE
		_button_host_custom.disabled = true
		
		_button_return.focus_mode = Control.FOCUS_NONE
		_button_return.disabled = true
