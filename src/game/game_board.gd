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
