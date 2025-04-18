@tool
extends "game_menu_base.gd"

signal submitted_name(player_name: String)

@onready
var _label_prompt: RichTextLabel = $label_prompt as RichTextLabel
@onready
var _line_edit_name: LineEdit = %line_edit_name as LineEdit
@onready
var _button_submit: Button = %button_submit as Button

func menu_grab_focus() -> void:
	if active:
		_line_edit_name.grab_focus()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_button_submit.pressed.connect(submitted_name.emit.bind(_line_edit_name.text))
	
	_update_enabled()
	_update_tween_skipped()

func _update_enabled() -> void:
	if active:
		_line_edit_name.focus_mode = Control.FOCUS_ALL
		_line_edit_name.editable = true
		
		_button_submit.focus_mode = Control.FOCUS_ALL
		_button_submit.disabled = false
	else:
		_line_edit_name.focus_mode = Control.FOCUS_NONE
		_line_edit_name.editable = false
		
		_button_submit.focus_mode = Control.FOCUS_NONE
		_button_submit.disabled = true
