@tool
extends Node

# Node created upon hosting or joining a game server. Represents all the state of a single game.
# This node will have a unique scene tree name synced across clients (most likely a game instance id integer).
# Stores all important information for a game (player and board data).

# TODO:
# where are submissions processed?
# game_instance should retain all game related data (since server will instantiate multiple GameInstance for each game)
# must store board tiles here too
# need rpcs for clearing tiles and also mass sending tile data (should be same as tile submission anyways)

# TODO:
# Game.gd:
# Server creates new GameInstance, assigns unique name
# Server rpc -> Client to create new GameInstance, passes unique name
# Server adds player to GameInstance via add_player. this then rpc syncs with client
# rpcs must be ordered to guarantee GameInstance exists on client

# TODO: Game instance list (lobby system)
# TODO: bake leaderboard data into array (bake data such as player name and points)
# TODO: Host player functionality (handles game instance settings such as turn count, turn timer, start game, etc.)

class PlayerData:
	extends RefCounted
	# Server-managed fields.
	var name: String = "Player"
	var ready: bool = false
	var spectator: bool = false
	var submitted: bool = false
	var points: int = 0
	## Each byte is an encoded tile.
	var tiles: Array[Tile] = []
	
	# Client-managed fields.
	var place: int = 0

const DEFAULT_TURN_COUNT: int = 8
const DEFAULT_TURN_TIMER: float = 60.0

signal updated()

## Set to true on updated signal.
var _dirty: bool = false

## Indicates if game play is active and looping.
var _play: bool = false

# TODO: Leaderboard baking.
var _leaderboard_names: PackedStringArray = PackedStringArray()
var _leaderboard_points: PackedInt64Array = PackedInt64Array()

## Force synchronize all data with remote player (authority only).
# TODO: Compress into a single PackedByteArray RPC.
func force_sync(player_id: int) -> bool:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to force sync with player ID '%d': multiplayer is not active." % [self.name, player_id])
		return false
	
	if !_players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to force sync with player ID '%d': player ID does not exist." % [self.name, player_id])
		return false
	
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to force sync with player ID '%d': only the authority can force sync." % [self.name, player_id])
		return false
	
	if player_id == multiplayer.get_unique_id():
		push_error("GameInstance '<%s>' | Failed to force sync with player ID '%d': cannot force sync with self." % [self.name, player_id])
		return false
	
	_rpc_set_play.rpc_id(player_id, _play)
	
	_rpc_set_turn_count.rpc_id(player_id, _turn_count)
	_rpc_set_turn_count_max.rpc_id(player_id, _turn_count_max)
	_rpc_set_turn_timer.rpc_id(player_id, _turn_timer)
	_rpc_set_turn_timer_max.rpc_id(player_id, _turn_timer_max)
	
	_rpc_set_tile_board.rpc_id(player_id, encode_tile_board(_tile_board))
	
	for _player_id: int in _players:
		var player_data: PlayerData = _players[_player_id]
		_rpc_set_player_name.rpc_id(player_id, _player_id, player_data.name)
		_rpc_set_player_ready.rpc_id(player_id, _player_id, player_data.ready)
		_rpc_set_player_spectator.rpc_id(player_id, _player_id, player_data.spectator)
		_rpc_set_player_submitted.rpc_id(player_id, _player_id, player_data.submitted)
		# NOTE: Each player should only know about their own tiles.
		#_rpc_set_player_tiles.rpc_id(player_id, _player_id, player_data.tiles)
		_rpc_set_player_points.rpc_id(player_id, _player_id, player_data.points)
	
	return true

#region Play

func set_play(play: bool) -> bool:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to set play to '%s': multiplayer is not active." % [self.name, str(play)])
		return false
	
	if _play == play:
		push_error("GameInstance '<%s>' | Failed to set play to '%s': play already matches." % [self.name, str(play)])
		return false
	
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to set play to '%s': only the authority can set play." % [self.name, str(play)])
		return false
	
	_play = play
	
	# Sync data with all players.
	for player_id: int in _players:
		if player_id != multiplayer.get_unique_id():
			_rpc_set_play.rpc_id(player_id, play)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_play(play: bool) -> void:
	_play = play
	
	updated.emit()

