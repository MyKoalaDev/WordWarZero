@tool
extends Node2D
class_name GameBoard

# TODO:
# where to instantiate newly created tiles?
# sync game board state (need a dictionary i suppose)

# TODO:
# do a submission check locally before sending to server (save time and rpcs)
# only send if local validated

var active: bool = false

@onready
var _game_tiles: GameTiles = $game_tiles as GameTiles
@onready
var _tile_board: TileBoard = $tile_board as TileBoard
@onready
var _game_camera: GameCamera = $game_camera as GameCamera
@onready
var _gui_label_turn: RichTextLabel = $gui/gui/panel_top/label_turn as RichTextLabel
@onready
var _gui_alert: Control = $gui/gui/alert as Control
var _gui_alert_tween: Tween = null
@onready
var _gui_alert_label: RichTextLabel = $gui/gui/alert/rich_text_label as RichTextLabel
@onready
var _button_submit: Button = $gui/gui/panel_bottom/h_box_container/button_submit as Button
@onready
var _button_recall: Button = $gui/gui/panel_bottom/h_box_container/button_recall as Button
@onready
var _button_swap: Button = $gui/gui/panel_bottom/h_box_container/button_swap as Button
@onready
var _word_check: WordCheck = $word_check as WordCheck

var _turn_count: int = 0
var _turn_count_max: int = 0
var _turn_time: float = 0.0
var _turn_time_max: float = 0.0

var _loop: bool = false
func is_loop() -> bool:
	return _loop

func start_loop(turn_count: int = DEFAULT_TURN_COUNT, turn_time: float = DEFAULT_TURN_TIME) -> void:
	if !multiplayer.has_multiplayer_peer() || !is_multiplayer_authority():
		return
	
	if _loop:
		return
	_loop = true
	
	_turn_count = 0
	_turn_count_max = turn_count
	_turn_time = 0.0
	_turn_time_max = turn_time
	
	_tile_board.clear_tiles()
	_game_data.clear_all_player_points()
	
	next_turn()

func next_turn() -> void:
	# Start next turn.
	_turn_count += 1
	_turn_time = _turn_time_max
	# set players submit
	# NOTE: players dont set submit at all, only server
	# server game board submit passes submission, then sets submit and notifies all peers
	
	for player_id: int in _game_data.get_player_ids():
		_fill_player_tiles(player_id)

var _await_submit_results: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_button_submit.pressed.connect(_on_button_submit_pressed)
	_button_submit.disabled = true
	_button_recall.pressed.connect(_on_button_recall_pressed)
	_button_recall.disabled = true
	_button_swap.pressed.connect(_on_button_swap_pressed)
	_button_swap.disabled = true
	
	_gui_alert.modulate.a = 0.0

func _on_button_submit_pressed() -> void:
	if _await_submit_results:
		return
	if multiplayer.has_multiplayer_peer():
		var bytes: PackedByteArray = _game_tiles.encode_submission_bytes()
		if !bytes.is_empty():
			_rpc_request_submit.rpc_id(get_multiplayer_authority(), bytes)
			_await_submit_results = true

func _on_button_recall_pressed() -> void:
	_game_tiles.recall_tiles()

func _on_button_swap_pressed() -> void:
	if multiplayer.has_multiplayer_peer():
		_rpc_request_swap.rpc_id(get_multiplayer_authority())

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if !is_visible_in_tree():
		return
	
	_gui_label_turn.clear()
	_gui_label_turn.text = ""
	_gui_label_turn.append_text("[color=white]Turn %d / %d | Time Left: [/color]" % [_turn_count, _turn_count_max])
	if _turn_time > 10.0:
		_gui_label_turn.append_text("[color=white]%01d:%02d[/color]" % [int(_turn_time / 60.0), int(fmod(_turn_time, 60.0))])
	else:
		_gui_label_turn.append_text("[color=red][b]%01d:%02d[/b][/color]" % [int(_turn_time / 60.0), int(fmod(_turn_time, 60.0))])

func _fill_player_tiles(player_id: int) -> void:
	if multiplayer.has_multiplayer_peer() && is_multiplayer_authority():
		if _game_data.get_player_spectator(player_id):
			return
		var player_tiles: Array[int] = _game_data.get_player_tiles(player_id)
		while player_tiles.size() < DEFAULT_TILE_COUNT:
			player_tiles.append(Tile.get_random_face())
		_game_data.set_player_tiles(player_id, player_tiles)

