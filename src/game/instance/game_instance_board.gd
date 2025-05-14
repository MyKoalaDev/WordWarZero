@tool
extends Node

class _PlayerData:
	extends RefCounted
	var player_ready: bool = false
	var player_spectator: bool = false

## Indicates if this board should not be automatically deleted when this has no players.
var persistent: bool = false

var _force_sync_queue: Array[int] = []

func _force_sync_queue_add(player_id: int) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstanceBoard \"%s\" | Failed to force sync player ID \'%d\': unauthorized." % [self.name, player_id])
		return false
	
	if !has_player_id(player_id):
		push_error("GameInstanceBoard \"%s\" | Failed to force sync player ID \'%d\': player ID does not exist." % [self.name, player_id])
		return false
	
	if player_id == multiplayer.get_unique_id():
		push_error("GameInstanceBoard \"%s\" | Failed to force sync player ID \'%d\': cannot force sync self." % [self.name, player_id])
		return false
	
	if _force_sync_queue.has(player_id):
		return true
	
	_force_sync_queue.append(player_id)
	return true

func _force_sync(player_id: int) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstanceBoard \"%s\" | Failed to force sync player ID \'%d\': unauthorized." % [self.name, player_id])
		return false
	
	if !has_player_id(player_id):
		push_error("GameInstanceBoard \"%s\" | Failed to force sync player ID \'%d\': player ID does not exist." % [self.name, player_id])
		return false
	
	if player_id == multiplayer.get_unique_id():
		push_error("GameInstanceBoard \"%s\" | Failed to force sync player ID \'%d\': cannot force sync self." % [self.name, player_id])
		return false
	
	_rpc_set_board_name.rpc_id(player_id, _board_name)
	_rpc_set_board_public.rpc_id(player_id, _board_public)
	
	for _player_id: int in _players:
		var player_data: _PlayerData = _players[_player_id]
		if player_id != _player_id:
			_rpc_add_player_id.rpc_id(player_id, _player_id)
		_rpc_set_player_ready.rpc_id(player_id, player_data.player_ready)
		_rpc_set_player_spectator.rpc_id(player_id, player_data.player_spectator)
	
	return true

#region Player

var _players: Dictionary[int, _PlayerData] = {}

func has_player_ids() -> bool:
	return !_players.is_empty()

func has_player_id(player_id: int) -> bool:
	return _players.has(player_id)

#region Player ID

signal player_id_added(player_id: int)
signal player_id_removed(player_id: int)

func get_player_ids() -> Array[int]:
	var player_ids: Array[int] = _players.keys() as Array[int]
	player_ids.make_read_only()
	return player_ids

func _add_player_id(player_id: int) -> bool:
	if _players.has(player_id):
		push_error("GameInstanceBoard \"%s\" | Failed to add player ID \'%d\': player ID already exists." % [self.name, player_id])
		return false
	
	_players[player_id] = _PlayerData.new()
	
	if is_multiplayer_authority():
		var local_player_id: int = multiplayer.get_unique_id()
		for _player_id: int in _players:
			if _player_id != local_player_id:
				_rpc_add_player_id.rpc_id(_player_id, player_id)
		
		_force_sync_queue_add(player_id)
	
	player_id_added.emit(player_id)
	return true

@rpc("authority", "call_remote", "reliable", 0)
func add_player_id(player_id: int) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstanceBoard \"%s\" | Failed to add player ID \'%d\': unauthorized." % [self.name, player_id])
		return false
	
	return _add_player_id(player_id)

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_add_player_id(player_id: int) -> void:
	_add_player_id(player_id)

func _remove_player_id(player_id: int) -> bool:
	if !has_player_id(player_id):
		push_error("GameInstanceBoard \"%s\" | Failed to remove player ID \'%d\': could not find player ID." % [self.name, player_id])
		return false
	
	_players.erase(player_id)
	
	if is_multiplayer_authority():
		var local_player_id: int = multiplayer.get_unique_id()
		for _player_id: int in _players:
			if _player_id != local_player_id:
				_rpc_remove_player_id.rpc_id(_player_id, player_id)
		
		if player_id != local_player_id:
			_rpc_remove_player_id.rpc_id(player_id, player_id)
	
	player_id_removed.emit(player_id)
	return true

func remove_player_id(player_id: int) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstanceBoard \"%s\" | Failed to remove player ID \'%d\': unauthorized." % [self.name, player_id])
		return false
	
	return _remove_player_id(player_id)

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_remove_player_id(player_id: int) -> void:
	_remove_player_id(player_id)

#endregion
#region Player Ready

signal player_ready_changed(player_id: int, player_ready: bool)

