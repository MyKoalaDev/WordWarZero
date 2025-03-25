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
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to force sync with player ID '%d': only the authority can force sync." % [self.name, player_id])
		return false
	
	if !_players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to force sync with player ID '%d': player ID does not exist." % [self.name, player_id])
		return false
	
	if player_id == multiplayer.get_unique_id():
		push_error("GameInstance '<%s>' | Failed to force sync with player ID '%d': cannot force sync with self." % [self.name, player_id])
		return false
	
	_rpc_set_play.rpc_id(player_id, _play)
	
	_rpc_set_turn_count.rpc_id(player_id, _turn_count)
	_rpc_set_turn_count_max.rpc_id(player_id, _turn_count_max)
	_rpc_set_turn_timer.rpc_id(player_id, _turn_timer)
	_rpc_set_turn_timer_max.rpc_id(player_id, _turn_timer_max)
	
	_rpc_set_tile_board.rpc_id(player_id, _encode_tile_board(_tile_board))
	
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
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to set play to '%s': only the authority can set play." % [self.name, str(play)])
		return false
	
	if _play == play:
		return true
	
	_play = play
	
	for _player_id: int in _players:
		if _player_id != multiplayer.get_unique_id():
			_rpc_set_play.rpc_id(_player_id, play)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_play(play: bool) -> void:
	_play = play
	
	updated.emit()

#endregion
#region Turn

var _turn_count: int = 0

func get_turn_count() -> int:
	return _turn_count

func set_turn_count(turn_count: int) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to set turn count to '%d': only the authority can set turn count." % [self.name, turn_count])
		return false
	
	if _turn_count == turn_count:
		return true
	
	_turn_count = turn_count
	
	for _player_id: int in _players:
		if _player_id != multiplayer.get_unique_id():
			_rpc_set_turn_count.rpc_id(_player_id, turn_count)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_turn_count(turn_count: int) -> void:
	_turn_count = turn_count
	
	updated.emit()

var _turn_count_max: int = DEFAULT_TURN_COUNT

func get_turn_count_max() -> int:
	return _turn_count_max

func set_turn_count_max(turn_count_max: int) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to set turn count max to '%d': only the authority can set turn count max." % [self.name, turn_count_max])
		return false
	
	if _turn_count_max == turn_count_max:
		return true
	
	_turn_count_max = turn_count_max
	
	for _player_id: int in _players:
		if _player_id != multiplayer.get_unique_id():
			_rpc_set_turn_count_max.rpc_id(_player_id, turn_count_max)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_turn_count_max(turn_count_max: int) -> void:
	_turn_count_max = turn_count_max
	
	updated.emit()

var _turn_timer: float = 0.0

func get_turn_timer() -> float:
	return _turn_timer

func set_turn_timer(turn_timer: int) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to set turn timer to '%d': only the authority can set turn timer." % [self.name, turn_timer])
		return false
	
	if _turn_timer == turn_timer:
		return true
	
	_turn_timer = turn_timer
	
	for _player_id: int in _players:
		if _player_id != multiplayer.get_unique_id():
			_rpc_set_turn_timer.rpc_id(_player_id, turn_timer)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_turn_timer(turn_timer: int) -> void:
	_turn_timer = turn_timer

var _turn_timer_max: float = DEFAULT_TURN_TIMER

func get_turn_timer_max() -> float:
	return _turn_timer_max

func set_turn_timer_max(turn_timer_max: int) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to set turn timer max to '%d': only the authority can set turn timer max." % [self.name, turn_timer_max])
		return false
	
	if _turn_timer_max == turn_timer_max:
		return true
	
	_turn_timer_max = turn_timer_max
	
	for _player_id: int in _players:
		if _player_id != multiplayer.get_unique_id():
			_rpc_set_turn_timer_max.rpc_id(_player_id, turn_timer_max)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_turn_timer_max(turn_timer_max: int) -> void:
	_turn_timer_max = turn_timer_max

#endregion
#region Tile Board

signal tile_board_set()
signal tile_board_cleared()
signal tile_board_tile_added(tile_position: Vector2i, tile: Tile)

## Hashmap of tile coordinates to encoded tile data. (These are submitted tiles locked onto the board).
var _tile_board: Dictionary[Vector2i, Tile] = {}

## Returns a read-only duplicate of the tile board.
func get_tile_board() -> Dictionary[Vector2i, Tile]:
	var tile_board: Dictionary[Vector2i, Tile] = {}
	for tile_position: Vector2i in _tile_board:
		tile_board[tile_position] = _tile_board[tile_position].duplicate()
	tile_board.make_read_only()
	return tile_board

