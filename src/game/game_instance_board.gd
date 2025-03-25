@tool
extends Node

enum SubmissionResult {
	OK,
	ERROR,
	TIMED_OUT,
	STILL_PROCESSING,
	ALREADY_SUBMITTED,
	EMPTY_SUBMISSION,
	INVALID_SUBMISSION,
	INVALID_TILES,
	TILES_OVERLAPPING,
	TILES_REDUNDANT,
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
		SubmissionResult.TILES_REDUNDANT:
			return "Invalid submission! (Game problem)"
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

func validate_submission(tile_board: Dictionary[Vector2i, int], tile_board_submission: Dictionary[Vector2i, int]) -> SubmissionResult:
	# TODO: Move submitted and player tiles check.
	# Check if player has already submitted this turn.
	#if _game_data.get_player_submitted(player_id):
		#_rpc_submit_result.rpc_id(player_id, SubmissionResult.ALREADY_SUBMITTED)
		#return SubmissionResult.ALREADY_SUBMITTED
	#
	## Check for invalid player tile data.
	#var player_tiles: Array[int] = _game_data.get_player_tiles(player_id)
	#for tile_position: Vector2i in tile_board_submission:
		#var face: int = tile_board_submission[tile_position]
		#if !player_tiles.has(face):
			#_rpc_submit_result.rpc_id(player_id, SubmissionResult.INVALID_TILES)
			#return SubmissionResult.INVALID_TILES# game code problem
		#player_tiles.erase(face)
	
	# Empty submissions are invalid.
	if tile_board_submission.is_empty():
		return SubmissionResult.EMPTY_SUBMISSION
	
	# Check for first word length.
	if tile_board.is_empty() && tile_board_submission.size() < 2:
		return SubmissionResult.TOO_SHORT
	
	var tile_positions: Array[Vector2i] = tile_board_submission.keys()
	
	# Check for overlapping tile positions.
	for tile_position: Vector2i in tile_positions:
		if tile_board.has(tile_position):
			return SubmissionResult.TILES_OVERLAPPING# too slow!
	
	# Check for redundant tile positions.
	for index_a: int in tile_positions.size():
		for index_b: int in tile_positions.size():
			if index_a == index_b:
				continue
			if tile_positions[index_a] == tile_positions[index_b]:
				return SubmissionResult.TILES_REDUNDANT# game code problem
	
	var tile_major_axis: Vector2i = Vector2i.RIGHT# Valid tile_board_submission has all tiles on one major axis.
	var tile_major_axis_min: Vector2i = tile_positions[0]# Min tile on major axis (including board tiles)
	var tile_major_axis_max: Vector2i = tile_positions[0]# Max tile on major axis (including board tiles)
	var tile_minor_axis: Vector2i = Vector2i.DOWN# Not the major axis.
	
	# Check if tiles are collinear and contiguous.
	# Get component-wise min and max (upper-left and bottom-right 2D rect).
	var tile_rect_min: Vector2i = tile_positions[0]
	var tile_rect_max: Vector2i = tile_positions[0]
	for tile_position: Vector2i in tile_positions:
		tile_rect_min = tile_rect_min.min(tile_position)
		tile_rect_max = tile_rect_max.max(tile_position)
	
	# If both axis components are non-zero, tiles are not collinear.
	var tile_rect_delta: Vector2i = (tile_rect_max - tile_rect_min).mini(1)
	if tile_rect_delta == Vector2i.ONE:
		return SubmissionResult.TILES_NOT_COLLINEAR
	
	if tile_board_submission.size() > 1:
		tile_major_axis = tile_rect_delta
		tile_minor_axis = Vector2i.ONE - tile_major_axis
	
	# NOTE: An axis is either Vector2i.DOWN or Vector2i.RIGHT.
	assert(tile_major_axis == Vector2i.DOWN || tile_major_axis == Vector2i.RIGHT)
	assert(tile_minor_axis == Vector2i.DOWN || tile_minor_axis == Vector2i.RIGHT)
	assert(tile_major_axis != tile_minor_axis)
	
	# Get major axis min and max.
	while true:
		var tile_position: Vector2i = tile_major_axis_min - tile_major_axis
		if !tile_board_submission.has(tile_position) && !tile_board.has(tile_position):
			break
		tile_major_axis_min = tile_position
	
	while true:
		var tile_position: Vector2i = tile_major_axis_max + tile_major_axis
		if !tile_board_submission.has(tile_position) && !tile_board.has(tile_position):
			break
		tile_major_axis_max = tile_position
	
	# If axis min/max is more/less than rect min/max, tiles are not contiguous.
	if tile_major_axis_min > tile_rect_min || tile_major_axis_max < tile_rect_max:
		return SubmissionResult.TILES_NOT_CONTIGUOUS
	
	# Check for center tile position (if first board is empty).
	if tile_board.is_empty():
		var has_center: bool = false
		for tile_position: Vector2i in tile_positions:
			if tile_position == Vector2i.ZERO:
				has_center = true
		if !has_center:
			return SubmissionResult.FIRST_CENTER
	