func get_all_players_ready() -> bool:
	if _players.is_empty():
		return false
	
	for _player_id: int in _players:
		if !_players[_player_id].player_spectator && !_players[_player_id].player_ready:
			return false
	
	return true

func _set_all_players_ready(player_ready: bool) -> bool:
	var local_player_id: int = multiplayer.get_unique_id()
	for _player_id: int in _players:
		if _players[_player_id].player_ready != player_ready:
			_players[_player_id].player_ready = player_ready
			player_ready_changed.emit(_player_id, player_ready)
		
		if is_multiplayer_authority() && (_player_id != local_player_id):
			_rpc_set_all_players_ready.rpc_id(_player_id, player_ready)
	
	return true

func set_all_players_ready(player_ready: bool) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstanceBoard \"%s\" | Failed to set all players ready to \'%s\': unauthorized." % [self.name, str(player_ready)])
		return false
	
	return _set_all_players_ready(player_ready)

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_all_players_ready(player_ready: bool) -> void:
	_set_all_players_ready(player_ready)

func get_player_ready(player_id: int) -> bool:
	if !has_player_id(player_id):
		push_error("GameInstanceBoard \"%s\" | Failed to get player ready for player ID '%d': could not find player ID." % [self.name, player_id])
		return false
	
	return _players[player_id].player_ready

func _set_player_ready(player_id: int, player_ready: bool) -> bool:
	if !has_player_id(player_id):
		push_error("GameInstanceBoard \"%s\" | Failed to set player ready to \'%s\' for player ID \'%d\': could not find player ID." % [self.name, str(player_ready), player_id])
		return false
	
	if _players[player_id].player_ready == player_ready:
		return true
	
	_players[player_id].player_ready = player_ready
	
	if is_multiplayer_authority():
		var local_player_id: int = multiplayer.get_unique_id()
		for _player_id: int in _players:
			if _player_id != local_player_id:
				_rpc_set_player_ready.rpc_id(_player_id, player_id, player_ready)
	
	player_ready_changed.emit(player_id, player_ready)
	return true

func set_player_ready(player_id: int, player_ready: bool) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstanceBoard \"%s\" | Failed to set player ready to \'%s\' for player ID \'%d\': unauthorized." % [self.name, str(player_ready), player_id])
		return false
	
	return _set_player_ready(player_id, player_ready)

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_player_ready(player_id: int, player_ready: bool) -> void:
	_set_player_ready(player_id, player_ready)

func request_set_local_player_ready(player_ready: bool) -> bool:
	if is_multiplayer_authority():
		push_error("GameInstanceBoard \"%s\" | Failed to request to set local player ready to \'%s\': authority may not request." % [self.name, str(player_ready)])
		return false
	
	var player_id: int = multiplayer.get_unique_id()
	if !has_player_id(player_id):
		push_error("GameInstanceBoard \"%s\" | Failed to request to set local player ready to \'%s\': could not find local player ID." % [self.name, str(player_ready), player_id])
		return false
	
	if _players[player_id].player_ready == player_ready:
		return true
	
	_rpc_request_set_local_player_ready.rpc_id(get_multiplayer_authority(), player_ready)
	return true

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_set_local_player_ready(player_ready: bool) -> void:
	var player_id: int = multiplayer.get_remote_sender_id()
	if !is_multiplayer_authority():
		push_error("GameInstanceBoard \"%s\" | (RPC) Failed to process request from player ID \'%d\' to set local player name to \'%s\': non authority received request." % [self.name, player_id, str(player_ready)])
		return
	
	_set_player_ready(player_id, player_ready)

#endregion
#region Player Spectator

signal player_spectator_changed(player_id: int, player_spectator: bool)

func get_player_spectator(player_id: int) -> bool:
	if !has_player_id(player_id):
		push_error("GameInstanceBoard \"%s\" | Failed to get player spectator for player ID '%d': could not find player ID." % [self.name, player_id])
		return false
	
	return _players[player_id].player_spectator

func _set_player_spectator(player_id: int, player_spectator: bool) -> bool:
	if !has_player_id(player_id):
		push_error("GameInstanceBoard \"%s\" | Failed to set player spectator to \'%s\' for player ID \'%d\': could not find player ID." % [self.name, str(player_spectator), player_id])
		return false
	
	if _players[player_id].player_spectator == player_spectator:
		return true
	
	_players[player_id].player_spectator = player_spectator
	
	if is_multiplayer_authority():
		var local_player_id: int = multiplayer.get_unique_id()
		for _player_id: int in _players:
			if _player_id != local_player_id:
				_rpc_set_player_spectator.rpc_id(_player_id, player_id, player_spectator)
	
	player_spectator_changed.emit(player_id, player_spectator)
	return true