func set_tile_board(tile_board: Dictionary[Vector2i, Tile]) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to set tile board: only the authority can set tile board." % [self.name])
		return false
	
	_tile_board.clear()
	for tile_position: Vector2i in tile_board:
		_tile_board[tile_position] = tile_board[tile_position].duplicate()
	
	var bytes: PackedByteArray = _encode_tile_board(tile_board)
	for _player_id: int in _players:
		if _player_id != multiplayer.get_unique_id():
			_rpc_set_tile_board.rpc_id(_player_id, bytes)
	
	tile_board_set.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_tile_board(bytes: PackedByteArray) -> void:
	_tile_board = _decode_tile_board(bytes)
	
	tile_board_set.emit()

func clear_tile_board() -> bool:
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

func add_tile_board_tile(tile_position: Vector2i, tile: Tile) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to add tile board tile: only the authority can add tile board tile." % [self.name])
		return false
	
	if _tile_board.has(tile_position):
		push_error("GameInstance '<%s>' | Failed to add tile board tile: a tile already exists at (%d, %d)." % [self.name, tile_position.x, tile_position.y])
		return false
	
	_tile_board[tile_position] = tile.duplicate()
	
	var bytes: PackedByteArray = PackedByteArray()
	bytes.encode_s16(0, tile_position.x)
	bytes.encode_s16(2, tile_position.y)
	bytes.encode_u8(4, _encode_tile(tile))
	for _player_id: int in _players:
		if _player_id != multiplayer.get_unique_id():
			_rpc_add_tile_board_tile.rpc_id(_player_id, bytes)
	
	tile_board_tile_added.emit(tile_position, _tile_board[tile_position])
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_add_tile_board_tile(bytes: PackedByteArray) -> void:
	var tile_position: Vector2i = Vector2i(bytes.decode_s16(0), bytes.decode_s16(2))
	var tile: Tile = _decode_tile(bytes.decode_u8(4))
	_tile_board[tile_position] = tile
	
	tile_board_tile_added.emit(tile_position, tile)

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
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to add player ID '%d': only the authority can add player ID." % [self.name, player_id])
		return false
	
	if _players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to add player ID '%d': player ID already exists." % [self.name, player_id])
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
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to remove player ID '%d': only the authority can remove player ID." % [self.name, player_id])
		return false
	
	if !_players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to remove player ID '%d': player ID does not exist." % [self.name, player_id])
		return false
	
	_players.erase(player_id)
	
	for _player_id: int in _players:
		if _player_id != multiplayer.get_unique_id():
			_rpc_remove_player_id.rpc_id(_player_id, player_id)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_remove_player_id(player_id: int) -> void:
	_players.erase(player_id)
	
	updated.emit()

#endregion
#region Player Name

func get_player_name(player_id: int) -> String:
	if !_players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to get player name for player ID '%d': could not find player ID." % [self.name, player_id])
		return ""
	
	return _players[player_id].name

func set_player_name(player_id: int, player_name: String) -> bool:
	if !is_multiplayer_authority() && (player_id != multiplayer.get_unique_id()):
		push_error("GameInstance '<%s>' | Failed to set player name to '%s' for player ID '%d': only the authority can set remote player name." % [self.name, player_name, player_id])
		return false
	
	if !_players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to set player name to '%s' for player ID '%d': could not find player ID." % [self.name, player_name, player_id])
		return false
	
	if _players[player_id].name == player_name:
		return true
	
	if !Game.is_valid_player_name(player_name):
		push_error("GameInstance '<%s>' | Failed to set player name to '%s' for player ID '%d': player name is not valid." % [self.name, player_name, player_id])
		return false
	
	if !is_multiplayer_authority():
		_rpc_request_set_player_name.rpc_id(get_multiplayer_authority(), player_name)
		return true
	
	_players[player_id].name = player_name
	
	for _player_id: int in _players:
		if _player_id != multiplayer.get_unique_id():
			_rpc_set_player_name.rpc_id(_player_id, player_name)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_player_name(player_id: int, player_name: String) -> void:
	_players[player_id].name = player_name
	
	updated.emit()

@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_set_player_name(player_name: String) -> void:
	var player_id: int = multiplayer.get_remote_sender_id()
	if is_multiplayer_authority():
		set_player_name(player_id, player_name)

#endregion
#region Player Ready

func get_all_players_ready() -> bool:
	if _players.is_empty():
		return false
	
	for _player_id: int in _players:
		if !_players[_player_id].spectator && !_players[_player_id].ready:
			return false
	
	return true

func set_all_players_ready(player_ready: bool) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to set all players ready to '%s': only the authority can set all players ready." % [self.name, str(player_ready)])
		return false
	
	for _player_id: int in _players:
		_players[_player_id].ready = player_ready
		if _player_id != multiplayer.get_unique_id():
			_rpc_set_all_players_ready.rpc_id(_player_id, player_ready)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_all_players_ready(player_ready: bool) -> void:
	for _player_id: int in _players:
		_players[_player_id].ready = player_ready
	
	updated.emit()

