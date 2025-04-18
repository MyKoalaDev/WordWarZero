@tool
extends "game_menu_base.gd"

signal submitted_join(address: String)
signal submitted_return()

@onready
var _line_edit_address: LineEdit = %line_edit_address as LineEdit
@onready
var _button_join: Button = %button_join as Button
@onready
var _button_return: Button = %button_return as Button

func menu_grab_focus() -> void:
	if active:
		_line_edit_address.grab_focus()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_button_join.pressed.connect(submitted_join.emit.bind(_line_edit_address.text))
	_button_return.pressed.connect(submitted_return.emit)
	
	_update_enabled()
	_update_tween_skipped()

func _update_enabled() -> void:
	if active:
		_line_edit_address.focus_mode = Control.FOCUS_ALL
		_line_edit_address.editable = true
		
		_button_join.focus_mode = Control.FOCUS_ALL
		_button_join.disabled = false
		
		_button_return.focus_mode = Control.FOCUS_ALL
		_button_return.disabled = false
	else:
		_line_edit_address.focus_mode = Control.FOCUS_NONE
		_line_edit_address.editable = false
		
		_button_join.focus_mode = Control.FOCUS_NONE
		_button_join.disabled = true
		
		_button_return.focus_mode = Control.FOCUS_NONE
		_button_return.disabled = true
