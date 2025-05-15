@tool
extends "game_info_board.gd"

class _PlayerDataClassic:
	extends RefCounted
	# Server-managed fields.
	var player_submit: bool = false
	var player_points: int = 0
	var player_tiles: Array[Tile] = []
	
	# Client-managed fields.
	var place: int = 0

const DEFAULT_TURN_COUNT: int = 8
const DEFAULT_TURN_TIMER: float = 60.0

const DEFAULT_TILE_BOARD_MULTIPLIERS_LETTER: Array[int] = [
	1, 1, 2, 1, 2, 1, 1, 2, 1, 2, 1, 1, 2, 1, 2, 1,
	1, 2, 1, 2, 1, 1, 3, 1, 1, 1, 3, 1, 1, 2, 1, 2,
	1, 1, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 3, 1,
	1, 2, 1, 1, 1, 2, 1, 1, 3, 1, 1, 2, 1, 1, 1, 2,
	2, 1, 1, 1, 2, 1, 2, 1, 1, 1, 2, 1, 2, 1, 1, 1,
	1, 2, 1, 1, 1, 3, 1, 1, 1, 1, 1, 3, 1, 1, 1, 2,
	2, 1, 1, 1, 1, 1, 1, 2, 1, 2, 1, 1, 1, 1, 1, 1,
	1, 3, 1, 1, 2, 1, 2, 1, 1, 1, 2, 1, 2, 1, 1, 3,
	1, 1, 1, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 3, 1, 1,
	1, 3, 1, 1, 2, 1, 2, 1, 1, 1, 2, 1, 2, 1, 1, 3,
	2, 1, 1, 1, 1, 1, 1, 2, 1, 2, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 3, 1, 1, 1, 1, 1, 3, 1, 1, 1, 1,
	2, 1, 1, 1, 2, 1, 2, 1, 1, 1, 2, 1, 2, 1, 1, 1,
	1, 2, 1, 1, 1, 2, 1, 1, 3, 1, 1, 2, 1, 1, 1, 2,
	1, 1, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 3, 1,
	1, 2, 1, 2, 1, 1, 3, 1, 1, 1, 3, 1, 1, 2, 1, 2,
]
const DEFAULT_TILE_BOARD_MULTIPLIERS_LETTER_SIZE: Vector2i = Vector2i(16, 16)

const DEFAULT_TILE_BOARD_MULTIPLIERS_WORD: Array[int] = [
	1, 1, 1, 2, 1, 1, 1, 1, 2, 1, 1, 1, 1, 2, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1,
	2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 2, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 3, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 2, 1, 1, 1,
	2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
]
const DEFAULT_TILE_BOARD_MULTIPLIERS_WORD_SIZE: Vector2i = Vector2i(16, 16)

enum SubmissionResult {
	OK,
	AWAITING,
	ERROR,
	TIMED_OUT,
	STILL_PROCESSING,
	ALREADY_SUBMITTED,
	EMPTY_SUBMISSION,
	INVALID_PLAYER,
	INVALID_SUBMISSION,
	INVALID_TILES,
	TILES_OVERLAPPING,
	TILES_NOT_COLLINEAR,
	TILES_NOT_CONTIGUOUS,
	TILES_NOT_CONNECTED,
	FIRST_CENTER,
	TOO_SHORT,
	INVALID_WORD,
}

static func get_submission_result_message(submission_result: SubmissionResult) -> String:
	match submission_result:
		SubmissionResult.OK:
			return "Submission passed!"
		SubmissionResult.AWAITING:
			return "Awaiting submission result..."
		SubmissionResult.ERROR:
			return "Submission error!"
		SubmissionResult.TIMED_OUT:
			return "Submission time out!"
		SubmissionResult.STILL_PROCESSING:
			return "Submission still processing!"
		SubmissionResult.ALREADY_SUBMITTED:
			return "Already submitted this turn!"
		SubmissionResult.EMPTY_SUBMISSION:
			return "Empty submission!"
		SubmissionResult.INVALID_SUBMISSION:
			return "Invalid submission!"
		SubmissionResult.INVALID_TILES:
			return "Invalid submission tiles! (Game problem)"
		SubmissionResult.TILES_OVERLAPPING:
			return "Submission is out of date!"
		SubmissionResult.TILES_NOT_COLLINEAR:
			return "Submission tiles are not aligned!"
		SubmissionResult.TILES_NOT_CONTIGUOUS:
			return "Submission tiles are not contiguous!"
		SubmissionResult.TILES_NOT_CONNECTED:
			return "Submission tiles are not connected!"
		SubmissionResult.FIRST_CENTER:
			return "The first word must be on the center tile!"
		SubmissionResult.TOO_SHORT:
			return "Submission word is too short!"
		SubmissionResult.INVALID_WORD:
			return "Not a valid word!"
	return "?"

