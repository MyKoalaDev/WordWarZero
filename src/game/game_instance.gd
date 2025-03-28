@tool
extends Node

# Node that stores and synchronizes all data relevant to a single game instance.
# This is done to minimize processing on the server.
# Server instantiates multiple game instances for each player-created lobby.
# Each player only instantiates the one game instance they've joined.

# TODO:
# Player created lobbies (instance name and password).
# Customizable board multipliers (set by player host).
# 

# TODO:
# Game.gd:
# Server creates new GameInstance, assigns unique name
# Server rpc -> Client to create new GameInstance, passes unique name
# Server adds player to GameInstance via add_player. this then rpc syncs with client
# rpcs must be ordered to guarantee GameInstance exists on client

# TODO: Game instance list (lobby system)
# TODO: bake leaderboard data into array (bake data such as player name and points)
# TODO: Host player functionality (customize game instance settings such as turn count, turn timer, force start game, etc.)

class _PlayerData:
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

signal updated()

## Indicates if this should not be automatically deleted when this has no players (used by game.gd).
var persistent: bool = false

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
		push_error("GameInstance \"%s\" | Failed to force sync with player ID '%d': only the authority can force sync." % [self.name, player_id])
		return false
	
	if !_players.has(player_id):
		push_error("GameInstance \"%s\" | Failed to force sync with player ID '%d': player ID does not exist." % [self.name, player_id])
		return false
	
	if player_id == multiplayer.get_unique_id():
		push_error("GameInstance \"%s\" | Failed to force sync with player ID '%d': cannot force sync with self." % [self.name, player_id])
		return false
	
	_rpc_set_play.rpc_id(player_id, _play)
	
	_rpc_set_turn_count.rpc_id(player_id, _turn_count)
	_rpc_set_turn_count_max.rpc_id(player_id, _turn_count_max)
	_rpc_set_turn_timer.rpc_id(player_id, _turn_timer)
	_rpc_set_turn_timer_max.rpc_id(player_id, _turn_timer_max)
	
	_rpc_set_tile_board.rpc_id(player_id, _encode_tile_board(_tile_board))
	
	for _player_id: int in _players:
		var player_data: _PlayerData = _players[_player_id]
		_rpc_set_player_name.rpc_id(player_id, _player_id, player_data.name)
		_rpc_set_player_ready.rpc_id(player_id, _player_id, player_data.ready)
		_rpc_set_player_spectator.rpc_id(player_id, _player_id, player_data.spectator)
		_rpc_set_player_submitted.rpc_id(player_id, _player_id, player_data.submitted)
		# NOTE: Each player should only know about their own tiles.
		#_rpc_set_player_tiles.rpc_id(player_id, _player_id, player_data.tiles)
		_rpc_set_player_points.rpc_id(player_id, _player_id, player_data.points)
	
	return true

#region Instance

var _instance_name: String = ""

func get_instance_name() -> String:
	return _instance_name

func set_instance_name(instance_name: String) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstance \"%s\" | Failed to set instance name to '%s': only the authority can set instance name." % [self.name, instance_name])
		return false
	
	_instance_name = instance_name
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_instance_name(instance_name: String) -> void:
	_instance_name = instance_name
	
	updated.emit()

var _instance_public: bool = false
var _instance_password: String = ""

func check_instance_password(instance_password: String) -> bool:
	return _instance_password.is_empty() || (_instance_password == instance_password)

func set_instance_password(instance_password: String) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstance \"%s\" | Failed to set instance password: only the authority can set instance password." % [self.name])
		return false
	
	_instance_password = instance_password
	
	if _instance_password.is_empty() != _instance_public:
		_instance_public = !_instance_public
		_rpc_set_instance_public.rpc(_instance_public)
	
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_set_instance_public(instance_public: bool) -> void:
	_instance_public = instance_public
	
	updated.emit()

#endregion
#region Play

