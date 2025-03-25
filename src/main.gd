@tool
extends Node

# TODO (where I left off)
# game_submission problem: need to get tile board multiplier data

# TODO: Test passing args in HTML export 

# TODO: Server read stdin as commands (OS.read_string_from_stdin())
# Command ideas:
# help - lists all commands and their usage
# list_instances - lists all game instances (ID) and their players (name and ID)
# list_players - lists all players (name and ID)
# kick <player_id> - kick a player
# stop_instance <instance_id> - stops a game instance
# shutdown - shuts down the server and exits game

const DEFAULT_SERVER_PORT: int = 30666
const DEFAULT_SERVER_ADDRESS: String = "127.0.0.1"

enum State {
	SPLASH,
	NETWORK,
	TITLE,
	GAME,
}
var _state: State = State.SPLASH

@onready
var _menu_config: MenuConfig = $gui/menu_config as MenuConfig

@onready
var _game: Game = $game as Game

const TIMEOUT: float = 300.0
var _timeout: float = 0.0

var _unsafe: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_menu_config.network_host_request.connect(_on_menu_config_network_host_request)
	_menu_config.network_join_request.connect(_on_menu_config_network_join_request)
	
	_game.server_started.connect(_on_game_server_started)
	_game.server_stopped.connect(_on_game_server_stopped)
	_game.client_started.connect(_on_game_client_started)
	_game.client_stopped.connect(_on_game_client_stopped)
	
	# Process command line arguments.
	var args: Dictionary[String, String] = {}
	var args_raw: PackedStringArray = OS.get_cmdline_user_args()
	for arg_raw: String in args_raw:
		var split: int = arg_raw.find("=")
		var key: String = arg_raw.substr(0, split).trim_prefix("--")
		if split > -1:
			args[key] = arg_raw.substr(split + 1, -1)
		else:
			args[key] = ""
	
	var server: bool = false
	
	var auto_connect: bool = true
	var address: String = DEFAULT_SERVER_ADDRESS
	var port: int = DEFAULT_SERVER_PORT
	var player_name: String = ""
	
	if args.has("name"):
		player_name = args["name"]
	if args.has("unsafe"):
		_unsafe = true
	if args.has("auto-connect"):
		auto_connect = args["auto-connect"].to_lower() == "true"
	if args.has("address"):
		address = args["address"]
	if args.has("server"):
		server = true
	
	if !player_name.is_empty():
		_menu_config.set_player_name(player_name)
	
	if server:
		if !_game.start_server(port, true, "Host"):
			push_error("Error hosting server!")
			get_tree().quit(1)
			return
		
		_menu_config.set_state(MenuConfig.State.NONE)
	else:
		_menu_config.set_network_details(address, port, auto_connect)
		_menu_config.set_state(MenuConfig.State.NAME)

func _on_game_server_started() -> void:
	_menu_config.set_state(MenuConfig.State.NONE)

func _on_game_server_stopped() -> void:
	_menu_config.set_state(MenuConfig.State.NETWORK)

func _on_game_client_started() -> void:
	_menu_config.set_state(MenuConfig.State.NONE)

func _on_game_client_stopped() -> void:
	_menu_config.set_state(MenuConfig.State.NETWORK)

func _on_menu_config_network_join_request() -> void:
	_game.start_client(_menu_config.get_network_address(), _menu_config.get_network_port(), _menu_config.get_player_name())

func _on_menu_config_network_host_request() -> void:
	_game.start_server(_menu_config.get_network_port(), false)

func set_state(state: State) -> void:
	_state = state
	match state:
		State.SPLASH:
			pass
		State.TITLE:
			pass
		State.GAME:
			pass