func set_player_spectator(player_id: int, player_spectator: bool) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstanceBoard \"%s\" | Failed to set player spectator to \'%s\' for player ID \'%d\': unauthorized." % [self.name, str(player_spectator), player_id])
		return false
	
	return _set_player_spectator(player_id, player_spectator)

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_player_spectator(player_id: int, player_spectator: bool) -> void:
	_set_player_spectator(player_id, player_spectator)

func request_set_local_player_spectator(player_spectator: bool) -> bool:
	if is_multiplayer_authority():
		push_error("GameInstanceBoard \"%s\" | Failed to request to set local player spectator to \'%s\': authority may not request." % [self.name, str(player_spectator)])
		return false
	
	var player_id: int = multiplayer.get_unique_id()
	if !has_player_id(player_id):
		push_error("GameInstanceBoard \"%s\" | Failed to request to set local player spectator to \'%s\': could not find local player ID." % [self.name, str(player_spectator), player_id])
		return false
	
	if _players[player_id].player_spectator == player_spectator:
		return true
	
	_rpc_request_set_local_player_spectator.rpc_id(get_multiplayer_authority(), player_spectator)
	return true

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_set_local_player_spectator(player_spectator: bool) -> void:
	var player_id: int = multiplayer.get_remote_sender_id()
	if !is_multiplayer_authority():
		push_error("GameInstanceBoard \"%s\" | (RPC) Failed to process request from player ID \'%d\' to set local player name to \'%s\': non authority received request." % [self.name, player_id, str(player_spectator)])
		return
	
	_set_player_spectator(player_id, player_spectator)

#endregion
#endregion
#region Board
#region Board Name

signal board_name_changed(board_name_old: String, board_name_new: String)

var _board_name: String = ""

func get_board_name() -> String:
	return _board_name

func _set_board_name(board_name: String) -> bool:
	if  _board_name == board_name:
		return true
	
	var board_name_old: String = _board_name
	var board_name_new: String = board_name
	
	_board_name = board_name
	
	var local_player_id: int = multiplayer.get_unique_id()
	for _player_id: int in _players:
		if _player_id != local_player_id:
			_rpc_set_board_name.rpc_id(_player_id, _board_name)
	
	board_name_changed.emit(board_name_old, board_name_new)
	return true

func set_board_name(board_name: String) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstanceBoard \"%s\" | Failed to set board name to \'%s\': only the authority can set." % [self.name, board_name])
		return false
	
	return _set_board_name(board_name)

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_board_name(board_name: String) -> void:
	_set_board_name(board_name)

#endregion
#region Board Public

signal board_public_changed(board_public: bool)

var _board_public: bool = false

func _set_board_public(board_public: bool) -> bool:
	if _board_public == board_public:
		return true
	
	_board_public = board_public
	
	if is_multiplayer_authority():
		var local_player_id: int = multiplayer.get_unique_id()
		for _player_id: int in _players:
			if _player_id != local_player_id:
				_rpc_set_board_public.rpc_id(_player_id, _board_public)
	
	board_public_changed.emit(_board_public)
	return true

func set_board_public(board_public: bool) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstanceBoard \"%s\" | Failed to set board public to \'%s\': only the authority can set." % [self.name, board_public])
		return false
	
	return _set_board_public(board_public)

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_board_public(board_public: bool) -> void:
	_set_board_public(board_public)

#endregion
#region Board Password

var _board_password: String = ""

func check_board_password(board_password: String) -> bool:
	return _board_password == board_password

func set_board_password(board_password: String) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstanceBoard \"%s\" | Failed to set board password: only the authority can set." % [self.name])
		return false
	
	if _board_password == board_password:
		return true
	
	_board_password = board_password
	return true

#endregion
#region Board Play

signal board_play_started()
signal board_play_stopped()

var _board_play: bool = false

func _set_board_play(board_play: bool) -> bool:
	if _board_play == board_play:
		return false
	
	_board_play = board_play
	
	if _board_play:
		board_play_started.emit()
	else:
		board_play_stopped.emit()
	
	if is_multiplayer_authority():
		var local_player_id: int = multiplayer.get_unique_id()
		for _player_id: int in _players:
			if _player_id != local_player_id:
				_rpc_set_board_play.rpc_id(_player_id, _board_play)
	
	return true

func set_board_play(board_play: bool) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstanceLobbyBoardLobbyBoard \"%s\" | Failed to set board_play to \'%s\': unauthorized." % [self.name, str(board_play)])
		return false
	
	return _set_board_play(board_play)

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_board_play(board_play: bool) -> void:
	_set_board_play(board_play)

#endregion
#endregion

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	for player_id: int in _force_sync_queue:
		_force_sync(player_id)
	_force_sync_queue.clear()
	
