@tool
extends Control

# menu mutates Game directly? some rule violation but i think ok

enum State {
	NONE,
	NAME,
	HOME,
	HOME_PLAY_ONLINE,
	HOME_JOIN_CUSTOM,
	HOME_HOST_CUSTOM,
	SETTINGS,
}
var _state: State = State.NONE

const GameMenuName: = preload("game_menu_name.gd")
const GameMenuHome: = preload("game_menu_home.gd")
const GameMenuHomePlayOnline: = preload("game_menu_home_play_online.gd")
const GameMenuHomeJoinCustom: = preload("game_menu_home_join_custom.gd")
const GameMenuHomeHostCustom: = preload("game_menu_home_host_custom.gd")

const TWEEN_IN_DURATION: float = 0.125
const TWEEN_OUT_DURATION: float = 0.125

signal submitted_name(player_name: String)
signal submitted_play_official()
signal submitted_play_offline()
signal submitted_join_custom(address: String)
signal submitted_host_custom(port: int)

var game: Game = null:
	get:
		return game
	set(value):
		if game != value:
			game = value

@onready
var _color_rect: ColorRect = $color_rect as ColorRect
@onready
var _menu_name: GameMenuName = $menu_name as GameMenuName
@onready
var _menu_home: GameMenuHome = $menu_home as GameMenuHome
@onready
var _menu_home_play_online: GameMenuHomePlayOnline = $menu_home_play_online as GameMenuHomePlayOnline
@onready
var _menu_home_join_custom: GameMenuHomeJoinCustom = $menu_home_join_custom as GameMenuHomeJoinCustom
@onready
var _menu_home_host_custom: GameMenuHomeHostCustom = $menu_home_host_custom as GameMenuHomeHostCustom

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_menu_name.submitted_name.connect(game.set_local_player_name)
	
	_menu_home.submitted_play_online.connect(set_state.bind(State.HOME_PLAY_ONLINE))
	_menu_home.submitted_play_offline# play offline via game
	_menu_home.submitted_quit# quit via game
	
	_menu_home_play_online.submitted_join_official
	_menu_home_play_online.submitted_join_custom.connect(set_state.bind(State.HOME_JOIN_CUSTOM))
	_menu_home_play_online.submitted_host_custom.connect(set_state.bind(State.HOME_HOST_CUSTOM))
	_menu_home_play_online.submitted_back.connect(set_state.bind(State.HOME))
	
	_menu_home_join_custom.submitted_join
	_menu_home_join_custom.submitted_back.connect(set_state.bind(State.HOME_PLAY_ONLINE))
	
	_menu_home_host_custom.submitted_host
	_menu_home_host_custom.submitted_back.connect(set_state.bind(State.HOME_PLAY_ONLINE))
	

func _on_menu_home_submitted_play_online() -> void:
	pass

func set_state(state: State) -> void:
	if _state == state:
		return
	_state = state
	
	_menu_name.active = (_state == State.NAME)
	_menu_home.active = (_state == State.HOME)
	_menu_home_play_online.active = (_state == State.HOME_PLAY_ONLINE)
	_menu_home_join_custom.active = (_state == State.HOME_JOIN_CUSTOM)
	_menu_home_host_custom.active = (_state == State.HOME_HOST_CUSTOM)
	