func _force_sync(player_id: int) -> bool:
	if !super(player_id):
		return false
	
	_rpc_set_turn_count.rpc_id(player_id, _turn_count)
	_rpc_set_turn_count_max.rpc_id(player_id, _turn_count_max)
	_rpc_set_turn_timer.rpc_id(player_id, _turn_timer)
	_rpc_set_turn_timer_max.rpc_id(player_id, _turn_timer_max)
	
	_rpc_set_tile_board.rpc_id(player_id, _encode_tile_board(_tile_board))
	
	for _player_id: int in _players:
		var player_data_classic: _PlayerDataClassic = _players_classic[_player_id]
		_rpc_set_player_submit.rpc_id(player_id, _player_id, player_data_classic.player_submit)
		_rpc_set_player_points.rpc_id(player_id, _player_id, player_data_classic.player_points)
		# NOTE: Each player should only know about their own tiles.
		if player_id == _player_id:
			_rpc_set_player_tiles.rpc_id(player_id, _player_id, player_data_classic.player_tiles)
	
	return true

#region Player

## Hashmap of player IDs (multiplayer peer id) to player data.
var _players_classic: Dictionary[int, _PlayerDataClassic] = {}

#region Player ID

func _add_player_id(player_id: int) -> bool:
	if !super(player_id):
		return false
	
	_players_classic[player_id] = _PlayerDataClassic.new()
	return true

func _remove_player_id(player_id: int) -> bool:
	if !super(player_id):
		return false
	
	_players_classic.erase(player_id)
	return true

#endregion
#region Player Submit

signal player_submit_changed(player_id: int, player_submit: bool)

func get_all_players_submit() -> bool:
	if _players.is_empty():
		return false
	
	for _player_id: int in _players:
		if !_players[_player_id].player_spectator && !_players_classic[_player_id].player_submit:
			return false
	
	return true

func _set_all_players_submit(player_submit: bool) -> bool:
	var local_player_id: int = multiplayer.get_unique_id()
	for _player_id: int in _players_classic:
		if _players_classic[_player_id].player_submit != player_submit:
			_players_classic[_player_id].player_submit = player_submit
			player_submit_changed.emit(_player_id, player_submit)
		
		if is_multiplayer_authority() && (_player_id != local_player_id):
			_rpc_set_all_players_submit.rpc_id(_player_id, player_submit)
	
	return true

func set_all_players_submit(player_submit: bool) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInfoBoard \"%s\" | Failed to set all players submit to \'%s\': unauthorized." % [self.name, str(player_submit)])
		return false
	
	return _set_all_players_submit(player_submit)

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_all_players_submit(player_submit: bool) -> void:
	_set_all_players_submit(player_submit)

func get_player_submit(player_id: int) -> bool:
	if !has_player_id(player_id):
		push_error("GameInfoBoard \"%s\" | Failed to get player submit for player ID '%d': could not find player ID." % [self.name, player_id])
		return false
	
	return _players_classic[player_id].player_submit

func _set_player_submit(player_id: int, player_submit: bool) -> bool:
	if !has_player_id(player_id):
		push_error("GameInfoBoard \"%s\" | Failed to set player submit to \'%s\' for player ID \'%d\': could not find player ID." % [self.name, str(player_submit), player_id])
		return false
	
	if _players_classic[player_id].player_submit == player_submit:
		return true
	
	_players_classic[player_id].player_submit = player_submit
	
	if is_multiplayer_authority():
		var local_player_id: int = multiplayer.get_unique_id()
		for _player_id: int in _players_classic:
			if _player_id != local_player_id:
				_rpc_set_player_submit.rpc_id(_player_id, player_id, player_submit)
	
	player_submit_changed.emit(player_id, player_submit)
	return true

func set_player_submit(player_id: int, player_submit: bool) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInfoBoard \"%s\" | Failed to set player submit to \'%s\' for player ID \'%d\': unauthorized." % [self.name, str(player_submit), player_id])
		return false
	
	return _set_player_submit(player_id, player_submit)

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_player_submit(player_id: int, player_submit: bool) -> void:
	_set_player_submit(player_id, player_submit)