#endregion
#region Turn

var _turn_count: int = 0

func set_turn_count(turn_count: int) -> bool:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to set turn count to '%d': multiplayer is not active." % [self.name, turn_count])
		return false
	
	if _turn_count == turn_count:
		push_error("GameInstance '<%s>' | Failed to set turn count to '%d': turn count already matches." % [self.name, turn_count])
		return false
	
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to set turn count to '%d': only the authority can set turn count." % [self.name, turn_count])
		return false
	
	_turn_count = turn_count
	
	# Sync data with all players.
	for player_id: int in _players:
		if player_id != multiplayer.get_unique_id():
			_rpc_set_turn_count.rpc_id(player_id, turn_count)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_turn_count(turn_count: int) -> void:
	_turn_count = turn_count
	
	updated.emit()

var _turn_count_max: int = DEFAULT_TURN_COUNT

func set_turn_count_max(turn_count_max: int) -> bool:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to set turn count max to '%d': multiplayer is not active." % [self.name, turn_count_max])
		return false
	
	if _turn_count_max == turn_count_max:
		push_error("GameInstance '<%s>' | Failed to set turn count max to '%d': turn count max already matches." % [self.name, turn_count_max])
		return false
	
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to set turn count max to '%d': only the authority can set turn count max." % [self.name, turn_count_max])
		return false
	
	_turn_count_max = turn_count_max
	
	# Sync data with all players.
	for player_id: int in _players:
		if player_id != multiplayer.get_unique_id():
			_rpc_set_turn_count_max.rpc_id(player_id, turn_count_max)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_turn_count_max(turn_count_max: int) -> void:
	_turn_count_max = turn_count_max
	
	updated.emit()

var _turn_timer: float = 0.0

func set_turn_timer(turn_timer: int) -> bool:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to set turn timer to '%d': multiplayer is not active." % [self.name, turn_timer])
		return false
	
	if _turn_timer == turn_timer:
		push_error("GameInstance '<%s>' | Failed to set turn timer to '%d': turn timer already matches." % [self.name, turn_timer])
		return false
	
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to set turn timer to '%d': only the authority can set turn timer." % [self.name, turn_timer])
		return false
	
	_turn_timer = turn_timer
	
	# Sync data with all players.
	for player_id: int in _players:
		if player_id != multiplayer.get_unique_id():
			_rpc_set_turn_timer.rpc_id(player_id, turn_timer)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_turn_timer(turn_timer: int) -> void:
	_turn_timer = turn_timer

var _turn_timer_max: float = DEFAULT_TURN_TIMER

func set_turn_timer_max(turn_timer_max: int) -> bool:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to set turn timer max to '%d': multiplayer is not active." % [self.name, turn_timer_max])
		return false
	
	if _turn_timer_max == turn_timer_max:
		push_error("GameInstance '<%s>' | Failed to set turn timer max to '%d': turn timer max already matches." % [self.name, turn_timer_max])
		return false
	
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to set turn timer max to '%d': only the authority can set turn timer max." % [self.name, turn_timer_max])
		return false
	
	_turn_timer_max = turn_timer_max
	
	# Sync data with all players.
	for player_id: int in _players:
		if player_id != multiplayer.get_unique_id():
			_rpc_set_turn_timer_max.rpc_id(player_id, turn_timer_max)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_turn_timer_max(turn_timer_max: int) -> void:
	_turn_timer_max = turn_timer_max

#endregion
#region Tile Board

signal tile_board_set()
signal tile_board_cleared()
signal tile_board_tile_added(tile_position: Vector2i, tile_data: int)

