@tool
extends Node2D
class_name TileBoardInstance2D

# NOTE: Tiles are not instantiated nor freed by add_tile or remove_tile.

enum BoardMultiplier {
	LETTER_1X,
	LETTER_2X,
	LETTER_3X,
	LETTER_4X,
	WORD_1X,
	WORD_2X,
	WORD_3X,
	WORD_4X,
}

@export
var board_repeat_size: Vector2i = Vector2i(16, 16):
	get:
		return board_repeat_size
	set(value):
		board_repeat_size = value.maxi(1)

## BoardMultiplier 2D array (BoardMultiplier[x][y]).
var _board_multipliers: Array[Array] = []

@onready
var _tile_map_layer: TileMapLayer = $parallax_2d/tile_map_layer as TileMapLayer

func global_to_map(global_pos: Vector2) -> Vector2i:
	return _tile_map_layer.local_to_map(_tile_map_layer.to_local(global_pos))
	#return _tile_map_layer.local_to_map(to_local(global_pos - _tile_map_layer.position))

func map_to_global(coordinates: Vector2i) -> Vector2:
	return _tile_map_layer.to_global(_tile_map_layer.map_to_local(coordinates))
	#return global_transform * (Vector2(coordinates * _tile_map_layer.tile_set.tile_size))

#region Tiles

var _tiles: Dictionary[Vector2i, Tile2D] = {}

func clear_tiles() -> void:
	for coordinates: Vector2i in _tiles:
		remove_child(_tiles[coordinates])
		_tiles[coordinates].queue_free()
	_tiles.clear()

func add_tile(coordinates: Vector2i, tile: Tile2D) -> bool:
	if !is_instance_valid(tile):
		return false
	
	if _tiles.has(coordinates):
		return false
	
	var parent: Node = tile.get_parent()
	if is_instance_valid(parent):
		parent.remove_child(tile)
	add_child(tile)
	
	tile.global_position = map_to_global(coordinates)
	tile.reset_physics_interpolation()
	
	_tiles[coordinates] = tile
	
	return true

func remove_tile(coordinates: Vector2i) -> Tile2D:
	if !_tiles.has(coordinates):
		return null
	
	var tile: Tile2D = _tiles[coordinates]
	remove_child(tile)
	
	_tiles.erase(coordinates)
	
	return tile

func has_tile_at(coordinates: Vector2i) -> bool:
	return _tiles.has(coordinates)

func is_empty() -> bool:
	return _tiles.is_empty()

#endregion

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	# Initialize BoardMultiplier 2D array.
	# Reads each cell atlas coords from tile map layer, mapping to BoardMultiplier.
	_board_multipliers.resize(board_repeat_size.x)
	for x: int in board_repeat_size.x:
		_board_multipliers[x].resize(board_repeat_size.y)
		for y: int in board_repeat_size.y:
			var atlas_coords: Vector2i = _tile_map_layer.get_cell_atlas_coords(Vector2i(x, y))
			var atlas_id: int = atlas_coords.x + (atlas_coords.y * 4)
			match atlas_id:
				0:
					_board_multipliers[x][y] = BoardMultiplier.LETTER_1X
				1:
					_board_multipliers[x][y] = BoardMultiplier.LETTER_2X
				2:
					_board_multipliers[x][y] = BoardMultiplier.LETTER_3X
				3:
					_board_multipliers[x][y] = BoardMultiplier.LETTER_4X
				4:
					_board_multipliers[x][y] = BoardMultiplier.WORD_1X
				5:
					_board_multipliers[x][y] = BoardMultiplier.WORD_2X
				6:
					_board_multipliers[x][y] = BoardMultiplier.WORD_3X
				7:
					_board_multipliers[x][y] = BoardMultiplier.WORD_4X
				_:
					_board_multipliers[x][y] = BoardMultiplier.LETTER_1X

func get_board_letter_multiplier(tile_position: Vector2i) -> int:
	var wrapped: Vector2i = Vector2i(
		posmod(tile_position.x, _board_multipliers.size()),
		posmod(tile_position.y, _board_multipliers[0].size())
	)
	match _board_multipliers[wrapped.x][wrapped.y]:
		BoardMultiplier.LETTER_1X:
			return 1
		BoardMultiplier.LETTER_2X:
			return 2
		BoardMultiplier.LETTER_3X:
			return 3
		BoardMultiplier.LETTER_4X:
			return 4
	return 1

func get_board_word_multiplier(tile_position: Vector2i) -> int:
	var wrapped: Vector2i = Vector2i(
		posmod(tile_position.x, _board_multipliers.size()),
		posmod(tile_position.y, _board_multipliers[0].size())
	)
	match _board_multipliers[wrapped.x][wrapped.y]:
		BoardMultiplier.WORD_1X:
			return 1
		BoardMultiplier.WORD_2X:
			return 2
		BoardMultiplier.WORD_3X:
			return 3
		BoardMultiplier.WORD_4X:
			return 4
	return 1