#endregion
#region Player Tiles

signal player_tiles_changed(player_id: int, player_tiles: Array[Tile])

func _clear_all_players_tiles() -> bool:
	var local_player_id: int = multiplayer.get_unique_id()
	for _player_id: int in _players_classic:
		if !_players_classic[_player_id].player_tiles.is_empty():
			_players_classic[_player_id].player_tiles.clear()
			player_tiles_changed.emit(_player_id, [])
		
		if is_multiplayer_authority() && (_player_id != local_player_id):
			_rpc_clear_all_players_tiles.rpc_id(_player_id)
	
	return true

func clear_all_players_tiles() -> bool:
	if !is_multiplayer_authority():
		push_error("GameInfoBoard \"%s\" | Failed to clear all player tiles: unauthorized." % [self.name])
		return false
	
	return _clear_all_players_tiles()

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_clear_all_players_tiles() -> void:
	_clear_all_players_tiles()

func get_player_tiles(player_id: int) -> Array[Tile]:
	if has_player_id(player_id):
		push_error("GameInfoBoard \"%s\" | Failed to get player tiles for player ID '%d': could not find player ID." % [self.name, player_id])
		return []
	
	var tiles: Array[Tile] = []
	for tile: Tile in _players_classic[player_id].player_tiles:
		tiles.append(Tile.new(tile.get_face(), tile.is_wild()))
	tiles.make_read_only()
	return tiles

func _set_player_tiles(player_id: int, player_tiles: Array[Tile]) -> bool:
	if !has_player_id(player_id):
		push_error("GameInfoBoard \"%s\" | Failed to set player tiles to \'%s\' for player ID \'%d\': could not find player ID." % [self.name, str(player_tiles), player_id])
		return false
	
	var tiles: Array[Tile] = []
	for tile: Tile in _players_classic[player_id].player_tiles:
		tiles.append(Tile.new(tile.get_face(), tile.is_wild()))
	
	_players_classic[player_id].player_tiles = tiles
	
	if is_multiplayer_authority():
		var local_player_id: int = multiplayer.get_unique_id()
		for _player_id: int in _players_classic:
			if _player_id != local_player_id:
				_rpc_set_player_tiles.rpc_id(_player_id, player_id, _encode_tiles(tiles))
	
	player_tiles_changed.emit(player_id, get_player_tiles(player_id))
	return true

func set_player_tiles(player_id: int, player_tiles: Array[Tile]) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInfoBoard \"%s\" | Failed to set player tiles to \'%s\' for player ID \'%d\': unauthorized." % [self.name, str(player_tiles), player_id])
		return false
	
	return _set_player_tiles(player_id, player_tiles)

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_player_tiles(player_id: int, bytes: PackedByteArray) -> void:
	_set_player_tiles(player_id, _decode_tiles(bytes))

#endregion
#region Player Points

signal player_points_changed(player_id: int, player_points: int)

func _clear_all_players_points() -> bool:
	var local_player_id: int = multiplayer.get_unique_id()
	for _player_id: int in _players_classic:
		if _players_classic[_player_id].player_points != 0:
			_players_classic[_player_id].player_points = 0
			player_points_changed.emit(_player_id, 0)
		
		if is_multiplayer_authority() && (_player_id != local_player_id):
			_rpc_clear_all_players_points.rpc_id(_player_id)
	
	return true

func clear_all_players_points() -> bool:
	if !is_multiplayer_authority():
		push_error("GameInfoBoard \"%s\" | Failed to clear all player points: unauthorized." % [self.name])
		return false
	
	return _clear_all_players_points()

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_clear_all_players_points() -> void:
	_clear_all_players_points()

func get_player_points(player_id: int) -> int:
	if has_player_id(player_id):
		push_error("GameInfoBoard \"%s\" | Failed to get player points for player ID '%d': could not find player ID." % [self.name, player_id])
		return 0
	
	return _players_classic[player_id].player_points

func _set_player_points(player_id: int, player_points: int) -> bool:
	if !has_player_id(player_id):
		push_error("GameInfoBoard \"%s\" | Failed to set player points to \'%s\' for player ID \'%d\': could not find player ID." % [self.name, str(player_points), player_id])
		return false
	
	_players_classic[player_id].player_points = player_points
	
	if is_multiplayer_authority():
		var local_player_id: int = multiplayer.get_unique_id()
		for _player_id: int in _players_classic:
			if _player_id != local_player_id:
				_rpc_set_player_points.rpc_id(_player_id, player_id, player_points)
	
	player_points_changed.emit(player_id, get_player_points(player_id))
	return true