## Hashmap of tile coordinates to encoded tile data. (These are submitted tiles locked onto the board).
var _tile_board: Dictionary[Vector2i, int] = {}

func get_tile_board() -> Dictionary[Vector2i, int]:
	return _tile_board.duplicate()

func set_tile_board(tile_board: Dictionary[Vector2i, int]) -> bool:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to set tile board: multiplayer is not active." % [self.name])
		return false
	
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to set tile board: only the authority can set tile board." % [self.name])
		return false
	
	_tile_board = tile_board
	
	var bytes: PackedByteArray = encode_tile_board(tile_board)
	for _player_id: int in _players:
		if _player_id != multiplayer.get_unique_id():
			_rpc_set_tile_board.rpc_id(_player_id, bytes)
	
	tile_board_set.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_tile_board(bytes: PackedByteArray) -> void:
	_tile_board = decode_tile_board(bytes)
	
	tile_board_set.emit()

func clear_tile_board() -> bool:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to clear tile board: multiplayer is not active." % [self.name])
		return false
	
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to clear tile board: only the authority can clear tile board." % [self.name])
		return false
	
	_tile_board.clear()
	
	for _player_id: int in _players:
		if _player_id != multiplayer.get_unique_id():
			_rpc_clear_tile_board.rpc_id(_player_id)
	
	tile_board_cleared.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_clear_tile_board() -> void:
	_tile_board.clear()
	
	tile_board_cleared.emit()

func add_tile_board_tile(tile_position: Vector2i, tile_data: int) -> bool:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to add tile board tile: multiplayer is not active." % [self.name])
		return false
	
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to add tile board tile: only the authority can add tile board tile." % [self.name])
		return false
	
	if _tile_board.has(tile_position):
		push_error("GameInstance '<%s>' | Failed to add tile board tile: a tile already exists at (%d, %d)." % [self.name, tile_position.x, tile_position.y])
		return false
	
	_tile_board[tile_position] = tile_data
	
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(5)
	for _player_id: int in _players:
		if _player_id != multiplayer.get_unique_id():
			_rpc_add_tile_board_tile(bytes)
	
	tile_board_tile_added.emit(tile_position, tile_data)
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_add_tile_board_tile(bytes: PackedByteArray) -> void:
	var tile_position: Vector2i = Vector2i(bytes.decode_s16(0), bytes.decode_s16(2))
	var tile_data: int = bytes.decode_u8(4)
	_tile_board[tile_position] = tile_data
	
	tile_board_tile_added.emit(tile_position, tile_data)

# NOTE: TileMap coordinates are limited to 16 bit signed integers.
# tile position x: 2 bytes (16 bit signed int)
# tile position y: 2 bytes (16 bit signed int)
# tile face: 1 byte (8 bit unsigned int)
static func encode_tile_board(tile_board: Dictionary[Vector2i, int]) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(tile_board.size() * 5)
	var index: int = 0
	for tile_position: Vector2i in tile_board:
		bytes.encode_s16(index + 0, tile_position.x)
		bytes.encode_s16(index + 2, tile_position.y)
		bytes.encode_u8(index + 4, tile_board[tile_position])
		index += 5
	return bytes

static func decode_tile_board(bytes: PackedByteArray) -> Dictionary[Vector2i, int]:
	if bytes.size() % 5 != 0:
		return {}
	
	var tile_board: Dictionary[Vector2i, int] = {}
	var index: int = 0
	while index < bytes.size():
		var tile_position: Vector2i = Vector2i(bytes.decode_s16(index + 0), bytes.decode_s16(index + 2))
		var tile_data: int = bytes.decode_u8(index + 4)
		tile_board[tile_position] = tile_data
		index += 5
	return tile_board

#endregion
#region Player

## Hashmap of player IDs (multiplayer peer id) to player data.
var _players: Dictionary[int, PlayerData] = {}

#region Player ID

func get_player_ids() -> Array[int]:
	return _players.keys()

