@tool
extends "game_menu_base.gd"

signal submitted_open()
signal submitted_resume()

@onready
var _texture_button_open: TextureButton = %texture_button_open as TextureButton

@onready
var _color_rect: ColorRect = %color_rect as ColorRect

@onready
var _texture_button_sound: TextureButton = %texture_button_sound as TextureButton
var _texture_button_sound_toggled: bool = false
@onready
var _h_slider_sound: HSlider = %h_slider_sound as HSlider
var _h_slider_sound_value_changed: bool = false

@onready
var _texture_button_music: TextureButton = %texture_button_music as TextureButton
var _texture_button_music_toggled: bool = false
@onready
var _h_slider_music: HSlider = %h_slider_music as HSlider
var _h_slider_music_value_changed: bool = false

@onready
var _button_resume: Button = %button_resume as Button

func menu_grab_focus() -> void:
	if active:
		_button_resume.grab_focus()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_texture_button_open.pressed.connect(submitted_open.emit)
	
	_texture_button_sound.pressed.connect(func() -> void: _texture_button_sound_toggled = true)
	_h_slider_sound.value_changed.connect(func(value: float) -> void: _h_slider_sound_value_changed = true)
	
	_texture_button_music.pressed.connect(func() -> void: _texture_button_music_toggled = true)
	_h_slider_music.value_changed.connect(func(value: float) -> void: _h_slider_music_value_changed = true)
	
	_button_resume.pressed.connect(submitted_resume.emit)
	
	_update_enabled()
	_update_tween_skipped()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	var sound_bus_index: int = AudioServer.get_bus_index(&"Sound")
	var sound_bus_muted: bool = AudioServer.is_bus_mute(sound_bus_index)
	var sound_bus_volume: float = AudioServer.get_bus_volume_linear(sound_bus_index)
	var sound_slider_value: float = remap(_h_slider_sound.value, _h_slider_sound.min_value, _h_slider_sound.max_value, 0.0, 1.0)
	
	var music_bus_index: int = AudioServer.get_bus_index(&"Music")
	var music_bus_muted: bool = AudioServer.is_bus_mute(music_bus_index)
	var music_bus_volume: float = AudioServer.get_bus_volume_linear(music_bus_index)
	var music_slider_value: float = remap(_h_slider_music.value, _h_slider_music.min_value, _h_slider_music.max_value, 0.0, 1.0)
	
	# Update AudioServer busses
	
	if _texture_button_sound_toggled:
		_texture_button_sound_toggled = false
		sound_bus_muted = !sound_bus_muted
		AudioServer.set_bus_mute(sound_bus_index, sound_bus_muted)
	
	if _texture_button_music_toggled:
		_texture_button_music_toggled = false
		music_bus_muted = !music_bus_muted
		AudioServer.set_bus_mute(music_bus_index, music_bus_muted)
	
	if _h_slider_sound_value_changed:
		_h_slider_sound_value_changed = false
		sound_bus_volume = sound_slider_value
		AudioServer.set_bus_volume_linear(sound_bus_index, sound_slider_value)
	
	if _h_slider_music_value_changed:
		_h_slider_music_value_changed = false
		music_bus_volume = music_slider_value
		AudioServer.set_bus_volume_linear(music_bus_index, music_slider_value)
	
	# Update GUI elements
	
	if sound_bus_muted:
		# TODO: Set texture to muted texture.
		_texture_button_sound.modulate = Color(1.0, 1.0, 1.0, 0.25)
	else:
		# TODO: Set texture to unmuted texture.
		_texture_button_sound.modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	if music_bus_muted:
		# TODO: Set texture to muted texture.
		_texture_button_music.modulate = Color(1.0, 1.0, 1.0, 0.25)
	else:
		# TODO: Set texture to unmuted texture.
		_texture_button_music.modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	if !is_equal_approx(sound_bus_volume, sound_slider_value):
		_h_slider_sound.set_value_no_signal(remap(sound_bus_volume, 0.0, 1.0, _h_slider_sound.min_value, _h_slider_sound.max_value))
	
	if !is_equal_approx(music_bus_volume, music_slider_value):
		_h_slider_music.set_value_no_signal(remap(music_bus_volume, 0.0, 1.0, _h_slider_music.min_value, _h_slider_music.max_value))

func _update_enabled() -> void:
	if active:
		_button_resume.focus_mode = Control.FOCUS_ALL
		_button_resume.disabled = false
	else:
		_button_resume.focus_mode = Control.FOCUS_NONE
		_button_resume.disabled = true

func _update_tween() -> void:
	super()
	
	var tween_duration: float
	if active:
		tween_duration = tween_in_duration * (1.0 - _tween_value)
		_tween.tween_property(self, "_tween_value", 1.0, tween_duration)
	else:
		tween_duration = tween_out_duration * (_tween_value)
		_tween.tween_property(self, "_tween_value", 0.0, tween_duration)

	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.set_trans(Tween.TRANS_LINEAR)
	
	if active:
		_color_rect.visible = true
		_tween.tween_property(_color_rect, "modulate:a", 1.0, tween_duration)
	else:
		_tween.tween_property(_color_rect, "modulate:a", 0.0, tween_duration)
		_tween.finished.connect(_color_rect.set.bind("visible", false))

func _update_tween_skipped() -> void:
	super()
	if active:
		_color_rect.visible = true
		_color_rect.modulate.a = 1.0
	else:
		_color_rect.visible = false
		_color_rect.modulate.a = 0.0