func set_player_points(player_id: int, player_points: int) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInfoBoard \"%s\" | Failed to set player points to \'%s\' for player ID \'%d\': unauthorized." % [self.name, str(player_points), player_id])
		return false
	
	return _set_player_points(player_id, player_points)

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_player_points(player_id: int, player_points: int) -> void:
	_set_player_points(player_id, player_points)

#endregion
#endregion
#region Turn
#region Turn Count

signal turn_count_changed(turn_count_old: int, turn_count_new: int)
signal turn_count_max_changed(turn_count_max_old: int, turn_count_max_new: int)

var _turn_count: int = 0
var _turn_count_max: int = DEFAULT_TURN_COUNT

func get_turn_count() -> int:
	return _turn_count

func _set_turn_count(turn_count: int) -> bool:
	if _turn_count == turn_count:
		return false
	
	var turn_count_old: int = _turn_count
	var turn_count_new: int = turn_count
	
	_turn_count = turn_count
	
	turn_count_max_changed.emit(turn_count_old, turn_count_new)
	return true

func set_turn_count(turn_count: int) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInfoBoard \"%s\" | Failed to set turn count to \'%d\': unauthorized." % [self.name, turn_count])
		return false
	
	if !_set_turn_count(turn_count):
		return false
	
	for _player_id: int in _players:
		if _player_id != multiplayer.get_unique_id():
			_rpc_set_turn_count.rpc_id(_player_id, turn_count)
	
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_turn_count(turn_count: int) -> void:
	_set_turn_count(turn_count)

func get_turn_count_max() -> int:
	return _turn_count_max

func _set_turn_count_max(turn_count_max: int) -> bool:
	if _turn_count_max == turn_count_max:
		return false
	
	var turn_count_max_old: int = _turn_count_max
	var turn_count_max_new: int = turn_count_max
	
	_turn_count_max = turn_count_max
	
	turn_count_max_changed.emit(turn_count_max_old, turn_count_max_new)
	return true

func set_turn_count_max(turn_count_max: int) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInfoBoard \"%s\" | Failed to set turn count max to \'%d\': unauthorized." % [self.name, turn_count_max])
		return false
	
	if !_set_turn_count_max(turn_count_max):
		return false
	
	for _player_id: int in _players:
		if _player_id != multiplayer.get_unique_id():
			_rpc_set_turn_count_max.rpc_id(_player_id, turn_count_max)
	
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_turn_count_max(turn_count_max: int) -> void:
	_set_turn_count_max(turn_count_max)

#endregion
#region Turn Timer

signal turn_timer_changed(turn_timer_old: int, turn_timer_new: int)
signal turn_timer_max_changed(turn_timer_max_old: int, turn_timer_max_new: int)

var _turn_timer: float = 0.0
var _turn_timer_max: float = 0.0

func get_turn_timer() -> float:
	return _turn_timer

func _set_turn_timer(turn_timer: int) -> bool:
	if _turn_timer == turn_timer:
		return false
	
	var turn_timer_old: int = _turn_timer
	var turn_timer_new: int = turn_timer
	
	_turn_timer = turn_timer
	
	turn_timer_changed.emit(turn_timer_old, turn_timer_new)
	return true

func set_turn_timer(turn_timer: int) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInfoBoard \"%s\" | Failed to set turn timer to \'%d\': unauthorized." % [self.name, turn_timer])
		return false
	
	if !_set_turn_timer(turn_timer):
		return false
	
	for _player_id: int in _players:
		if _player_id != multiplayer.get_unique_id():
			_rpc_set_turn_timer.rpc_id(_player_id, turn_timer)
	
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_turn_timer(turn_timer: int) -> void:
	_set_turn_timer(turn_timer)

func get_turn_timer_max() -> float:
	return _turn_timer_max

func _set_turn_timer_max(turn_timer_max: int) -> bool:
	if _turn_timer_max == turn_timer_max:
		return false
	
	var turn_timer_max_old: int = _turn_timer_max
	var turn_timer_max_new: int = turn_timer_max
	
	_turn_timer_max = turn_timer_max
	
	turn_timer_max_changed.emit(turn_timer_max_old, turn_timer_max_new)
	return true