func has_player_id(player_id: int) -> bool:
	return _players.has(player_id)

func add_player_id(player_id: int) -> bool:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to add player ID '%d': multiplayer is not active." % [self.name, player_id])
		return false
	
	if _players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to add player ID '%d': player ID already exists." % [self.name, player_id])
		return false
	
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to add player ID '%d': only the authority can add player ID." % [self.name, player_id])
		return false
	
	_players[player_id] = PlayerData.new()
	
	for _player_id: int in _players:
		if _player_id != multiplayer.get_unique_id():
			_rpc_add_player_id.rpc_id(_player_id, player_id)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_add_player_id(player_id: int) -> void:
	if !_players.has(player_id):
		_players[player_id] = PlayerData.new()
	
	updated.emit()

func remove_player_id(player_id: int) -> bool:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to remove player ID '%d': multiplayer is not active." % [self.name, player_id])
		return false
	
	if !_players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to remove player ID '%d': player ID does not exist." % [self.name, player_id])
		return false
	
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to remove player ID '%d': only the authority can remove player ID." % [self.name, player_id])
		return false
	
	_players.erase(player_id)
	
	for _player_id: int in _players:
		if _player_id != multiplayer.get_unique_id():
			_rpc_remove_player_id.rpc_id(_player_id, player_id)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_remove_player_id(player_id: int) -> void:
	if _players.has(player_id):
		_players.erase(player_id)
	
	updated.emit()

#endregion
#region Player Name

func get_local_player_name() -> String:
	return get_player_name(multiplayer.get_unique_id())

func set_local_player_name(player_name: String) -> void:
	set_player_name(multiplayer.get_unique_id(), player_name)

func get_player_name(player_id: int) -> String:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to get player name for player ID '%d': multiplayer is not active." % [self.name, player_id])
		return ""
	
	if !_players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to get player name for player ID '%d': could not find player ID." % [self.name, player_id])
		return ""
	
	return _players[player_id].name

func set_player_name(player_id: int, player_name: String) -> bool:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to set player name to '%s' for player ID '%d': multiplayer is not active." % [self.name, player_name, player_id])
		return false
	
	if !_players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to set player name to '%s' for player ID '%d': could not find player ID." % [self.name, player_name, player_id])
		return false
	
	if _players[player_id].name == player_name:
		push_error("GameInstance '<%s>' | Failed to set player name to '%s' for player ID '%d': player name already matches." % [self.name, player_name, player_id])
		return false
	
	if !Game.is_valid_player_name(player_name):
		push_error("GameInstance '<%s>' | Failed to set player name to '%s' for player ID '%d': player name is not valid." % [self.name, player_name, player_id])
		return false
	
	if !is_multiplayer_authority():
		if player_id != multiplayer.get_unique_id():
			push_error("GameInstance '<%s>' | Failed to set player name to '%s' for player ID '%d': only the authority can set remote player name." % [self.name, player_name, player_id])
			return false
		
		_rpc_request_set_local_player_name.rpc_id(get_multiplayer_authority(), player_name)
		return true
	
	_players[player_id].name = player_name
	
	# Sync data with all players.
	for _player_id: int in _players:
		if _player_id != multiplayer.get_unique_id():
			_rpc_set_player_name.rpc_id(_player_id, player_name)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_player_name(player_id: int, player_name: String) -> void:
	if _players.has(player_id):
		_players[player_id].name = player_name
	
	updated.emit()

@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_set_local_player_name(player_name: String) -> void:
	var player_id: int = multiplayer.get_remote_sender_id()
	if is_multiplayer_authority():
		set_player_name(player_id, player_name)

#endregion
#region Player Ready

func get_all_players_ready() -> bool:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to get all players ready: multiplayer is not active." % [self.name])
		return false
	
	if _players.is_empty():
		return false
	
	for player_id: int in _players:
		if !_players[player_id].spectator && !_players[player_id].ready:
			return false
	
	return true

