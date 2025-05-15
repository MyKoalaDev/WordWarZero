@tool
extends Node

# game_info.gd should not care about multiplayer mode
# simply receive commands, and check authorities

# TODO:
# how to deal with multiple board types?
# how is swapping handled?
# needs to change script types
# for now, dont support switch board types, just determine it on board creation
# game_info handles syncing rpcs for boards, so keep an enum here for scripts

# how will boards be instanced server vs client?

# connect to server via menu button -> game.gd
#   - game.gd join_official()
#   - game.gd tracks network, and configures game_instance.gd on network signals
#   - on server start: game.gd calls game_instance.gd run_config_server()
#   - on client start: game.gd calls game_instance.gd run_config_client()
#     - basically, config is needed to configure for RPC calls and prepping tree
#   - game.gd calls some sort of reset/clean on client or server stop
#     - this reset will clear all players and boards locally (no RPCs)
# client wont have any game instances

## Game Instance node that represents the game client/server.

enum BoardType {
	CLASSIC = 0,
	MASSIVE = 1,
}

const GameInfoPlayers: = preload("game_info_players.gd")
const GameInfoBoard: = preload("game_info_board.gd")
const GameInfoBoardClassic: = preload("game_info_board_classic.gd")

@onready
var players: GameInfoPlayers = $players as GameInfoPlayers

var _boards: Dictionary[int, GameInfoBoard] = {}

var _local_board: GameInfoBoard = null

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	

func _create_board(board_type: BoardType = BoardType.CLASSIC) -> GameInfoBoard:
	var board: GameInfoBoard = null
	match board_type:
		BoardType.CLASSIC:
			board = GameInfoBoardClassic.new()
		BoardType.MASSIVE:
			assert(false)
	
	var board_id: int = 0
	while _boards.has(board_id):
		board_id += 1
	
	_boards[board_id] = board
	add_child(board, true)
	
	var board_name: String = "game_instance_board_%03d" % [board_id]
	board.name = board_name
	assert(board.name == board_name)
	return board

func _remove_board(board_id: int) -> void:
	if _boards.has(board_id):
		remove_child(_boards[board_id])
		_boards[board_id].queue_free()
		_boards.erase(board_id)
