@tool
extends Control

signal submitted_name(player_name: String)

@onready
var _label_prompt: RichTextLabel = $label_prompt as RichTextLabel
@onready
var _line_edit: LineEdit = $v_box_container/line_edit as LineEdit
@onready
var _button_submit: Button = $v_box_container/button_submit as Button

var _active: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_button_submit.pressed.connect(_on_button_submit_pressed)
	
	if _active:
		_button_submit.focus_mode = Control.FOCUS_ALL
		_button_submit.disabled = false
		
		_line_edit.focus_mode = Control.FOCUS_ALL
		_line_edit.grab_focus()
	else:
		_button_submit.focus_mode = Control.FOCUS_NONE
		_button_submit.disabled = true
		_button_submit.release_focus()
		
		_line_edit.focus_mode = Control.FOCUS_NONE
		_line_edit.release_focus()

func _on_button_submit_pressed() -> void:
	submitted_name.emit(_line_edit.text)

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
		_button_submit.focus_mode = Control.FOCUS_ALL
		_button_submit.disabled = false
		
		_line_edit.focus_mode = Control.FOCUS_ALL
		_line_edit.grab_focus()
		
		_tween.set_parallel(true)
		_tween.set_ease(Tween.EASE_IN)
		_tween.set_trans(Tween.TRANS_CUBIC)
		
		var transition_duration: float = TRANSITION_IN_DURATION * (1.0 - modulate.a)
		_tween.tween_property(self, "modulate:a", 1.0, transition_duration)
	else:
		_button_submit.focus_mode = Control.FOCUS_NONE
		_button_submit.disabled = true
		_button_submit.release_focus()
		
		_line_edit.focus_mode = Control.FOCUS_NONE
		_line_edit.release_focus()
		
		var transition_duration: float = TRANSITION_OUT_DURATION * modulate.a
		_tween.tween_property(self, "modulate:a", 0.0, transition_duration)