func set_all_players_ready(player_ready: bool) -> bool:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to set all players ready to '%s': multiplayer is not active." % [self.name, str(player_ready)])
		return false
	
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to set all players ready to '%s': only the authority can set all players ready." % [self.name, str(player_ready)])
		return false
	
	for player_id: int in _players:
		_players[player_id].ready = player_ready
	
	for player_id: int in _players:
		_rpc_set_all_players_ready.rpc_id(player_id, player_ready)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_all_players_ready(player_ready: bool) -> void:
	for player_id: int in _players:
		_players[player_id].ready = player_ready
	
	updated.emit()

func get_local_player_ready() -> bool:
	return get_player_ready(multiplayer.get_unique_id())

func set_local_player_ready(player_ready: bool) -> void:
	set_player_ready(multiplayer.get_unique_id(), player_ready)

func get_player_ready(player_id: int) -> bool:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to get player ready for player ID '%d': multiplayer is not active." % [self.name,player_id])
		return false
	
	if !_players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to get player ready for player ID '%d': could not find player ID." % [self.name, player_id])
		return false
	
	return _players[player_id].ready

func set_player_ready(player_id: int, player_ready: bool) -> bool:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to set player ready to '%s' for player ID '%d': multiplayer is not active." % [self.name, player_ready, player_id])
		return false
	
	if !_players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to set player ready to '%s' for player ID '%d': could not find player ID." % [self.name, player_ready, player_id])
		return false
	
	if _players[player_id].ready == player_ready:
		push_error("GameInstance '<%s>' | Failed to set player ready to '%s' for player ID '%d': player ready already matches." % [self.name, player_ready, player_id])
		return false
	
	if !is_multiplayer_authority():
		if player_id != multiplayer.get_unique_id():
			push_error("GameInstance '<%s>' | Failed to set player ready to '%s' for player ID '%d': only the authority can set remote player ready." % [self.name, player_ready, player_id])
			return false
		
		_rpc_request_set_local_player_ready.rpc_id(get_multiplayer_authority(), player_ready)
		return true
	
	_players[player_id].ready = player_ready
	for _player_id: int in _players:
		if _player_id != multiplayer.get_unique_id():
			_rpc_set_player_ready.rpc_id(_player_id, player_ready)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_player_ready(player_id: int, player_ready: bool) -> void:
	if _players.has(player_id):
		_players[player_id].ready = player_ready
	
	updated.emit()

@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_set_local_player_ready(player_ready: bool) -> void:
	var player_id: int = multiplayer.get_remote_sender_id()
	if is_multiplayer_authority():
		set_player_ready(player_id, player_ready)

#endregion
#region Player Spectator

func get_local_player_spectator() -> bool:
	return get_player_spectator(multiplayer.get_unique_id())

func set_local_player_spectator(player_spectator: bool) -> void:
	set_player_spectator(multiplayer.get_unique_id(), player_spectator)

func get_player_spectator(player_id: int) -> bool:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to get player spectator for player ID '%d': multiplayer is not active." % [self.name,player_id])
		return false
	
	if !_players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to get player spectator for player ID '%d': could not find player ID." % [self.name, player_id])
		return false
	
	return _players[player_id].spectator

func set_player_spectator(player_id: int, player_spectator: bool) -> bool:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to set player spectator to '%s' for player ID '%d': multiplayer is not active." % [self.name, player_spectator, player_id])
		return false
	
	if !_players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to set player spectator to '%s' for player ID '%d': could not find player ID." % [self.name, player_spectator, player_id])
		return false
	
	if _players[player_id].spectator == player_spectator:
		push_error("GameInstance '<%s>' | Failed to set player spectator to '%s' for player ID '%d': player spectator already matches." % [self.name, player_spectator, player_id])
		return false
	
	if !is_multiplayer_authority():
		if player_id != multiplayer.get_unique_id():
			push_error("GameInstance '<%s>' | Failed to set player spectator to '%s' for player ID '%d': only the authority can set remote player spectator." % [self.name, player_spectator, player_id])
			return false
		
		_rpc_request_set_local_player_spectator.rpc_id(get_multiplayer_authority(), player_spectator)
		return true
	
	_players[player_id].spectator = player_spectator
	for _player_id: int in _players:
		if _player_id != multiplayer.get_unique_id():
			_rpc_set_player_spectator.rpc_id(_player_id, player_spectator)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_player_spectator(player_id: int, player_spectator: bool) -> void:
	if _players.has(player_id):
		_players[player_id].spectator = player_spectator
	
	updated.emit()