func set_play(play: bool) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstance \"%s\" | Failed to set play to '%s': only the authority can set play." % [self.name, str(play)])
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
		push_error("GameInstance \"%s\" | Failed to set turn count to '%d': only the authority can set turn count." % [self.name, turn_count])
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
		push_error("GameInstance \"%s\" | Failed to set turn count max to '%d': only the authority can set turn count max." % [self.name, turn_count_max])
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
		push_error("GameInstance \"%s\" | Failed to set turn timer to '%d': only the authority can set turn timer." % [self.name, turn_timer])
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
		push_error("GameInstance \"%s\" | Failed to set turn timer max to '%d': only the authority can set turn timer max." % [self.name, turn_timer_max])
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
		push_error("GameInstance \"%s\" | Failed to set tile board: only the authority can set tile board." % [self.name])
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
		push_error("GameInstance \"%s\" | Failed to clear tile board: only the authority can clear tile board." % [self.name])
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
		push_error("GameInstance \"%s\" | Failed to add tile board tile: only the authority can add tile board tile." % [self.name])
		return false
	
	if _tile_board.has(tile_position):
		push_error("GameInstance \"%s\" | Failed to add tile board tile: a tile already exists at (%d, %d)." % [self.name, tile_position.x, tile_position.y])
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
#region Tile Board Multipliers

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
#region Player

## Hashmap of player IDs (multiplayer peer id) to player data.
var _players: Dictionary[int, _PlayerData] = {}

func is_empty() -> bool:
	return _players.is_empty()

#region Player ID

signal player_id_added(player_id: int)
signal player_id_removed(player_id: int)

func get_player_ids() -> Array[int]:
	return _players.keys()

func has_player_id(player_id: int) -> bool:
	return _players.has(player_id)

func add_player_id(player_id: int) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstance \"%s\" | Failed to add player ID '%d': only the authority can add player ID." % [self.name, player_id])
		return false
	
	if _players.has(player_id):
		push_error("GameInstance \"%s\" | Failed to add player ID '%d': player ID already exists." % [self.name, player_id])
		return false
	
	_players[player_id] = _PlayerData.new()
	
	for _player_id: int in _players:
		if _player_id != multiplayer.get_unique_id():
			_rpc_add_player_id.rpc_id(_player_id, player_id)
	
	player_id_added.emit(player_id)
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_add_player_id(player_id: int) -> void:
	if _players.has(player_id):
		return
	
	_players[player_id] = _PlayerData.new()
	
	player_id_added.emit(player_id)
	updated.emit()

func remove_player_id(player_id: int) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstance \"%s\" | Failed to remove player ID '%d': only the authority can remove player ID." % [self.name, player_id])
		return false
	
	if !_players.has(player_id):
		push_error("GameInstance \"%s\" | Failed to remove player ID '%d': player ID does not exist." % [self.name, player_id])
		return false
	
	_players.erase(player_id)
	
	for _player_id: int in _players:
		if _player_id != multiplayer.get_unique_id():
			_rpc_remove_player_id.rpc_id(_player_id, player_id)
	
	player_id_removed.emit(player_id)
	updated.emit()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _rpc_remove_player_id(player_id: int) -> void:
	if !_players.has(player_id):
		return
	
	_players.erase(player_id)
	
	player_id_removed.emit(player_id)
	updated.emit()

#endregion
#region Player Name

func get_player_name(player_id: int) -> String:
	if !_players.has(player_id):
		push_error("GameInstance \"%s\" | Failed to get player name for player ID '%d': could not find player ID." % [self.name, player_id])
		return ""
	
	return _players[player_id].name

func set_player_name(player_id: int, player_name: String) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstance \"%s\" | Failed to set player name to '%s' for player ID '%d': only the authority can set player name." % [self.name, player_name, player_id])
		return false
	
	if !_players.has(player_id):
		push_error("GameInstance \"%s\" | Failed to set player name to '%s' for player ID '%d': could not find player ID." % [self.name, player_name, player_id])
		return false
	
	if _players[player_id].name == player_name:
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
		push_error("GameInstance \"%s\" | Failed to set all players ready to '%s': only the authority can set all players ready." % [self.name, str(player_ready)])
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
		push_error("GameInstance \"%s\" | Failed to get player ready for player ID '%d': could not find player ID." % [self.name, player_id])
		return false
	
	return _players[player_id].ready

func set_player_ready(player_id: int, player_ready: bool) -> bool:
	if !is_multiplayer_authority() && (player_id != multiplayer.get_unique_id()):
		push_error("GameInstance \"%s\" | Failed to set player ready to '%s' for player ID '%d': only the authority can set remote player ready." % [self.name, player_ready, player_id])
		return false
	
	if !_players.has(player_id):
		push_error("GameInstance \"%s\" | Failed to set player ready to '%s' for player ID '%d': could not find player ID." % [self.name, player_ready, player_id])
		return false
	
	if _players[player_id].ready == player_ready:
		return true
	
	if !is_multiplayer_authority():
		_rpc_request_set_player_ready.rpc_id(get_multiplayer_authority(), player_ready)
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
func _rpc_request_set_player_ready(player_ready: bool) -> void:
	var player_id: int = multiplayer.get_remote_sender_id()
	if is_multiplayer_authority():
		set_player_ready(player_id, player_ready)

