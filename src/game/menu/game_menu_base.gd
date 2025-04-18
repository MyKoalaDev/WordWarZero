@tool
extends Control

enum TweenType {
	NONE,
	FADE,
	SLIDE_DOWN,
}

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

@export
var custom_tween_target: Control = null:
	get:
		return custom_tween_target
	set(value):
		custom_tween_target = value

@export
var tween_type: TweenType = TweenType.NONE:
	get:
		return _tween_type_next
	set(value):
		_tween_type_next = value

var _tween_type_curr: TweenType = TweenType.NONE
var _tween_type_next: TweenType = TweenType.NONE

@export_range(0.001, 8.0, 0.001, "or_greater")
var tween_in_duration: float = 0.5

@export_range(0.001, 8.0, 0.001, "or_greater")
var tween_out_duration: float = 0.5

var _tween: Tween = null
var _tween_value: float = 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_update_enabled()
	_update_tween_skipped()

func menu_grab_focus() -> void:
	pass

func _update_enabled() -> void:
	if active:
		pass
	else:
		pass

func _update_tween() -> void:
	if is_instance_valid(_tween) && _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	
	var tween_target: Control = custom_tween_target
	if !is_instance_valid(tween_target):
		tween_target = self
	
	var tween_duration: float
	if active:
		tween_duration = tween_in_duration * (1.0 - _tween_value)
		_tween.tween_property(self, "_tween_value", 1.0, tween_duration)
	else:
		tween_duration = tween_out_duration * (_tween_value)
		_tween.tween_property(self, "_tween_value", 0.0, tween_duration)
	
	if _tween_type_curr != _tween_type_next:
		match _tween_type_curr:
			TweenType.NONE:
				tween_target.visible = true
			TweenType.FADE:
				tween_target.visible = true
				tween_target.modulate.a = 1.0
			TweenType.SLIDE_DOWN:
				tween_target.visible = true
				tween_target.position.y = 0.0
		_tween_type_curr = _tween_type_next
	
	match _tween_type_curr:
		TweenType.NONE:
			if active:
				tween_target.visible = true
			else:
				tween_target.visible = false
		TweenType.FADE:
			_tween.set_ease(Tween.EASE_IN_OUT)
			_tween.set_trans(Tween.TRANS_LINEAR)
			
			if active:
				tween_target.visible = true
				_tween.tween_property(tween_target, "modulate:a", 1.0, tween_duration)
			else:
				_tween.tween_property(tween_target, "modulate:a", 0.0, tween_duration)
				_tween.finished.connect(tween_target.set.bind("visible", false))
		TweenType.SLIDE_DOWN:
			_tween.set_ease(Tween.EASE_OUT)
			_tween.set_trans(Tween.TRANS_CUBIC)
			
			if active:
				tween_target.visible = true
				_tween.tween_property(tween_target, "position:y", 0.0, tween_duration)
			else:
				_tween.tween_property(tween_target, "position:y", size.y, tween_duration)
				_tween.finished.connect(tween_target.set.bind("visible", false))

func _update_tween_skipped() -> void:
	if is_instance_valid(_tween) && _tween.is_valid():
		_tween.kill()
	
	var tween_target: Control = custom_tween_target
	if !is_instance_valid(tween_target):
		tween_target = self
	
	if _tween_type_curr != _tween_type_next:
		match _tween_type_curr:
			TweenType.NONE:
				tween_target.visible = true
			TweenType.FADE:
				tween_target.visible = true
				tween_target.modulate.a = 1.0
			TweenType.SLIDE_DOWN:
				tween_target.visible = true
				tween_target.position.y = 0.0
		_tween_type_curr = _tween_type_next
	
	match _tween_type_curr:
		TweenType.NONE:
			if active:
				tween_target.visible = true
			else:
				tween_target.visible = false
		TweenType.FADE:
			if active:
				tween_target.visible = true
				tween_target.modulate.a = 1.0
			else:
				tween_target.visible = false
				tween_target.modulate.a = 0.0
		TweenType.SLIDE_DOWN:
			if active:
				tween_target.visible = true
				tween_target.position.y = 0.0
			else:
				tween_target.visible = false
				tween_target.position.y = size.y
