@tool
extends Node
class_name Game

# TODO: move all networking stuff to Game from menu_network
#

# TODO:
# add game instance list. on button press -> game_instance.request_join_instance()

enum State {
	NONE,
	NAME,
	CONNECT,
	CONNECTING,
	HOME,
	WAIT,
	PLAY,
	HEADLESS,
}

const GameInstance: = preload("game_instance.gd")

const PLAYER_NAME_MAX_LENGTH: int = 16
const DEFAULT_PLAYER_NAME: String = "Player"
const INVALID_GAME_INSTANCE_ID: int = -1

@onready
var _network: Network = $network as Network
@onready
var _game_instance_root: Node = $instances as Node

@onready
var _game_lobby: GameLobby = $game_lobby/game_lobby as GameLobby
@onready
var _game_board: GameBoard = $game_board/game_board as GameBoard

var _state: State = State.NONE

## Hashmap of game instance IDs to game instances.
var _game_instances: Dictionary[int, GameInstance] = {}

#region Player

class _PlayerData:
	extends RefCounted
	var player_name: String = DEFAULT_PLAYER_NAME
	var player_name_set: bool = false
	var player_color: Color = Color.WHITE
	var player_game_instance_id: int = INVALID_GAME_INSTANCE_ID

## Hashmap of player IDs to player data (Server only).
var _players: Dictionary[int, _PlayerData] = {}

var _local_player_name: String = DEFAULT_PLAYER_NAME
var _local_player_color: Color = Color.WHITE
var _local_player_game_instance_id: int = INVALID_GAME_INSTANCE_ID

func is_valid_player_name(player_name: String) -> bool:
	if player_name.is_empty():
		return false
	if player_name.contains("\n"):
		return false
	if player_name.length() > PLAYER_NAME_MAX_LENGTH:
		return false
	return true

func set_local_player_name(player_name: String) -> bool:
	if !is_valid_player_name(player_name):
		return false
	
	_local_player_name = player_name
	return true

@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_set_player_name(player_name: String) -> void:
	if !is_multiplayer_authority():
		return
	
	if !is_valid_player_name(player_name):
		return
	
	var player_id: int = multiplayer.get_remote_sender_id()
	if !_players[player_id].player_name_set:
		_players[player_id].player_name_set = true
		_players[player_id].player_name = player_name

#endregion
#region Instance

func _on_game_instance_local_player_id_added(game_instance_id: int) -> void:
	assert(_local_player_game_instance_id == INVALID_GAME_INSTANCE_ID)
	_local_player_game_instance_id = game_instance_id

func _on_game_instance_local_player_id_removed(game_instance_id: int) -> void:
	assert(_local_player_game_instance_id == game_instance_id)
	_local_player_game_instance_id = INVALID_GAME_INSTANCE_ID

func get_instance_next_id() -> int:
	var game_instance_id: int = 0
	while _game_instances.has(game_instance_id):
		game_instance_id += 1
	return game_instance_id

func create_instance() -> int:
	if !multiplayer.has_multiplayer_peer():
		push_error("Game \"%s\" | Failed to create game instance: multiplayer is not currently active." % [self.name])
		return -1
	
	if !is_multiplayer_authority():
		push_error("Game \"%s\" | Failed to create game instance: only the authority can create game instances." % [self.name])
		return -1
	
	var game_instance_id: int = get_instance_next_id()
	_create_instance(game_instance_id)
	
	_rpc_create_instance.rpc(game_instance_id)
	return game_instance_id

func _create_instance(game_instance_id: int) -> void:
	var game_instance: GameInstance = GameInstance.new()
	_game_instance_root.add_child(game_instance)
	game_instance.name = str(game_instance_id)
	game_instance.local_player_id_added.connect(_on_game_instance_local_player_id_added.bind(game_instance_id))
	game_instance.local_player_id_removed.connect(_on_game_instance_local_player_id_removed.bind(game_instance_id))
	_game_instances[game_instance_id] = game_instance

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_create_instance(game_instance_id: int) -> void:
	if _game_instances.has(game_instance_id):
		return
	
	_create_instance(game_instance_id)

