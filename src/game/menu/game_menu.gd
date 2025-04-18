@tool
extends Control

enum State {
	NONE,
	NAME,
	HOME,
	LIST,
}

const GameMenuName: = preload("game_menu_name.gd")
const GameMenuHome: = preload("game_menu_home.gd")
const GameMenuList: = preload("game_menu_list.gd")
const GameMenuSettings: = preload("game_menu_settings.gd")

signal submitted_name(player_name: String)
signal submitted_play_offline()
signal submitted_join_official()
signal submitted_join_custom(address: String)
signal submitted_host_custom(port: int)
signal submitted_join_instance(game_instance_id: int)
signal submitted_disconnect()

@onready
var _game_menu_name: GameMenuName = $game_menu_name as GameMenuName
@onready
var _game_menu_home: GameMenuHome = $game_menu_home as GameMenuHome
@onready
var _game_menu_list: GameMenuList = $game_menu_list as GameMenuList
@onready
var _game_menu_settings: GameMenuSettings = $game_menu_settings as GameMenuSettings

var _state: State = State.NONE

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_game_menu_name.submitted_name.connect(submitted_name.emit)
	
	_game_menu_home.submitted_play_offline.connect(submitted_play_offline.emit)
	_game_menu_home.submitted_join_official.connect(submitted_join_official.emit)
	_game_menu_home.submitted_join_custom.connect(submitted_join_custom.emit)
	_game_menu_home.submitted_host_custom.connect(submitted_host_custom.emit)
	
	_game_menu_list.submitted_join_instance.connect(submitted_join_instance.emit)
	#_game_menu_list.submitted_refresh
	_game_menu_list.submitted_disconnect.emit(submitted_disconnect.emit)
	
	_game_menu_settings.submitted_open.connect(func() -> void: _game_menu_settings.active = true)
	_game_menu_settings.submitted_resume.connect(func() -> void: _game_menu_settings.active = false)

func set_state(state: State) -> void:
	if _state == state:
		return
	_state = state
	
	match _state:
		State.NONE:
			_game_menu_name.active = false
			_game_menu_home.active = false
			_game_menu_list.active = false
		State.NAME:
			_game_menu_name.active = true
			_game_menu_home.active = false
			_game_menu_list.active = false
		State.HOME:
			_game_menu_name.active = false
			_game_menu_home.active = true
			_game_menu_list.active = false
		State.LIST:
			_game_menu_name.active = false
			_game_menu_home.active = false
			_game_menu_list.active = true
