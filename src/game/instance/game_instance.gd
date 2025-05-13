@tool
extends Node

## Game Instance node that represents the game client/server.

#const GameInstanceLobby: = preload("game_instance_lobby.gd")
const GameInstancePlayers: = preload("game_instance_players.gd")

var players: GameInstancePlayers = null

@onready
var _root_lobbies: Node = $lobbies as Node

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	players = get_node(NodePath("game_instance_players")) as GameInstancePlayers