func set_turn_timer_max(turn_timer_max: int) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInfoBoard \"%s\" | Failed to set turn timer max to \'%d\': unauthorized." % [self.name, turn_timer_max])
		return false
	
	if !_set_turn_timer_max(turn_timer_max):
		return false
	
	for _player_id: int in _players:
		if _player_id != multiplayer.get_unique_id():
			_rpc_set_turn_timer_max.rpc_id(_player_id, turn_timer_max)
	
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_turn_timer_max(turn_timer_max: int) -> void:
	_set_turn_timer_max(turn_timer_max)

#endregion
#endregion
#region Tile Board

signal tile_board_set(tile_board: Dictionary[Vector2i, Tile])
signal tile_board_cleared()
signal tile_board_tile_added(tile_position: Vector2i, tile: Tile)

## Hashmap of tile coordinates to encoded tile data. (These are submitted tiles locked onto the board).
var _tile_board: Dictionary[Vector2i, Tile] = {}

func get_tile_board() -> Dictionary[Vector2i, Tile]:
	var tile_board: Dictionary[Vector2i, Tile] = {}
	for tile_position: Vector2i in _tile_board:
		tile_board[tile_position] = _tile_board[tile_position].duplicate()
	
	tile_board.make_read_only()
	return tile_board

func _set_tile_board(tile_board: Dictionary[Vector2i, Tile]) -> bool:
	_tile_board.clear()
	for tile_position: Vector2i in tile_board:
		_tile_board[tile_position] = tile_board[tile_position].duplicate()
	
	var bytes: PackedByteArray = _encode_tile_board(tile_board)
	var local_player_id: int = multiplayer.get_unique_id()
	for _player_id: int in _players:
		if _player_id != local_player_id:
			_rpc_set_tile_board.rpc_id(_player_id, bytes)
	
	tile_board_set.emit(_tile_board)
	return true

func set_tile_board(tile_board: Dictionary[Vector2i, Tile]) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInfoBoard \"%s\" | Failed to set tile board: unauthorized." % [self.name])
		return false
	
	return _set_tile_board(tile_board)

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_tile_board(bytes: PackedByteArray) -> void:
	_set_tile_board(_decode_tile_board(bytes))

func _clear_tile_board() -> bool:
	_tile_board.clear()
	
	var local_player_id: int = multiplayer.get_unique_id()
	for _player_id: int in _players:
		if _player_id != local_player_id:
			_rpc_clear_tile_board.rpc_id(_player_id)
	
	tile_board_cleared.emit()
	return true

func clear_tile_board() -> bool:
	if !is_multiplayer_authority():
		push_error("GameInfoBoard \"%s\" | Failed to clear tile board: unauthorized." % [self.name])
		return false
	
	return _clear_tile_board()

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_clear_tile_board() -> void:
	_clear_tile_board()

func _add_tile_board_tile(tile_position: Vector2i, tile: Tile) -> bool:
	if _tile_board.has(tile_position):
		push_error("GameInfoBoard \"%s\" | Failed to add tile board tile: a tile already exists at (%d, %d)." % [self.name, tile_position.x, tile_position.y])
		return false
	
	_tile_board[tile_position] = tile
	
	var bytes: PackedByteArray = PackedByteArray()
	bytes.encode_s16(0, tile_position.x)
	bytes.encode_s16(2, tile_position.y)
	bytes.encode_u8(4, _encode_tile(tile))
	for _player_id: int in _players:
		if _player_id != multiplayer.get_unique_id():
			_rpc_add_tile_board_tile.rpc_id(_player_id, bytes)
	
	tile_board_tile_added.emit(tile_position, _tile_board[tile_position])
	return true

func add_tile_board_tile(tile_position: Vector2i, tile: Tile) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInfoBoard \"%s\" | Failed to add tile board tile: unauthorized." % [self.name])
		return false
	
	return _add_tile_board_tile(tile_position, tile)

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_add_tile_board_tile(bytes: PackedByteArray) -> void:
	var tile_position: Vector2i = Vector2i(bytes.decode_s16(0), bytes.decode_s16(2))
	var tile: Tile = _decode_tile(bytes.decode_u8(4))
	_add_tile_board_tile(tile_position, tile)

#endregion
#region Tile Board Multipliers

# TODO: Tile board customization.

var _tile_board_multipliers_letter: Array[int] = DEFAULT_TILE_BOARD_MULTIPLIERS_LETTER
var _tile_board_multipliers_letter_size: Vector2i = DEFAULT_TILE_BOARD_MULTIPLIERS_LETTER_SIZE

