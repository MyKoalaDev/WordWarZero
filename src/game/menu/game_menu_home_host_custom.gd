@tool
extends "game_menu_base.gd"

signal submitted_host(port: int)
signal submitted_return()

@onready
var _line_edit_port: LineEdit = %line_edit_port as LineEdit
@onready
var _button_host: Button = %button_host as Button
@onready
var _button_return: Button = %button_return as Button

func menu_grab_focus() -> void:
	if active:
		_line_edit_port.grab_focus()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_button_host.pressed.connect(submitted_host.emit.bind(_line_edit_port.text))
	
	_update_enabled()
	_update_tween_skipped()

func _update_enabled() -> void:
	if active:
		_line_edit_port.focus_mode = Control.FOCUS_ALL
		_line_edit_port.editable = true
		
		_button_host.focus_mode = Control.FOCUS_ALL
		_button_host.disabled = false
		
		_button_return.focus_mode = Control.FOCUS_ALL
		_button_return.disabled = false
	else:
		_line_edit_port.focus_mode = Control.FOCUS_NONE
		_line_edit_port.editable = false
		
		_button_host.focus_mode = Control.FOCUS_NONE
		_button_host.disabled = true
		
		_button_return.focus_mode = Control.FOCUS_NONE
		_button_return.disabled = true
