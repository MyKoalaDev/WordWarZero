@tool
extends "game_menu_base.gd"

enum State {
	TITLE,
	PLAY_ONLINE,
	JOIN_CUSTOM,
	HOST_CUSTOM,
}

const GameMenuHomeTitle: = preload("game_menu_home_title.gd")
const GameMenuHomePlayOnline: = preload("game_menu_home_play_online.gd")
const GameMenuHomeJoinCustom: = preload("game_menu_home_join_custom.gd")
const GameMenuHomeHostCustom: = preload("game_menu_home_host_custom.gd")

signal submitted_play_offline()
signal submitted_join_official()
signal submitted_join_custom(address: String)
signal submitted_host_custom(custom_port: int)
signal submitted_quit()

@onready
var _game_menu_home_title: GameMenuHomeTitle = $game_menu_home_title as GameMenuHomeTitle
@onready
var _game_menu_home_play_online: GameMenuHomePlayOnline = $game_menu_home_play_online as GameMenuHomePlayOnline
@onready
var _game_menu_home_join_custom: GameMenuHomeJoinCustom = $game_menu_home_join_custom as GameMenuHomeJoinCustom
@onready
var _game_menu_home_host_custom: GameMenuHomeHostCustom = $game_menu_home_host_custom as GameMenuHomeHostCustom

var _state: State = State.TITLE

func menu_grab_focus() -> void:
	if active:
		match _state:
			State.TITLE:
				_game_menu_home_title.menu_grab_focus()
			State.PLAY_ONLINE:
				_game_menu_home_play_online.menu_grab_focus()
			State.JOIN_CUSTOM:
				_game_menu_home_join_custom.menu_grab_focus()
			State.HOST_CUSTOM:
				_game_menu_home_host_custom.menu_grab_focus()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_game_menu_home_title.submitted_play_online.connect(_set_state.bind(State.PLAY_ONLINE))
	_game_menu_home_title.submitted_play_offline.connect(submitted_play_offline.emit)
	_game_menu_home_title.submitted_quit.connect(submitted_quit.emit)
	
	_game_menu_home_play_online.submitted_join_official.connect(submitted_join_official.emit)
	_game_menu_home_play_online.submitted_join_custom.connect(_set_state.bind(State.JOIN_CUSTOM))
	_game_menu_home_play_online.submitted_host_custom.connect(_set_state.bind(State.HOST_CUSTOM))
	_game_menu_home_play_online.submitted_return.connect(_set_state.bind(State.TITLE))
	
	_game_menu_home_join_custom.submitted_join.connect(submitted_join_custom.emit)
	_game_menu_home_join_custom.submitted_return.connect(_set_state.bind(State.PLAY_ONLINE))
	
	_game_menu_home_host_custom.submitted_host.connect(submitted_host_custom.emit)
	_game_menu_home_host_custom.submitted_return.connect(_set_state.bind(State.PLAY_ONLINE))
	
	_update_enabled()
	_update_tween_skipped()

func _set_state(state: State) -> void:
	_state = state
	_update_enabled()

func _update_enabled() -> void:
	_game_menu_home_title.active = active && (_state == State.TITLE)
	_game_menu_home_play_online.active = active && (_state == State.PLAY_ONLINE)
	_game_menu_home_join_custom.active = active && (_state == State.JOIN_CUSTOM)
	_game_menu_home_host_custom.active = active && (_state == State.HOST_CUSTOM)