#endregion
#region Player Spectator

func get_player_spectator(player_id: int) -> bool:
	if !_players.has(player_id):
		push_error("GameInstance \"%s\" | Failed to get player spectator for player ID '%d': could not find player ID." % [self.name, player_id])
		return false
	
	return _players[player_id].spectator

func set_player_spectator(player_id: int, player_spectator: bool) -> bool:
	if !is_multiplayer_authority() && player_id != multiplayer.get_unique_id():
		push_error("GameInstance \"%s\" | Failed to set player spectator to '%s' for player ID '%d': only the authority can set remote player spectator." % [self.name, player_spectator, player_id])
		return false
	
	if !_players.has(player_id):
		push_error("GameInstance \"%s\" | Failed to set player spectator to '%s' for player ID '%d': could not find player ID." % [self.name, player_spectator, player_id])
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
		push_error("GameInstance \"%s\" | Failed to clear all players submitted: only the authority can clear all players submitted." % [self.name])
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
		push_error("GameInstance \"%s\" | Failed to get player submitted for player ID '%d': could not find player ID." % [self.name, player_id])
		return false
	
	return _players[player_id].submitted

func set_player_submitted(player_id: int, player_submitted: bool) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstance \"%s\" | Failed to set player submitted to '%s' for player ID '%d': only the authority can set remote player submitted." % [self.name, player_submitted, player_id])
		return false
	
	if !_players.has(player_id):
		push_error("GameInstance \"%s\" | Failed to set player submitted to '%s' for player ID '%d': could not find player ID." % [self.name, player_submitted, player_id])
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
		push_error("GameInstance \"%s\" | Failed to clear all players tiles: only the authority can clear all players tiles." % [self.name])
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
		push_error("GameInstance \"%s\" | Failed to get player tiles for player ID '%d': could not find player ID." % [self.name, player_id])
		return []
	
	var tiles: Array[Tile] = []
	for tile: Tile in _players[player_id].tiles:
		tiles.append(Tile.new(tile.get_face(), tile.is_wild()))
	return tiles

func set_player_tiles(player_id: int, player_tiles: Array[Tile]) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstance \"%s\" | Failed to set player tiles to '%s' for player ID '%d': only the authority can set player tiles." % [self.name, str(player_tiles), player_id])
		return false
	
	if !_players.has(player_id):
		push_error("GameInstance \"%s\" | Failed to set player tiles to '%s' for player ID '%d': could not find player ID." % [self.name, str(player_tiles), player_id])
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
		push_error("GameInstance \"%s\" | Failed to clear all players points: only the authority can clear all players points." % [self.name])
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
		push_error("GameInstance \"%s\" | Failed to get player points for player ID '%d': could not find player ID." % [self.name, player_id])
		return -1
	
	return _players[player_id].points

func set_player_points(player_id: int, player_points: int) -> bool:
	if !is_multiplayer_authority():
		push_error("GameInstance \"%s\" | Failed to set player points to '%s' for player ID '%d': only the authority can set player points." % [self.name, str(player_points), player_id])
		return false
	
	if !_players.has(player_id):
		push_error("GameInstance \"%s\" | Failed to set player points to '%s' for player ID '%d': could not find player ID." % [self.name, str(player_points), player_id])
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
		push_error("GameInstance \"%s\" | Failed to get player place for player ID '%d': could not find player ID." % [self.name, player_id])
		return -1
	
	return _players[player_id].place

#endregion
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
	
	# If not the authority, check if player id is remote.
	if !is_multiplayer_authority() && (player_id != multiplayer.get_unique_id()):
		return SubmissionResult.INVALID_PLAYER
	
	# Check if player has already submitted this turn.
	if _submission_validating || get_player_submitted(player_id):
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
	
	set_player_submitted(player_id, true)
	# TODO: Fill player tiles.
	set_player_tiles(player_id, player_tiles)
	set_player_points(player_id, get_player_points(player_id) + points)
	for tile_position: Vector2i in submission:
		add_tile_board_tile(tile_position, submission[tile_position])
	return SubmissionResult.OK

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
		push_error("GameInstance \"%s\" | Multiplayer is not active." % [self.name])
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
