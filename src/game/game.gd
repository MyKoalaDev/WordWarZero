@tool
extends Node
class_name Game

enum State {
	NONE,
	
}

const GameInstance: = preload("game_instance.gd")

signal client_started()
signal client_stopped()
signal server_started()
signal server_stopped()

const PLAYER_NAME_MAX_LENGTH: int = 16

@onready
var _network: Network = $network as Network
@onready
var _game_instance_root: Node = $instances as Node

@onready
var _game_lobby: GameLobby = $game_lobby/game_lobby as GameLobby
@onready
var _game_board: GameBoard = $game_board/game_board as GameBoard

var _game_instances: Dictionary[int, GameInstance] = {}
var _game_instance: GameInstance = null

static func is_valid_player_name(player_name: String) -> bool:
	if player_name.is_empty():
		return false
	if player_name.contains("\n"):
		return false
	if player_name.length() > PLAYER_NAME_MAX_LENGTH:
		return false
	return true

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	multiplayer.peer_connected.connect(_on_multiplayer_peer_connected)
	multiplayer.peer_disconnected.connect(_on_multiplayer_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_multiplayer_server_connected)
	multiplayer.server_disconnected.connect(_on_multiplayer_server_disconnected)

func _on_multiplayer_peer_connected(player_id: int) -> void:
	pass

func _on_multiplayer_peer_disconnected(player_id: int) -> void:
	pass

func _on_multiplayer_server_connected() -> void:
	pass

func _on_multiplayer_server_disconnected() -> void:
	pass

func is_active() -> bool:
	return _mode != Mode.NONE

func start_client(address: String, port: int, player_name: String = "Player") -> bool:
	if await _network.join_server(address, port) != OK:
		return false
	
	_game_data.set_local_player_name(player_name)
	_game_data.set_local_player_spectator(false)
	
	_mode = Mode.CLIENT
	client_started.emit()
	return true

func start_server(port: int, spectator: bool = true, player_name: String = "Host") -> bool:
	if _network.host_server(port) != OK:
		return false
	
	_game_data.set_local_player_name(player_name)
	_game_data.set_local_player_spectator(spectator)
	
	_mode = Mode.SERVER
	_set_state(State.LOBBY)
	server_started.emit()
	return true

func stop() -> void:
	match _mode:
		Mode.NONE:
			pass
		Mode.CLIENT:
			# TODO: Reset board, tiles, players, etc.
			# though much of reset would be through rpcs and multiplayer callbacks?
			if _network.is_active():
				_network.quit_server()
			_mode = Mode.NONE
			_set_state(State.NONE)
			client_stopped.emit()
		Mode.SERVER:
			if _network.is_active():
				_network.stop_server()
			_mode = Mode.NONE
			_set_state(State.NONE)
			server_stopped.emit()

@rpc("authority", "call_remote", "reliable", 1)
func _rpc_set_state(state: State) -> void:
	_set_state(state)

func _set_state(state: State) -> void:
	if _state_curr == state:
		return
	_state_curr = state
	if multiplayer.has_multiplayer_peer() && is_multiplayer_authority():
		_rpc_set_state.rpc(_state_curr)
	
	match _state_curr:
		State.NONE:
			_game_lobby.active = false
			_game_lobby.visible = false
			_game_board.active = false
			_game_board.visible = false
		State.LOBBY:
			_game_lobby.active = true
			_game_lobby.visible = true
			_game_board.active = false
			_game_board.visible = false
		State.PLAY:
			_game_lobby.active = false
			_game_lobby.visible = false
			_game_board.active = true
			_game_board.visible = true

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	match _mode:
		Mode.NONE:
			pass
		Mode.CLIENT:
			if !multiplayer.has_multiplayer_peer():
				stop()
			match _state_curr:
				State.LOBBY:
					pass
				State.PLAY:
					pass
		Mode.SERVER:
			if !multiplayer.has_multiplayer_peer():
				stop()
			match _state_curr:
				State.LOBBY:
					if _game_data.get_all_players_ready():
						_game_data.set_all_players_ready(false)
						_set_state(State.PLAY)
						_game_board.start_loop()
				State.PLAY:
					if !_game_board.is_loop():
						_set_state(State.LOBBY)