	# Check if at least one submission tile connects to a board tile.
	if !tile_board.is_empty():
		var check: bool = false
		for tile_position: Vector2i in tile_positions:
			if (tile_board.has(tile_position + Vector2i.DOWN) ||
				tile_board.has(tile_position + Vector2i.UP) ||
				tile_board.has(tile_position + Vector2i.RIGHT) ||
				tile_board.has(tile_position + Vector2i.LEFT)):
					check = true
					break
		if !check:
			return SubmissionResult.TILES_NOT_CONNECTED
	
	var points: int = 0
	
	# Get all words created by tile_board_submission and calculate points.
	# Words are 2 or more consecutive tiles in left->right and top->bottom directions.
	var words: Array[String] = []
	# Get major axis word.
	var tile_major_axis_word: String = ""
	var tile_major_axis_position: Vector2i = tile_major_axis_min
	var tile_major_axis_points: int = 0
	var tile_major_axis_points_multiplier: int = 1
	while tile_major_axis_position <= tile_major_axis_max:
		var tile_data: int = 0
		if tile_board.has(tile_major_axis_position):
			tile_data = tile_board[tile_major_axis_position]
		elif tile_board_submission.has(tile_major_axis_position):
			tile_data = tile_board_submission[tile_major_axis_position]
		
		var tile: Tile = Tile.decode(tile_data)
		tile_major_axis_word += tile.get_face_string()
		tile_major_axis_points += tile.get_face_points(tile_face) * tile_board.get_board_letter_multiplier(tile_major_axis_position)
		tile_major_axis_points_multiplier *= tile_board.get_board_word_multiplier(tile_major_axis_position)
		tile_major_axis_position += tile_major_axis
	
	if tile_major_axis_word.length() > 1:
		words.append(tile_major_axis_word)
		points += tile_major_axis_points * tile_major_axis_points_multiplier
	
	# Get minor axis words (only from tile_board_submission tiles!)
	for tile_position: Vector2i in tile_positions:
		var tile_face: int = tile_board_submission[tile_position]
		var tile_minor_axis_word: String = Tile.get_face_string(tile_face)
		var tile_minor_axis_points: int = Tile.get_face_points(tile_face) * tile_board.get_board_letter_multiplier(tile_position)
		var tile_minor_axis_points_multiplier: int = 1 * tile_board.get_board_word_multiplier(tile_position)
		
		# Navigate to minor axis min.
		var tile_minor_axis_min: Vector2i = tile_position
		while true:
			tile_minor_axis_min -= tile_minor_axis
			if tile_board.has_tile_at(tile_minor_axis_min):
				tile_face = tile_board.get_tile_at(tile_minor_axis_min)
			elif tile_board_submission.has(tile_minor_axis_min):
				tile_face = tile_board_submission[tile_minor_axis_min]
			else:
				break
			
			tile_minor_axis_word = Tile.get_face_string(tile_face) + tile_minor_axis_word
			tile_minor_axis_points += Tile.get_face_points(tile_face) * tile_board.get_board_letter_multiplier(tile_minor_axis_min)
			tile_minor_axis_points_multiplier *= tile_board.get_board_word_multiplier(tile_minor_axis_min)
		
		# Navigate to minor axis max.
		var tile_minor_axis_max: Vector2i = tile_position
		while true:
			tile_minor_axis_max += tile_minor_axis
			if tile_board.has_tile_at(tile_minor_axis_max):
				tile_face = tile_board.get_tile_at(tile_minor_axis_max)
			elif tile_board_submission.has(tile_minor_axis_max):
				tile_face = tile_board_submission[tile_minor_axis_max]
			else:
				break
			
			tile_minor_axis_word = Tile.get_face_string(tile_face) + tile_minor_axis_word
			tile_minor_axis_points += Tile.get_face_points(tile_face) * tile_board.get_board_letter_multiplier(tile_minor_axis_max)
			tile_minor_axis_points_multiplier *= tile_board.get_board_word_multiplier(tile_minor_axis_max)
		
		if tile_minor_axis_word.length() > 1:
			words.append(tile_minor_axis_word)
			points += tile_minor_axis_points * tile_minor_axis_points_multiplier
	
	# Check words with WordCheck.
	for word: String in words:
		if !(_word_check.is_word(word)):
			_rpc_submit_result.rpc_id(player_id, SubmissionResult.INVALID_WORD)
			return SubmissionResult.INVALID_WORD
	
	return SubmissionResult.OK

# TODO: move this to game instance or gane
	# Submission passed all checks!
	# Update game board state (add tiles), remove player tiles, and set player as submitted.
	#for coordinates: Vector2i in tile_board_submission:
		#var face: int = tile_board_submission[coordinates]
		#tile_board.add_tile(coordinates, face)
	#
	#_game_data.set_player_tiles(player_id, player_tiles)
	#_game_data.set_player_points(player_id, _game_data.get_player_points(player_id) + points)
	#_game_data.set_player_submitted(player_id, true)
	
	#_fill_player_tiles(player_id)
	
	#_rpc_submit_result.rpc_id(player_id, SubmissionResult.OK, points)