func get_player_ready(player_id: int) -> bool:
	if !_players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to get player ready for player ID '%d': could not find player ID." % [self.name, player_id])
		return false
	
	return _players[player_id].ready

func set_player_ready(player_id: int, player_ready: bool) -> bool:
	if !is_multiplayer_authority() && (player_id != multiplayer.get_unique_id()):
		push_error("GameInstance '<%s>' | Failed to set player ready to '%s' for player ID '%d': only the authority can set remote player ready." % [self.name, player_ready, player_id])
		return false
	
	if !_players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to set player ready to '%s' for player ID '%d': could not find player ID." % [self.name, player_ready, player_id])
		return false
	
	if _players[player_id].ready == player_ready:
		return true
	
	if !is_multiplayer_authority():
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
	_players[player_id].ready = player_ready
	
	updated.emit()

@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_set_local_player_ready(player_ready: bool) -> void:
	var player_id: int = multiplayer.get_remote_sender_id()
	if is_multiplayer_authority():
		set_player_ready(player_id, player_ready)

#endregion
#region Player Spectator

func get_player_spectator(player_id: int) -> bool:
	if !_players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to get player spectator for player ID '%d': could not find player ID." % [self.name, player_id])
		return false
	
	return _players[player_id].spectator

func set_player_spectator(player_id: int, player_spectator: bool) -> bool:
	if !is_multiplayer_authority() && player_id != multiplayer.get_unique_id():
		push_error("GameInstance '<%s>' | Failed to set player spectator to '%s' for player ID '%d': only the authority can set remote player spectator." % [self.name, player_spectator, player_id])
		return false
	
	if !_players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to set player spectator to '%s' for player ID '%d': could not find player ID." % [self.name, player_spectator, player_id])
		return false
	
	if _players[player_id].spectator == player_spectator:
		return true
	
	if !is_multiplayer_authority():
		_rpc_request_set_player_spectator.rpc_id(get_multiplayer_authority(), player_spectator)
		return true
	
	_players[player_id].spectator = player_spectator
	
	for _player_id: int in _players:
		if _player_id != multiplayer.get_unique_id():
			_rpc_set_player_spectator.rpc_id(_player_id, player_id, player_spectator)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_player_spectator(player_id: int, player_spectator: bool) -> void:
	_players[player_id].spectator = player_spectator
	
	updated.emit()

@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_set_player_spectator(player_spectator: bool) -> void:
	var player_id: int = multiplayer.get_remote_sender_id()
	if is_multiplayer_authority():
		set_player_spectator(player_id, player_spectator)

#endregion
#region Player Submitted

func get_all_players_submitted() -> bool:
	if _players.is_empty():
		return false
	
	for _player_id: int in _players:
		if !_players[_player_id].spectator && !_players[_player_id].submitted:
			return false
	
	return true

func clear_all_players_submitted() -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to clear all players submitted: only the authority can clear all players submitted." % [self.name])
		return false
	
	for _player_id: int in _players:
		_players[_player_id].submitted = false
		if _player_id != multiplayer.get_unique_id():
			_rpc_clear_all_players_submitted.rpc_id(_player_id)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_clear_all_players_submitted() -> void:
	for _player_id: int in _players:
		_players[_player_id].submitted = false
	
	updated.emit()

func get_player_submitted(player_id: int) -> bool:
	if !_players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to get player submitted for player ID '%d': could not find player ID." % [self.name, player_id])
		return false
	
	return _players[player_id].submitted

func set_player_submitted(player_id: int, player_submitted: bool) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to set player submitted to '%s' for player ID '%d': only the authority can set remote player submitted." % [self.name, player_submitted, player_id])
		return false
	
	if !_players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to set player submitted to '%s' for player ID '%d': could not find player ID." % [self.name, player_submitted, player_id])
		return false
	
	if _players[player_id].submitted == player_submitted:
		return true
	
	_players[player_id].submitted = player_submitted
	
	for _player_id: int in _players:
		if _player_id != multiplayer.get_unique_id():
			_rpc_set_player_submitted.rpc_id(_player_id, player_id, player_submitted)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_player_submitted(player_id: int, player_submitted: bool) -> void:
	_players[player_id].submitted = player_submitted
	
	updated.emit()

#endregion
#region Player Tiles

func clear_all_players_tiles() -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to clear all players tiles: only the authority can clear all players tiles." % [self.name])
		return false
	
	for _player_id: int in _players:
		_players[_player_id].tiles.clear()
		if _player_id != multiplayer.get_unique_id():
			_rpc_clear_all_players_tiles.rpc_id(_player_id)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_clear_all_players_tiles() -> void:
	for _player_id: int in _players:
		_players[_player_id].tiles.clear()
	
	updated.emit()