@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_set_local_player_spectator(player_spectator: bool) -> void:
	var player_id: int = multiplayer.get_remote_sender_id()
	if is_multiplayer_authority():
		set_player_spectator(player_id, player_spectator)

#endregion
#region Player Submitted

func get_all_players_submitted() -> bool:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to get all players submitted: multiplayer is not active." % [self.name])
		return false
	
	if _players.is_empty():
		return false
	
	for player_id: int in _players:
		if !_players[player_id].spectator && !_players[player_id].submitted:
			return false
	
	return true

func set_all_players_submitted(player_submitted: bool) -> bool:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to set all players submitted to '%s': multiplayer is not active." % [self.name, str(player_submitted)])
		return false
	
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to set all players submitted to '%s': only the authority can set all players submitted." % [self.name, str(player_submitted)])
		return false
	
	for player_id: int in _players:
		_players[player_id].submitted = player_submitted
	
	for player_id: int in _players:
		_rpc_set_all_players_submitted.rpc_id(player_id, player_submitted)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_all_players_submitted(player_submitted: bool) -> void:
	for player_id: int in _players:
		_players[player_id].submitted = player_submitted
	
	updated.emit()

func get_local_player_submitted() -> bool:
	return get_player_submitted(multiplayer.get_unique_id())

func set_local_player_submitted(player_submitted: bool) -> void:
	set_player_submitted(multiplayer.get_unique_id(), player_submitted)

func get_player_submitted(player_id: int) -> bool:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to get player submitted for player ID '%d': multiplayer is not active." % [self.name,player_id])
		return false
	
	if !_players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to get player submitted for player ID '%d': could not find player ID." % [self.name, player_id])
		return false
	
	return _players[player_id].submitted

func set_player_submitted(player_id: int, player_submitted: bool) -> bool:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to set player submitted to '%s' for player ID '%d': multiplayer is not active." % [self.name, player_submitted, player_id])
		return false
	
	if !_players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to set player submitted to '%s' for player ID '%d': could not find player ID." % [self.name, player_submitted, player_id])
		return false
	
	if _players[player_id].submitted == player_submitted:
		push_error("GameInstance '<%s>' | Failed to set player submitted to '%s' for player ID '%d': player submitted already matches." % [self.name, player_submitted, player_id])
		return false
	
	if !is_multiplayer_authority():
		if player_id != multiplayer.get_unique_id():
			push_error("GameInstance '<%s>' | Failed to set player submitted to '%s' for player ID '%d': only the authority can set remote player submitted." % [self.name, player_submitted, player_id])
			return false
		
		_rpc_request_set_local_player_submitted.rpc_id(get_multiplayer_authority(), player_submitted)
		return true
	
	_players[player_id].submitted = player_submitted
	
	# Sync new data with all players.
	for _player_id: int in _players:
		if _player_id != multiplayer.get_unique_id():
			_rpc_set_player_submitted.rpc_id(_player_id, player_submitted)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_player_submitted(player_id: int, player_submitted: bool) -> void:
	if _players.has(player_id):
		_players[player_id].submitted = player_submitted
	
	updated.emit()

@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_set_local_player_submitted(player_submitted: bool) -> void:
	var player_id: int = multiplayer.get_remote_sender_id()
	if is_multiplayer_authority():
		set_player_submitted(player_id, player_submitted)