func remove_instance(game_instance_id: int) -> bool:
	if !is_multiplayer_authority():
		push_error("Game \"%s\" | Failed to remove game instance ID '%d': only the authority can remove game instances." % [self.name, game_instance_id])
		return false
	
	if !_game_instances.has(game_instance_id):
		push_error("Game \"%s\" | Failed to remove game instance ID '%d': game instance does not exist." % [self.name, game_instance_id])
		return false
	
	_remove_instance(game_instance_id)
	
	_rpc_remove_instance.rpc(game_instance_id)
	return true

func _remove_instance(game_instance_id: int) -> void:
	var game_instance: GameInstance = _game_instances[game_instance_id]
	_game_instances.erase(game_instance_id)
	_game_instance_root.remove_child(game_instance)
	game_instance.queue_free()
	if _local_player_game_instance_id == game_instance_id:
		_local_player_game_instance_id = INVALID_GAME_INSTANCE_ID

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_remove_instance(game_instance_id: int) -> void:
	if !_game_instances.has(game_instance_id):
		return
	
	_remove_instance(game_instance_id)

func request_create_instance() -> bool:
	if !multiplayer.has_multiplayer_peer():
		push_error("Game \"%s\" | Failed to request to create game instance: multiplayer is not currently active." % [self.name])
		return false
	
	if is_multiplayer_authority():
		push_error("Game \"%s\" | Failed to request to create game instance: only non-authority can request." % [self.name])
		return false
	
	if _local_player_game_instance_id != INVALID_GAME_INSTANCE_ID:
		push_error("Game \"%s\" | Failed to request to create game instance: already in a game instance." % [self.name])
		return false
	
	_rpc_request_create_instance.rpc_id(get_multiplayer_authority())
	return true

# Creates a game instance and adds the remote caller to the instance.
@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_create_instance() -> void:
	if !is_multiplayer_authority():
		return
	
	var player_id: int = multiplayer.get_remote_sender_id()
	
	# Make sure the player doesn't already belong to a game instance.
	for game_instance_id: int in _game_instances:
		if _game_instances[game_instance_id].has_player_id(player_id):
			return
	
	var game_instance_id: int = create_instance()
	_game_instances[game_instance_id].add_player_id(player_id)

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_instances(game_instance_ids: PackedInt32Array) -> void:
	for game_instance_id: int in _game_instances:
		if !game_instance_ids.has(game_instance_id):
			_remove_instance(game_instance_id)
	for game_instance_id: int in game_instance_ids:
		if !_game_instances.has(game_instance_id):
			_create_instance(game_instance_id)

func request_join_instance(game_instance_id: int) -> bool:
	if !multiplayer.has_multiplayer_peer():
		push_error("Game \"%s\" | Failed to request to join game instance ID '%d': multiplayer is not currently active." % [self.name, game_instance_id])
		return false
	
	if _local_player_game_instance_id != INVALID_GAME_INSTANCE_ID:
		push_error("Game \"%s\" | Failed to request to join game instance ID '%d': already in a game instance." % [self.name, game_instance_id])
		return false
	
	if !_game_instances.has(game_instance_id):
		push_error("Game \"%s\" | Failed to request to join game instance ID '%d': game instance does not exist." % [self.name, game_instance_id])
		return false
	
	if is_multiplayer_authority():
		var player_id: int = multiplayer.get_unique_id()
		if !_game_instances[game_instance_id].has_player_id(player_id):
			_game_instances[game_instance_id].add_player_id(multiplayer.get_unique_id())
		return true
	
	_rpc_request_join_instance.rpc_id(get_multiplayer_authority(), game_instance_id)
	return true

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_join_instance(game_instance_id: int) -> void:
	if !is_multiplayer_authority():
		return
	
	if !_game_instances.has(game_instance_id):
		return
	
	var player_id: int = multiplayer.get_remote_sender_id()
	
	# Make sure the player doesn't already belong to a game instance.
	for _game_instance_id: int in _game_instances:
		if _game_instances[_game_instance_id].has_player_id(player_id):
			return
	
	_game_instances[game_instance_id].add_player_id(player_id)

