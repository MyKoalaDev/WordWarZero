@tool
extends Control

const TWEEN_IN_DURATION: float = 0.125
const TWEEN_OUT_DURATION: float = 0.125

signal submitted_play_online()
signal submitted_play_offline()
signal submitted_quit()

@onready
var _button_play_online: Button = $v_box_container/button_play_online as Button
@onready
var _button_play_offline: Button = $v_box_container/button_play_offline as Button
@onready
var _button_quit: Button = $v_box_container/button_quit as Button

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

func menu_grab_focus() -> void:
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

func _update_tween() -> void:
	if is_instance_valid(_tween) && _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	
	if active:
		var tween_duration: float = TWEEN_IN_DURATION * (1.0 - _tween_value)
		_tween.tween_property(self, "_tween_value", 1.0, tween_duration)
		
		_tween.set_parallel(true)
		_tween.set_ease(Tween.EASE_IN_OUT)
		_tween.set_trans(Tween.TRANS_LINEAR)
		_tween.tween_property(self, "visible", true, 0.0)
		_tween.tween_property(self, "modulate:a", 1.0, tween_duration)
	else:
		var tween_duration: float = TWEEN_OUT_DURATION * (_tween_value)
		_tween.tween_property(self, "_tween_value", 0.0, tween_duration)
		
		_tween.set_parallel(true)
		_tween.set_ease(Tween.EASE_IN_OUT)
		_tween.set_trans(Tween.TRANS_LINEAR)
		_tween.tween_property(self, "modulate:a", 0.0, tween_duration)
		_tween.tween_property(self, "visible", false, tween_duration)

func _update_tween_skipped() -> void:
	if is_instance_valid(_tween) && _tween.is_valid():
		_tween.kill()
	
	# Skip to tween end values.
	if active:
		_tween_value = 1.0
		
		visible = true
		modulate.a = 1.0
	else:
		_tween_value = 0.0
		
		modulate.a = 0.0
		visible = false