#endregion
#region Player Tiles

func clear_all_players_tiles() -> bool:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to clear all players tiles: multiplayer is not active." % [self.name])
		return false
	
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to clear all players tiles: only the authority can clear all players tiles." % [self.name])
		return false
	
	for player_id: int in _players:
		_players[player_id].tiles.clear()
	
	for player_id: int in _players:
		_rpc_clear_all_players_tiles.rpc_id(player_id)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_clear_all_players_tiles() -> void:
	for player_id: int in _players:
		_players[player_id].tiles.clear()
	
	updated.emit()

func get_local_player_tiles() -> PackedByteArray:
	return get_player_tiles(multiplayer.get_unique_id())

func get_player_tiles(player_id: int) -> Array[Tile]:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to get player tiles for player ID '%d': multiplayer is not active." % [self.name,player_id])
		return []
	
	if !_players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to get player tiles for player ID '%d': could not find player ID." % [self.name, player_id])
		return []
	
	var tiles: Array[Tile] = []
	for tile: Tile in _players[player_id].tiles:
		tiles.append(Tile.new(tile.get_face(), tile.is_wild()))
	return tiles

func set_player_tiles(player_id: int, player_tiles: PackedByteArray) -> bool:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to set player tiles to '%s' for player ID '%d': multiplayer is not active." % [self.name, str(player_tiles), player_id])
		return false
	
	if !_players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to set player tiles to '%s' for player ID '%d': could not find player ID." % [self.name, str(player_tiles), player_id])
		return false
	
	if _players[player_id].tiles == player_tiles:
		push_error("GameInstance '<%s>' | Failed to set player tiles to '%s' for player ID '%d': player tiles already matches." % [self.name, str(player_tiles), player_id])
		return false
	
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to set player tiles to '%s' for player ID '%d': only the authority can set player tiles." % [self.name, str(player_tiles), player_id])
		return false
	
	_players[player_id].tiles = player_tiles
	
	# Sync data with only the tiles owner.
	if player_id != multiplayer.get_unique_id():
		_rpc_set_player_tiles.rpc_id(player_id, player_id, player_tiles)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_player_tiles(player_id: int, player_tiles: PackedByteArray) -> void:
	if _players.has(player_id):
		_players[player_id].tiles = player_tiles
	
	updated.emit()

# TODO: move encoding and decoding to Game
#func get_player_tiles(player_id: int) -> Array[int]:
	#var player: Player = _get_player(player_id)
	#if is_instance_valid(player):
		#var player_tiles: Array[int] = []
		#for index: int in player.tiles.size():
			#player_tiles.append(player.tiles.decode_u8(index))
		#return player_tiles
	#return []
#
#func set_player_tiles(player_id: int, player_tiles: Array[int]) -> void:
	#if multiplayer.has_multiplayer_peer():
		#if is_multiplayer_authority():
			#var bytes: PackedByteArray = PackedByteArray()
			#bytes.resize(player_tiles.size())
			#for index: int in player_tiles.size():
				#bytes.encode_u8(index, player_tiles[index])
			#_set_player_tiles(player_id, bytes)

#endregion
#region Player Points

func clear_all_players_points() -> bool:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to clear all players points: multiplayer is not active." % [self.name])
		return false
	
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to clear all players points: only the authority can clear all players points." % [self.name])
		return false
	
	for player_id: int in _players:
		_players[player_id].points = 0
	
	for player_id: int in _players:
		_rpc_clear_all_players_points.rpc_id(player_id)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_clear_all_players_points() -> void:
	for player_id: int in _players:
		_players[player_id].points = 0
	
	updated.emit()

func get_local_player_points() -> int:
	return get_player_points(multiplayer.get_unique_id())

func get_player_points(player_id: int) -> int:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to get player points for player ID '%d': multiplayer is not active." % [self.name,player_id])
		return -1
	
	if !_players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to get player points for player ID '%d': could not find player ID." % [self.name, player_id])
		return -1
	
	return _players[player_id].points