func get_player_tiles(player_id: int) -> Array[Tile]:
	if !_players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to get player tiles for player ID '%d': could not find player ID." % [self.name, player_id])
		return []
	
	var tiles: Array[Tile] = []
	for tile: Tile in _players[player_id].tiles:
		tiles.append(Tile.new(tile.get_face(), tile.is_wild()))
	return tiles

func set_player_tiles(player_id: int, player_tiles: Array[Tile]) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to set player tiles to '%s' for player ID '%d': only the authority can set player tiles." % [self.name, str(player_tiles), player_id])
		return false
	
	if !_players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to set player tiles to '%s' for player ID '%d': could not find player ID." % [self.name, str(player_tiles), player_id])
		return false
	
	_players[player_id].tiles = player_tiles
	
	# Sync with only the tiles owner.
	if player_id != multiplayer.get_unique_id():
		_rpc_set_player_tiles.rpc_id(player_id, player_id, _encode_tiles(player_tiles))
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_player_tiles(player_id: int, bytes: PackedByteArray) -> void:
	_players[player_id].tiles = _decode_tiles(bytes)
	
	updated.emit()

#endregion
#region Player Points

func clear_all_players_points() -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to clear all players points: only the authority can clear all players points." % [self.name])
		return false
	
	for _player_id: int in _players:
		_players[_player_id].points = 0
		if _player_id != multiplayer.get_unique_id():
			_rpc_clear_all_players_points.rpc_id(_player_id)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_clear_all_players_points() -> void:
	for _player_id: int in _players:
		_players[_player_id].points = 0
	
	updated.emit()

func get_player_points(player_id: int) -> int:
	if !_players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to get player points for player ID '%d': could not find player ID." % [self.name, player_id])
		return -1
	
	return _players[player_id].points

func set_player_points(player_id: int, player_points: int) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstance '<%s>' | Failed to set player points to '%s' for player ID '%d': only the authority can set player points." % [self.name, str(player_points), player_id])
		return false
	
	if !_players.has(player_id):
		push_error("GameInstance '<%s>' | Failed to set player points to '%s' for player ID '%d': could not find player ID." % [self.name, str(player_points), player_id])
		return false
	
	if _players[player_id].points == player_points:
		return true
	
	_players[player_id].points = player_points
	
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
					clear_all_players_submitted()
				else:
					# Reset data and stop play loop.
					# TODO: Bake leaderboard. _leaderboard_names _leaderboard_points
					clear_all_players_tiles()
					set_all_players_ready(false)
					clear_all_players_submitted()
					set_play(false)

#region Byte Encoding/Decoding

func _encode_tile(tile: Tile) -> int:
	var byte: int = 0
	if tile.is_wild():
		byte |= 1 << 7
	byte |= tile.get_face()
	return byte

func _decode_tile(byte: int) -> Tile:
	return Tile.new(byte & ~(1 << 7), byte & (1 << 7))

## Encode tiles to a byte array.
## Right most bits of a byte indicate face.
## Left most bit of a byte indicates wild.
func _encode_tiles(tiles: Array[Tile]) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(tiles.size())
	for index: int in tiles.size():
		bytes[index] = _encode_tile(tiles[index])
	return bytes

## Decode tile from a byte.
func _decode_tiles(bytes: PackedByteArray) -> Array[Tile]:
	var tiles: Array[Tile] = []
	for index: int in bytes.size():
		tiles.append(_decode_tile(bytes[index]))
	return tiles

# NOTE: TileMap coordinates are limited to 16 bit signed integers.
# tile position x: 2 bytes (16 bit signed int)
# tile position y: 2 bytes (16 bit signed int)
# tile face: 1 byte (8 bit unsigned int)
func _encode_tile_board(tile_board: Dictionary[Vector2i, Tile]) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(tile_board.size() * 5)
	var index: int = 0
	for tile_position: Vector2i in tile_board:
		bytes.encode_s16(index + 0, tile_position.x)
		bytes.encode_s16(index + 2, tile_position.y)
		bytes.encode_u8(index + 4, _encode_tile(tile_board[tile_position]))
		index += 5
	return bytes

func _decode_tile_board(bytes: PackedByteArray) -> Dictionary[Vector2i, Tile]:
	if bytes.size() % 5 != 0:
		return {}
	
	var tile_board: Dictionary[Vector2i, Tile] = {}
	var index: int = 0
	while index < bytes.size():
		var tile_position: Vector2i = Vector2i(bytes.decode_s16(index + 0), bytes.decode_s16(index + 2))
		tile_board[tile_position] = _decode_tile(bytes.decode_u8(index + 4))
		index += 5
	return tile_board

#endregion
