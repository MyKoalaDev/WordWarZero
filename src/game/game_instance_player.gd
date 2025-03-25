@tool
extends Node

# Server-managed fields.
var player_name: String = "Player"
var player_ready: bool = false
var player_spectator: bool = false
var player_submitted: bool = false
var player_points: int = 0
var player_tiles: Array[Tile] = []