func set_player_points(player_id: int, player_points: int) -> bool:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to set player points to '%s' for player ID '%d': multiplayer is not active." % [self.name, str(player_points), player_id])
		return false
	
	if !_players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to set player points to '%s' for player ID '%d': could not find player ID." % [self.name, str(player_points), player_id])
		return false
	
	if _players[player_id].points == player_points:
		push_error("GameInstance '<%s>' | Failed to set player points to '%s' for player ID '%d': player points already matches." % [self.name, str(player_points), player_id])
		return false
	
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to set player points to '%s' for player ID '%d': only the authority can set player points." % [self.name, str(player_points), player_id])
		return false
	
	_players[player_id].points = player_points
	
	# Sync data with all players.
	for _player_id: int in _players:
		if _player_id != multiplayer.get_unique_id():
			_rpc_set_player_points.rpc_id(_player_id, player_points)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_player_points(player_id: int, player_points: int) -> void:
	if _players.has(player_id):
		_players[player_id].points = player_points
	
	updated.emit()

#endregion
#region Player Place

func get_player_place(player_id: int) -> int:
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Failed to get player place for player ID '%d': multiplayer is not active." % [self.name,player_id])
		return -1
	
	if !_players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to get player place for player ID '%d': could not find player ID." % [self.name, player_id])
		return -1
	
	return _players[player_id].place

#endregion
#endregion

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	updated.connect(_on_updated)

func _on_updated() -> void:
	_dirty = true

## Custom sort method for sorting player IDs.
## Spectators are sorted by name (ascending order) and are pushed after non-spectators.
## Non-spectators are sorted by points (descending order).
func _sort_player_custom(a: int, b: int) -> bool:
	if _players[a].spectator:
		return _players[b].spectator && (_players[a].name < _players[b].name)
	
	if _players[b].spectator:
		return true
	
	return _players[a].points > _players[b].points

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if _dirty:
		# Sort players.
		var players_sorted: Array[int] = []
		players_sorted.append_array(_players.keys())
		players_sorted.sort_custom(_sort_player_custom)
		
		# Assign player places in ascending order based on players_sorted.
		var place: int = 0
		for player_id: int in players_sorted:
			if !_players[player_id].spectator:
				_players[player_id].place = place
				place += 1
		
		updated.emit()
		_dirty = false
	
	# TODO: handle disconnections in game.gd (should free game instances)
	if !multiplayer.has_multiplayer_peer():
		push_error("GameInstance '<%s>' | Multiplayer is not active." % [self.name])
		get_tree().quit(1)# if this happens i am terrible programmer
		return
	
	if !_play:
		# TODO: if no players, stop game instance (notify game.gd with signal? then queue frees this)?
		
		if is_multiplayer_authority():
			# Start play loop when all players are ready.
			# TODO: Start a countdown instead? If 50% of players are ready, maybe start a countdown at 20 seconds?
			if get_all_players_ready():
				set_play(true)
	else:
		# Decrement turn timer.
		if _turn_timer > 0.0:
			_turn_timer = maxf(_turn_timer - delta, 0.0)
		
		if is_multiplayer_authority():
			if _turn_timer > 3.0 && get_all_players_submitted():
				# Fast-forward turn timer if all players have submitted.
				set_turn_timer(3.0)
			elif is_zero_approx(_turn_timer):
				# Increment turn count on turn timer timeout. Stop on last turn.
				if _turn_count < _turn_count_max:
					# Prepare next turn.
					set_turn_count(_turn_count + 1)
					set_turn_timer(_turn_timer_max)
					set_all_players_submitted(false)
				else:
					# Reset data and stop play loop.
					# TODO: Bake leaderboard. _leaderboard_names _leaderboard_points
					clear_all_players_tiles()
					set_all_players_ready(false)
					set_all_players_submitted(false)
					set_play(false)
