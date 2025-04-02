@tool
extends Control

const TWEEN_IN_DURATION: float = 0.125
const TWEEN_OUT_DURATION: float = 0.125

signal submitted_toggle()
signal submitted_resume()
signal submitted_return()

@onready
var _color_rect: ColorRect = $color_rect as ColorRect
@onready
var _panel: Panel = $panel as Panel
@onready
var _button_toggle: TextureButton = $button_toggle as TextureButton
@onready
var _button_resume: Button = $panel/margin_container/v_box_container/button_resume as Button
@onready
var _button_return: Button = $panel/margin_container/v_box_container/button_return as Button

@export
var active: bool = false:
	get:
		return active
	set(value):
		if active != value:
			active = value
			if is_node_ready():
				_update_enabled()
				_update_tween()

var _tween: Tween = null
var _tween_value: float = 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_button_toggle.pressed.connect(submitted_toggle.emit)
	_button_resume.pressed.connect(submitted_resume.emit)
	_button_return.pressed.connect(submitted_return.emit)
	
	_update_enabled()
	_update_tween_skipped()

func _update_enabled() -> void:
	if active:
		_button_resume.focus_mode = Control.FOCUS_ALL
		_button_resume.disabled = false
		
		_button_return.focus_mode = Control.FOCUS_ALL
		_button_return.disabled = false
	else:
		_button_resume.focus_mode = Control.FOCUS_NONE
		_button_resume.disabled = true
		
		_button_return.focus_mode = Control.FOCUS_NONE
		_button_return.disabled = true

func _update_tween() -> void:
	if is_instance_valid(_tween) && _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	
	if active:
		var tween_duration: float = TWEEN_IN_DURATION * (1.0 - _tween_value)
		_tween.tween_property(self, "_tween_value", 1.0, tween_duration)
		
		_tween.set_parallel(true)
		_tween.tween_property(_color_rect, "visible", true, 0.0)
		_tween.tween_property(_panel, "visible", true, 0.0)
		
		_tween.set_parallel(true)
		_tween.set_ease(Tween.EASE_IN_OUT)
		_tween.set_trans(Tween.TRANS_LINEAR)
		_tween.tween_property(_color_rect, "modulate:a", 1.0, tween_duration)
		_tween.tween_property(_panel, "modulate:a", 1.0, tween_duration)
	else:
		var tween_duration: float = TWEEN_OUT_DURATION * (_tween_value)
		_tween.tween_property(self, "_tween_value", 0.0, tween_duration)
		
		_tween.set_parallel(true)
		_tween.set_ease(Tween.EASE_IN_OUT)
		_tween.set_trans(Tween.TRANS_LINEAR)
		_tween.tween_property(_color_rect, "modulate:a", 0.0, tween_duration)
		_tween.tween_property(_panel, "modulate:a", 0.0, tween_duration)
		
		_tween.set_parallel(false)
		_tween.tween_property(_color_rect, "visible", false, 0.0)
		_tween.tween_property(_panel, "visible", false, 0.0)

func _update_tween_skipped() -> void:
	if is_instance_valid(_tween) && _tween.is_valid():
		_tween.kill()
	
	# Skip to tween end values.
	if active:
		_tween_value = 1.0
		
		_color_rect.visible = true
		_panel.visible = true
		
		_color_rect.modulate.a = 1.0
		_panel.modulate.a = 1.0
	else:
		_tween_value = 0.0
		
		_color_rect.modulate.a = 0.0
		_panel.modulate.a = 0.0
		
		_color_rect.visible = false
		_panel.visible = false
