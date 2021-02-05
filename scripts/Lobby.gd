extends CenterContainer

onready var host_button := $"Connect/VBoxContainer/HBoxContainer/HostButton"
onready var join_button := $"Connect/VBoxContainer/HBoxContainer2/JoinButton"
onready var start_button := $"Players/VBoxContainer/StartButton"
onready var nick := $Connect/VBoxContainer/HBoxContainer/NameEdit
onready var ip := $Connect/VBoxContainer/HBoxContainer2/IPEdit
onready var players_list := $Players/VBoxContainer/List

func _ready():
	host_button.connect("pressed", self, "_on_host_pressed")
	join_button.connect("pressed", self, "_on_join_pressed")
	start_button.connect("pressed", self, "_on_start_pressed")

	GameState.connect("connection_failed", self, "_on_connection_failed")
	GameState.connect("connection_succeeded", self, "_on_connection_success")
	GameState.connect("player_list_changed", self, "refresh_lobby")
	GameState.connect("game_ended", self, "_on_game_ended")
	# GameState.connect("game_error", self, "_on_game_error")

	# Set the player name according to the system username. Fallback to the path.
	if OS.has_environment("USERNAME"):
		nick.text = OS.get_environment("USERNAME")
	else:
		var desktop_path = OS.get_system_dir(0).replace("\\", "/").split("/")
		nick.text = desktop_path[desktop_path.size() - 2]

func _on_connection_success():
	$Connect.hide()
	$Players.show()

func _on_connection_failed():
	join_button.disabled = false
	host_button.disabled = false

func _on_game_ended():
	show()
	$Connect.show()
	$Players.hide()
	host_button.disabled = false
	join_button.disabled = false


func _on_game_error(_errtxt):
	# $ErrorDialog.dialog_text = errtxt
	# $ErrorDialog.popup_centered_minsize()
	host_button.disabled = false
	join_button.disabled = false

func _on_host_pressed():
	GameState.host_game(nick.text)
	$Connect.hide()
	$Players.show()
	refresh_lobby()

func _on_join_pressed():
	join_button.disabled = true
	host_button.disabled = true
	GameState.join_game(ip.text, nick.text)

func refresh_lobby():
	players_list.clear()
	players_list.add_item(GameState.player_name + " (You)")
	for p in GameState.get_players():
		if (GameState.player_name != p):
			players_list.add_item(p)
	
	start_button.disabled = not get_tree().is_network_server()

func _on_start_pressed():
	GameState.begin_game()