var _player_submission_ids: Array[int] = []
var _player_submission_processes: Array[Callable] = []
var _player_submission_processing: bool = false

# Client to server: submit tiles.
# tile_pos_x: 2 bytes (16 bit signed int)
# tile_pos_y: 2 bytes (16 bit signed int)
# tile_face: 1 byte (8 bit unsigned int)
@rpc("any_peer", "call_local", "reliable", 0)
func _rpc_request_submit(bytes: PackedByteArray) -> void:
	if multiplayer.has_multiplayer_peer() && is_multiplayer_authority():
		var player_id: int = multiplayer.get_remote_sender_id()
		
		var player_submission: Dictionary[Vector2i, int] = _game_tiles.decode_submission_bytes(bytes)
		if player_submission.is_empty():
			_rpc_submit_result.rpc_id(player_id, SubmissionResult.INVALID_SUBMISSION)
			return
		
		if _player_submission_ids.has(player_id):
			_rpc_submit_result.rpc_id(player_id, SubmissionResult.STILL_PROCESSING)
			return
		
		_player_submission_ids.append(player_id)
		_player_submission_processes.append(_validate_submission.bind(player_id, player_submission))

@rpc("any_peer", "call_local", "reliable", 0)
func _rpc_request_swap() -> void:
	if multiplayer.has_multiplayer_peer() && is_multiplayer_authority():
		var player_id: int = multiplayer.get_remote_sender_id()
		if !_game_data.get_player_submitted(player_id):
			_game_data.set_player_submitted(player_id, true)
			var player_tiles: Array[int] = []
			while player_tiles.size() < DEFAULT_TILE_COUNT:
				player_tiles.append(Tile.get_random_face())
			_game_data.set_player_tiles(player_id, player_tiles)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if !active:
		_game_camera.global_position = Vector2.ZERO
		return
	
	if _await_submit_results || _game_data.get_local_player_submitted():
		_button_submit.disabled = true
		_button_submit.text = "Submitted"
		_button_recall.disabled = true
		_button_swap.disabled = true
	else:
		_button_submit.disabled = false
		_button_submit.text = "Submit"
		_button_recall.disabled = false
		_button_swap.disabled = false
	
	if _turn_time > 0.0:
		_turn_time = maxf(_turn_time - delta, 0.0)
	
	if multiplayer.has_multiplayer_peer() && is_multiplayer_authority():
		while !_player_submission_processes.is_empty():
			if _player_submission_processing:
				break
			_player_submission_processing = true
			await _player_submission_processes[0].call()
			_player_submission_ids.pop_front()
			_player_submission_processes.pop_front()
			_player_submission_processing = false
		
		# Fast forward turn timer if everyone has already submitted.
		if _turn_time > 3.0 && _game_data.get_all_players_submitted():
			_turn_time = 3.0
			_rpc_set_turn_time.rpc(_turn_time, _turn_time_max)
		if is_zero_approx(_turn_time) && _loop:
			if _turn_count < _turn_count_max:
				next_turn()
			else:
				# Out of turns, end the game loop.
				stop_loop()

@rpc("authority", "call_local", "reliable", 0)
func _rpc_submit_result(submission_result: SubmissionResult, points: int = 0) -> void:
	var submission_result_message: String = get_submission_result_message(submission_result)
	_gui_alert_label.text = ""
	_gui_alert_label.clear()
	if submission_result == SubmissionResult.OK:
		_gui_alert_label.append_text("[color=white]%s[/color]" % [submission_result_message])
		_gui_alert_label.append_text(" ")
		_gui_alert_label.append_text("[color=green]+%d points![/color]" % [points])
	else:
		_gui_alert_label.append_text("[color=red]%s[/color]" % [submission_result_message])
	
	if is_instance_valid(_gui_alert_tween):
		_gui_alert_tween.kill()
	_gui_alert_tween = _gui_alert.create_tween()
	_gui_alert_tween.tween_property(_gui_alert, "modulate:a", 1.0, 0.125)
	_gui_alert_tween.set_parallel(false)
	_gui_alert_tween.tween_interval(3.0)
	_gui_alert_tween.tween_property(_gui_alert, "modulate:a", 0.0, 1.0)
	_await_submit_results = false