func request_quit_instance(game_instance_id: int) -> bool:
	if !multiplayer.has_multiplayer_peer():
		push_error("Game \"%s\" | Failed to request to quit game instance ID '%d': multiplayer is not currently active." % [self.name, game_instance_id])
		return false
	
	if _local_player_game_instance_id != INVALID_GAME_INSTANCE_ID:
		push_error("Game \"%s\" | Failed to request to quit game instance ID '%d': already in a game instance." % [self.name, game_instance_id])
		return false
	
	if is_multiplayer_authority():
		var player_id: int = multiplayer.get_unique_id()
		if _game_instances[game_instance_id].has_player_id(player_id):
			_game_instances[game_instance_id].remove_player_id(player_id)
		return true
	
	_rpc_request_quit_instance.rpc_id(get_multiplayer_authority(), game_instance_id)
	return true

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_quit_instance(game_instance_id: int) -> void:
	if !is_multiplayer_authority():
		return
	
	if !_game_instances.has(game_instance_id):
		return
	
	var player_id: int = multiplayer.get_remote_sender_id()
	
	if _game_instances[game_instance_id].has_player_id(player_id):
		_game_instances[game_instance_id].remove_player_id(player_id)

#endregion

func _set_state(state: State) -> void:
	if _state == state:
		return
	_state = state
	
	match _state:
		State.NONE:
			pass
		State.NAME:
			pass
		State.CONNECT:
			pass
		State.CONNECTING:
			pass
		State.HOME:
			pass
		State.WAIT:
			pass
		State.PLAY:
			pass
		State.HEADLESS:
			pass

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	multiplayer.peer_connected.connect(_on_multiplayer_peer_connected)
	multiplayer.peer_disconnected.connect(_on_multiplayer_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_multiplayer_server_connected)
	multiplayer.server_disconnected.connect(_on_multiplayer_server_disconnected)

func _on_multiplayer_peer_connected(player_id: int) -> void:
	if !_players.has(player_id):
		_players[player_id] = _PlayerData.new()

func _on_multiplayer_peer_disconnected(player_id: int) -> void:
	if _players.has(player_id):
		_players.erase(player_id)
	
	for game_instance_id: int in _game_instances:
		if _game_instances[game_instance_id].has_player_id(player_id):
			_game_instances[game_instance_id].remove_player_id(player_id)

func _on_multiplayer_server_connected() -> void:
	_rpc_request_set_player_name.rpc_id(get_multiplayer_authority(), _local_player_name)

func _on_multiplayer_server_disconnected() -> void:
	for game_instance_id: int in _game_instances:
		_game_instances[game_instance_id].queue_free()
	_game_instances.clear()
	_local_player_game_instance_id = INVALID_GAME_INSTANCE_ID

var connect_auto: bool = false
var _connect_auto: bool = false

var _name_submitted: bool = false

var _connect_submitted_host_offline: bool = false
var _connect_submitted_host_online: bool = false
var _connect_submitted_join: bool = false

var _home_submitted_join_instance: bool = false
var _home_submitted_join_instance_id: int = INVALID_GAME_INSTANCE_ID

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if is_multiplayer_authority():
		# Remove empty game instances.
		for game_instance_id: int in _game_instances:
			var game_instance: GameInstance = _game_instances[game_instance_id]
			if game_instance.is_empty() && !game_instance.persistent:
				remove_instance(game_instance_id)
	
	match _state:
		State.NONE:
			if DisplayServer.get_name() == "headless":
				if _network.host_server():
					_set_state(State.HEADLESS)
					var game_instance_id: int = create_instance()
					_game_instances[game_instance_id].persistent = true
				else:
					# TODO:
					get_tree().quit(1)
			else:
				_set_state(State.NAME)
		State.NAME:
			pass
			# TODO: on name submit, check if valid. if valid,
			if true:
				pass
				_set_state(State.CONNECT)
		State.CONNECT:
			# TODO: on connect to server:
			if _connect_submitted_host_offline:
				if _network.host_server_offline() == OK:
					_set_state(State.HOME)
			if _connect_submitted_join || (connect_auto && !_connect_auto):
				# TODO: Set auto connect via command line args.
				_connect_auto = true
				_connect_submitted_join = false
				
				_set_state(State.CONNECTING)
				if (await _network.join_server()) == OK:
					_set_state(State.HOME)
					_rpc_request_set_player_name.rpc_id(get_multiplayer_authority(), _local_player_name)
				else:
					_set_state(State.CONNECT)
		State.CONNECTING:
			pass
		State.HOME:
			# If no network connection is active (disconnected or stopped server), return to connect screen.
			if !_network.is_active():
				_set_state(State.CONNECT)
			
			if is_multiplayer_authority():
				pass
			
		State.WAIT:
			pass
		State.PLAY:
			pass
		State.HEADLESS:
			pass
