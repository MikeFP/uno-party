extends Node

var room_scene = preload("res://scenes/GameRoom.tscn")

# Default game port. Can be any number between 1024 and 49151.
const DEFAULT_PORT = 10266

# Max number of players.
const MAX_PEERS = 12

var player_name
var player_id
var players = {}
var players_ready = []
var room

signal player_list_changed
signal connection_failed
signal connection_succeeded
signal game_ended
signal game_error(what)

func _ready():
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self,"_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")

func _player_connected(id):
	# Registration of a client begins here, tell the connected player that we are here.
	player_id = id
	rpc_id(id, "register_player", player_name)

func _player_disconnected(id):
	if game_in_progress():
		if get_tree().is_network_server():
			emit_signal("game_error", "Player " + players[id] + " disconnected")
			end_game()
	else:
		unregister_player(id)

func _connected_ok():
	emit_signal("connection_succeeded")

func _server_disconnected():
	emit_signal("game_error", "Server disconnected")
	end_game()

func _connected_fail():
	get_tree().set_network_peer(null)
	emit_signal("connection_failed")

func get_players():
	return players.values()

func get_player_by_id(id):
	if players.has(id) :
		return players[id]
	return null

func host_game(nickname):
	player_name = nickname
	player_id = 1
	var host = NetworkedMultiplayerENet.new()
	host.create_server(DEFAULT_PORT, MAX_PEERS)
	get_tree().set_network_peer(host)

func join_game(ip, nickname):
	player_name = nickname
	var client = NetworkedMultiplayerENet.new()
	client.create_client(ip, DEFAULT_PORT)
	get_tree().set_network_peer(client)

# Lobby management functions.

remote func register_player(nickname):
	var id = get_tree().get_rpc_sender_id()
	print(id)
	players[id] = nickname
	emit_signal("player_list_changed")


func unregister_player(id):
	players.erase(id)
	emit_signal("player_list_changed")

# Game stages management

func game_in_progress():
	return has_node("/root/GameRoom")

func end_game():
	if game_in_progress():
		get_node("/root/GameRoom").queue_free()

	emit_signal("game_ended")
	players.clear()

func begin_game():
	assert(get_tree().is_network_server())
	
	var player_ids = [1] + players.keys()
	var ss = Utils.randomize_seed()

	rpc("pre_start_game", player_ids, ss)
	pre_start_game(player_ids, ss)

remote func pre_start_game(player_ids, ss):
	room = room_scene.instance()
	get_tree().get_root().add_child(room)
	get_node("/root/Lobby").hide()

	for p in player_ids:
		room.instance_new_player(p)
	room.shuffle_deck(ss)

	if not get_tree().is_network_server():
		# Tell server we are ready to start.
		rpc_id(1, "ready_to_start", player_id)
	else:
		if players.size() == 0:
			rpc("post_start_game")

remotesync func post_start_game():
	get_tree().set_pause(false)
	room.start()
	
remote func ready_to_start(id):
	assert(get_tree().is_network_server())

	if not id in players_ready:
		players_ready.append(id)

	if players_ready.size() == players.size():
		for p in players:
			rpc_id(p, "post_start_game")
		post_start_game()