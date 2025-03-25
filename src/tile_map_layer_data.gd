@tool
extends TileMapLayer

@export_tool_button("Extract")
var extract: Callable = _extract

func _extract() -> void:
	var multipliers_letters: Array[int] = []
	var multipliers_letters_width: int = 0
	
	var multipliers_words: Array[int] = []
	var multipliers_words_width: int = 0
	
	var rect: Rect2i = get_used_rect()
	
	multipliers_letters.resize(rect.size.x * rect.size.y)
	multipliers_letters.fill(1)
	multipliers_letters_width = rect.size.x
	
	multipliers_words.resize(rect.size.x * rect.size.y)
	multipliers_words.fill(1)
	multipliers_words_width = rect.size.x
	
	for multiplier_position: Vector2i in get_used_cells():
		var atlas_coords: Vector2i = get_cell_atlas_coords(multiplier_position)
		var atlas_id: int = atlas_coords.x + (atlas_coords.y * 4)
		var multiplier_index: int = (multiplier_position - rect.position).x + (rect.size.x * (multiplier_position - rect.position).y)
		match atlas_id:
			0:
				multipliers_letters[multiplier_index] = 1
			1:
				multipliers_letters[multiplier_index] = 2
			2:
				multipliers_letters[multiplier_index] = 3
			3:
				multipliers_letters[multiplier_index] = 4
			4:
				multipliers_words[multiplier_index] = 1
			5:
				multipliers_words[multiplier_index] = 2
			6:
				multipliers_words[multiplier_index] = 3
			7:
				multipliers_words[multiplier_index] = 4
			_:
				multipliers_letters[multiplier_index] = 1
	
	print("Letter Multipliers: ")
	print("[")
	var buffer: String = "\t"
	for index: int in multipliers_letters.size():
		buffer += str(multipliers_letters[index]) + ","
		if (index + 1) % multipliers_letters_width == 0:
			buffer += "\n\t"
		else:
			buffer += " "
	print(buffer)
	print("]")
	print()
	print("Word Multipliers: ")
	print("[")
	buffer = "\t"
	for index: int in multipliers_words.size():
		buffer += str(multipliers_words[index]) + ","
		if (index + 1) % multipliers_words_width == 0:
			buffer += "\n\t"
		else:
			buffer += " "
	print(buffer)
	print("]")