func get_tile_board_multiplier_letter(tile_position: Vector2i) -> int:
	var wrapped: Vector2i = Vector2i(
		posmod(tile_position.x, _tile_board_multipliers_letter_size.x),
		posmod(tile_position.y, _tile_board_multipliers_letter_size.y)
	)
	return _tile_board_multipliers_letter[wrapped.x + (wrapped.y * _tile_board_multipliers_letter_size.x)]

var _tile_board_multipliers_word: Array[int] = DEFAULT_TILE_BOARD_MULTIPLIERS_WORD
var _tile_board_multipliers_word_size: Vector2i = DEFAULT_TILE_BOARD_MULTIPLIERS_WORD_SIZE

func get_tile_board_multiplier_word(tile_position: Vector2i) -> int:
	var wrapped: Vector2i = Vector2i(
		posmod(tile_position.x, _tile_board_multipliers_word_size.x),
		posmod(tile_position.y, _tile_board_multipliers_word_size.y)
	)
	return _tile_board_multipliers_word[wrapped.x + (wrapped.y * _tile_board_multipliers_word_size.x)]

#endregion
#region Submission

signal submission_validated(submission_result: SubmissionResult)

var _submission_validating: bool = false

func is_submission_validating() -> bool:
	return _submission_validating

@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_submission_validate(bytes: PackedByteArray) -> void:
	if is_multiplayer_authority():
		var player_id: int = multiplayer.get_remote_sender_id()
		var submission: Dictionary[Vector2i, Tile] = _decode_tile_board(bytes)
		_rpc_return_submission_validate.rpc_id(player_id, submission_validate(player_id, submission))

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_return_submission_validate(submission_result: SubmissionResult) -> void:
	submission_validated.emit(submission_result)
	_submission_validating = false

