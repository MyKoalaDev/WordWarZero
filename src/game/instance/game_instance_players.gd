@tool
extends Node

class _PlayerData:
	extends RefCounted
	var player_name: String = "Player"
	var color: Color = Color.WHITE

func _force_sync(player_id: int) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstancePlayers \"%s\" | Failed to force sync player ID \'%d\': unauthorized." % [self.name, player_id])
		return false
	
	if !_players.has(player_id):
		push_error("GameInstancePlayers \"%s\" | Failed to force sync player ID \'%d\': player ID does not exist." % [self.name, player_id])
		return false
	
	if player_id == multiplayer.get_unique_id():
		push_error("GameInstancePlayers \"%s\" | Failed to force sync player ID \'%d\': cannot force sync self." % [self.name, player_id])
		return false
	
	for _player_id: int in _players:
		var player_data: _PlayerData = _players[_player_id]
		_rpc_set_player_name.rpc_id(player_id, player_data.player_name)
	
	return true

#region Player IDs

signal player_id_added(player_id: int)
signal player_id_removed(player_id: int)

var _players: Dictionary[int, _PlayerData] = {}

func get_player_ids() -> Array[int]:
	var player_ids: Array[int] = _players.keys() as Array[int]
	player_ids.make_read_only()
	return player_ids

func _add_player_id(player_id: int) -> bool:
	if _players.has(player_id):
		push_error("GameInstancePlayers \"%s\" | Failed to add player ID \'%d\': player ID already exists." % [self.name, player_id])
		return false
	
	_players[player_id] = _PlayerData.new()
	
	if is_multiplayer_authority():
		var local_player_id: int = multiplayer.get_unique_id()
		for _player_id: int in _players:
			if _player_id != local_player_id:
				_rpc_add_player_id.rpc_id(_player_id, player_id)
		
		_force_sync(player_id)
	
	player_id_added.emit(player_id)
	return true

func add_player_id(player_id: int) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstancePlayers \"%s\" | Failed to add player ID \'%d\': unauthorized." % [self.name, player_id])
		return false
	
	return _add_player_id(player_id)

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_add_player_id(player_id: int) -> void:
	_add_player_id(player_id)

func _remove_player_id(player_id: int) -> bool:
	if !_players.has(player_id):
		push_error("GameInstancePlayers \"%s\" | Failed to remove player ID \'%d\': could not find player ID." % [self.name, player_id])
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
		push_error("GameInstancePlayers \"%s\" | Failed to remove player ID \'%d\': unauthorized." % [self.name, player_id])
		return false
	
	return _remove_player_id(player_id)

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_remove_player_id(player_id: int) -> void:
	_remove_player_id(player_id)

#endregion
#region Player Name

signal player_name_changed(player_id: int, player_name_old: String, player_name_new: String)

func get_player_name(player_id: int) -> String:
	if !_players.has(player_id):
		push_error("GameInstancePlayers \"%s\" | Failed to get player name for player ID '%d': could not find player ID." % [self.name, player_id])
		return ""
	
	return _players[player_id].player_name

func _set_player_name(player_id: int, player_name: String) -> bool:
	if !_players.has(player_id):
		push_error("GameInstancePlayers \"%s\" | Failed to set player name to \'%s\' for player ID \'%d\': could not find player ID." % [self.name, player_name, player_id])
		return false
	
	if _players[player_id].player_name == player_name:
		return true
	
	var player_name_old: String = _players[player_id].player_name
	var player_name_new: String = player_name
	
	_players[player_id].player_name = player_name
	
	if is_multiplayer_authority():
		var local_player_id: int = multiplayer.get_unique_id()
		for _player_id: int in _players:
			if _player_id != local_player_id:
				_rpc_set_player_name.rpc_id(_player_id, player_id, player_name)
		
		player_name_changed.emit(player_id, player_name_old, player_name_new)
	
	return true

func set_player_name(player_id: int, player_name: String) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstancePlayers \"%s\" | Failed to set player name to \'%s\' for player ID \'%d\': unauthorized." % [self.name, player_name, player_id])
		return false
	
	return _set_player_name(player_id, player_name)

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_player_name(player_id: int, player_name: String) -> void:
	_set_player_name(player_id, player_name)

func request_set_local_player_name(player_name: String) -> bool:
	if is_multiplayer_authority():
		push_error("GameInstancePlayers \"%s\" | Failed to request to set local player_name to \'%s\': unauthorized." % [self.name, player_name])
		return false
	
	var player_id: int = multiplayer.get_unique_id()
	
	if _players[player_id].player_name == player_name:
		return true
	
	_rpc_request_set_local_player_name.rpc_id(get_multiplayer_authority(), player_name)
	return true

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_set_local_player_name(player_name: String) -> void:
	var player_id: int = multiplayer.get_remote_sender_id()
	if !is_multiplayer_authority():
		push_error("GameInstancePlayers \"%s\" | (RPC) Failed to process request from player ID \'%d\' to set local player name to \'%s\': non authority received request." % [self.name, player_id, player_name])
		return
	
	_set_player_name(player_id, player_name)

#endregion