func submission_validate(player_id: int, submission: Dictionary[Vector2i, Tile]) -> SubmissionResult:
	# Check if this instance has player.
	if !has_player_id(player_id):
		return SubmissionResult.INVALID_PLAYER
	
	# If unauthorized, check if player id is remote.
	if !is_multiplayer_authority() && (player_id != multiplayer.get_unique_id()):
		return SubmissionResult.INVALID_PLAYER
	
	# Check if player has already submitted this turn.
	if _submission_validating || _players_classic[player_id].player_submit:
		return SubmissionResult.ALREADY_SUBMITTED
	
	# Check if submission is empty.
	if submission.is_empty():
		return SubmissionResult.EMPTY_SUBMISSION
	
	# Check for invalid player tile data.
	var player_tiles: Array[Tile] = get_player_tiles(player_id)
	for tile_position: Vector2i in submission:
		var submission_tile: Tile = submission[tile_position]
		var check: bool = false
		
		# Match player tiles to submission tiles. If no match can be found, the submission is invalid.
		# Wild tiles can match even if the faces are different.
		# Search is destructive to account for duplicate tiles (tally).
		for player_tile: Tile in player_tiles:
			if player_tile.is_wild() != submission_tile.is_wild():
				continue
			
			if !player_tile.is_wild() && (player_tile.get_face() != submission_tile.get_face()):
				continue
			
			# Tile match was found.
			check = true
			player_tiles.erase(player_tile)
			break
		
		if !check:
			return SubmissionResult.INVALID_TILES# game code problem
	
	# Check for first word length.
	if _tile_board.is_empty() && submission.size() < 2:
		return SubmissionResult.TOO_SHORT
	
	# Check for overlapping tile positions.
	# Usually happens if the client's tile board is behind on updates (e.g. another player had just submitted).
	for tile_position: Vector2i in submission:
		if _tile_board.has(tile_position):
			return SubmissionResult.TILES_OVERLAPPING
	
	# TODO: Optimize all of this.
	# Make more flexible on axis checks (hexagon tiles?)
	
	var tile_position_default: Vector2i = submission.keys()[0]
	var tile_major_axis: Vector2i = Vector2i.RIGHT# Valid submission has all tiles on one major axis.
	var tile_major_axis_min: Vector2i = tile_position_default# Min tile on major axis (including board tiles)
	var tile_major_axis_max: Vector2i = tile_position_default# Max tile on major axis (including board tiles)
	var tile_minor_axis: Vector2i = Vector2i.DOWN# Not the major axis.
	
	# Check if tiles are collinear and contiguous.
	# Get component-wise min and max (upper-left and bottom-right 2D rect).
	var tile_rect_min: Vector2i = tile_position_default
	var tile_rect_max: Vector2i = tile_position_default
	for tile_position: Vector2i in submission:
		tile_rect_min = tile_rect_min.min(tile_position)
		tile_rect_max = tile_rect_max.max(tile_position)
	
	# If both axis components are non-zero, tiles are not collinear.
	var tile_rect_delta: Vector2i = (tile_rect_max - tile_rect_min).mini(1)
	if tile_rect_delta == Vector2i.ONE:
		return SubmissionResult.TILES_NOT_COLLINEAR
	
	if submission.size() > 1:
		tile_major_axis = tile_rect_delta
		tile_minor_axis = Vector2i.ONE - tile_major_axis
	
	# NOTE: An axis is either Vector2i.DOWN or Vector2i.RIGHT.
	assert(tile_major_axis == Vector2i.DOWN || tile_major_axis == Vector2i.RIGHT)
	assert(tile_minor_axis == Vector2i.DOWN || tile_minor_axis == Vector2i.RIGHT)
	assert(tile_major_axis != tile_minor_axis)
	
	# Get major axis min and max.
	while true:
		var tile_position: Vector2i = tile_major_axis_min - tile_major_axis
		if !submission.has(tile_position) && !_tile_board.has(tile_position):
			break
		tile_major_axis_min = tile_position
	
	while true:
		var tile_position: Vector2i = tile_major_axis_max + tile_major_axis
		if !submission.has(tile_position) && !_tile_board.has(tile_position):
			break
		tile_major_axis_max = tile_position
	
	# If axis min/max is more/less than rect min/max, tiles are not contiguous.
	if tile_major_axis_min > tile_rect_min || tile_major_axis_max < tile_rect_max:
		return SubmissionResult.TILES_NOT_CONTIGUOUS
	
	# Check for center tile position (if first submission).
	if _tile_board.is_empty():
		var has_center: bool = false
		for tile_position: Vector2i in submission:
			if tile_position == Vector2i.ZERO:
				has_center = true
		if !has_center:
			return SubmissionResult.FIRST_CENTER
	
	# Check if connects to tiles already on the board.
	if !_tile_board.is_empty():
		var check: bool = false
		for tile_position: Vector2i in submission:
			if (_tile_board.has(tile_position + Vector2i.DOWN) || 
				_tile_board.has(tile_position + Vector2i.UP) ||
				_tile_board.has(tile_position + Vector2i.RIGHT) ||
				_tile_board.has(tile_position + Vector2i.LEFT)):
				check = true
				break
		if !check:
			return SubmissionResult.TILES_NOT_CONNECTED
	
	var points: int = 0
	
	# Get all words created by submission and calculate points.
	# Words are 2 or more consecutive tiles in left->right and top->bottom directions.
	var words: Array[String] = []
	# Get major axis word.
	var tile_major_axis_word: String = ""
	var tile_major_axis_position: Vector2i = tile_major_axis_min
	var tile_major_axis_points: int = 0
	var tile_major_axis_points_multiplier: int = 1
	while tile_major_axis_position <= tile_major_axis_max:
		var tile: Tile = null
		if _tile_board.has(tile_major_axis_position):
			tile = _tile_board[tile_major_axis_position]
		elif submission.has(tile_major_axis_position):
			tile = submission[tile_major_axis_position]
		
		tile_major_axis_word += tile.get_face_string()
		tile_major_axis_points += tile.get_face_points() * get_tile_board_multiplier_letter(tile_major_axis_position)
		tile_major_axis_points_multiplier *= get_tile_board_multiplier_word(tile_major_axis_position)
		tile_major_axis_position += tile_major_axis
	
	if tile_major_axis_word.length() > 1:
		words.append(tile_major_axis_word)
		points += tile_major_axis_points * tile_major_axis_points_multiplier
	
	# Get minor axis words (only from submission tiles!)
	for tile_position: Vector2i in submission:
		var tile: Tile = submission[tile_position]
		var tile_minor_axis_word: String = tile.get_face_string()
		var tile_minor_axis_points: int = tile.get_face_points() * get_tile_board_multiplier_letter(tile_position)
		var tile_minor_axis_points_multiplier: int = get_tile_board_multiplier_word(tile_position)
		
		# Navigate to minor axis min.
		var tile_minor_axis_min: Vector2i = tile_position
		while true:
			tile_minor_axis_min -= tile_minor_axis
			if _tile_board.has(tile_minor_axis_min):
				tile = _tile_board[tile_minor_axis_min]
			elif submission.has(tile_minor_axis_min):
				tile = submission[tile_minor_axis_min]
			else:
				break
			
			tile_minor_axis_word = tile.get_face_string() + tile_minor_axis_word
			tile_minor_axis_points += tile.get_face_points() * get_tile_board_multiplier_letter(tile_minor_axis_min)
			tile_minor_axis_points_multiplier *= get_tile_board_multiplier_word(tile_minor_axis_min)
		
		# Navigate to minor axis max.
		var tile_minor_axis_max: Vector2i = tile_position
		while true:
			tile_minor_axis_max += tile_minor_axis
			if _tile_board.has(tile_minor_axis_max):
				tile = _tile_board[tile_minor_axis_max]
			elif submission.has(tile_minor_axis_max):
				tile = submission[tile_minor_axis_max]
			else:
				break
			
			tile_minor_axis_word = tile.get_face_string() + tile_minor_axis_word
			tile_minor_axis_points += tile.get_face_points() * get_tile_board_multiplier_letter(tile_minor_axis_max)
			tile_minor_axis_points_multiplier *= get_tile_board_multiplier_word(tile_minor_axis_max)
		
		if tile_minor_axis_word.length() > 1:
			words.append(tile_minor_axis_word)
			points += tile_minor_axis_points * tile_minor_axis_points_multiplier
	
	# Check words with a word database.
	for word: String in words:
		if !WordDatabase.is_word(word):
			return SubmissionResult.INVALID_WORD
	
	# Submission passed all checks!
	if !is_multiplayer_authority():
		_submission_validating = true
		_rpc_request_submission_validate.rpc_id(get_multiplayer_authority(), _encode_tile_board(submission))
		return SubmissionResult.AWAITING
	
	set_player_submit(player_id, true)
	# TODO: Fill player tiles.
	set_player_tiles(player_id, player_tiles)
	set_player_points(player_id, get_player_points(player_id) + points)
	for tile_position: Vector2i in submission:
		add_tile_board_tile(tile_position, submission[tile_position])
	return SubmissionResult.OK

#endregion

#func _ready() -> void:
	#if Engine.is_editor_hint():
		#return
	#
	#updated.connect(_on_updated)
#
#func _on_updated() -> void:
	#_dirty = true
#
### Custom sort method for sorting player IDs.
### Spectators are sorted by name (ascending order) and are pushed after non-spectators.
### Non-spectators are sorted by points (descending order).
#func _sort_player_custom(a: int, b: int) -> bool:
	#if _players[a].spectator:
		#return _players[b].spectator && (_players[a].name < _players[b].name)
	#
	#if _players[b].spectator:
		#return true
	#
	#return _players[a].points > _players[b].points

func _physics_process(delta: float) -> void:
	super(delta)
	
	if Engine.is_editor_hint():
		return
	
	#if _dirty:
		## Sort players.
		#var players_sorted: Array[int] = []
		#players_sorted.append_array(_players.keys())
		#players_sorted.sort_custom(_sort_player_custom)
		#
		## Assign player places in ascending order based on players_sorted.
		#var place: int = 0
		#for player_id: int in players_sorted:
			#if !_players[player_id].spectator:
				#_players[player_id].place = place
				#place += 1
		#
		#_dirty = false
	
	if !_board_play:
		if is_multiplayer_authority():
			# Start play loop when all players are ready.
			# TODO: Start a countdown instead? If 50% of players are ready, maybe start a countdown at 20 seconds?
			if get_all_players_ready():
				set_board_play(true)
	else:
		# Process turn timer.
		if _turn_timer > 0.0:
			_turn_timer = maxf(_turn_timer - delta, 0.0)
		
		if is_multiplayer_authority():
			if _turn_timer > 3.0 && get_all_players_submit():
				# Fast-forward turn timer if all players have submitted.
				set_turn_timer(3.0)
			elif is_zero_approx(_turn_timer):
				# Increment turn count on turn timer timeout. Stop on last turn.
				if _turn_count < _turn_count_max:
					# Prepare next turn.
					set_turn_count(_turn_count + 1)
					set_turn_timer(_turn_timer_max)
					set_all_players_submit(false)
				else:
					# Reset data and stop play loop.
					# TODO: Bake leaderboard. _leaderboard_names _leaderboard_points
					clear_all_players_tiles()
					set_all_players_ready(false)
					set_all_players_submit(false)
					set_board_play(false)

#region Byte Encoding/Decoding Helpers

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

# NOTE: TileMapLayer coordinates are limited to 16 bit signed integers.
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
