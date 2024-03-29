extends Node

var player_scene = preload("res://scenes/Player Hand.tscn")

export var num_players := 2
export var initial_hand_size := 7
var force_cards = ["wildcard BLACK", "wildcard BLACK"]

onready var hands = $Hands
onready var deck_obj = $Deck
onready var discard_pile_obj = $Discard

onready var main_hand_pos = $MainHandPosition
onready var left_hand_pos = $LeftHandPosition.transform.origin
onready var right_hand_pos = $RightHandPosition.transform.origin

onready var uno_button = $"UI/UNO Button"
onready var turn_flow = $"Environment/Turn Flow"
onready var match_result = $MatchResults
onready var continue_button = $MatchResults/ColorRect/CenterContainer/Panel/MarginContainer/Control/ContinueButton
onready var rematch_button = $MatchResults/ColorRect/CenterContainer/Panel/MarginContainer/Control/RematchButton

var players = {}
var remaining = []
var order = []

var deck = []
var pile = []
var player

var processing_card

var current = -1
var order_reversed = false setget set_order_reversed

func _ready():
	if GameState.player_name == null:
		for h in hands.get_children():
			if h.player_id == 1:
				_setup_player(h)
			else:
				hands.remove_child(h)
				h.queue_free()
	else:
		for h in hands.get_children():
			hands.remove_child(h)
			h.queue_free()
		players = {}

	_setup_new_game()

	if GameState.player_name == null:
		for i in range(num_players - 1):
			instance_new_player(i + 2)
		start()

func _setup_new_game():
	current = -1
	order_reversed = false
	order = []
	remaining = []
	processing_card = null

	for p in players.values():
		order.append(p.player_id)
		remaining.append(p)
		p.remove_cards()
	
	match_result.hide()

	clear(deck, deck_obj.get_node("Cards"))
	clear(pile, discard_pile_obj)

	# for _i in range(30):
	# 	force_cards.append("reverse RED")
	insert_in_deck(Utils.generate_deck(force_cards))

	if GameState.player_name == null:
		if force_cards.size() == 0:
			shuffle_deck(Utils.randomize_seed())

func instance_new_player(player_id):
	var p = player_scene.instance()
	p.player_id = player_id
	p.controller_path = get_path()
	p.deck_path = deck_obj.get_path()
	p.uno_path = uno_button.get_path()
	hands.add_child(p)

	if player_id == GameState.player_id:
		p.transform = main_hand_pos.transform
		p.max_width = 8
		p.max_space_between_cards = 0.6
	else:
		p.transform.origin = right_hand_pos

	_setup_player(p)
	print("player " + str(player_id) + " instanced")
	space_out_players()

func _setup_player(p):
	players[p.player_id] = p
	order.append(p.player_id)
	remaining.append(p)
	p.connect("drawn", self, "_on_cards_drawn", [p])
	p.connect("playable_changed", self, "_on_playable_cards_changed", [p])
	p.connect("card_played", self, "_on_card_played", [p])
	p.connect("called_out_uno", self, "_on_uno_called_out", [p])

func space_out_players():
	if players.size() == 1:
		return
	
	var angle_diff = 0
	var angle = 90
	
	if players.size() > 2:
		angle_diff = 180 / (players.size() - 2)
		angle = 0

	var circle_center = left_hand_pos + (right_hand_pos - left_hand_pos)/2
	var polar_zero = right_hand_pos - circle_center

	var current_player_id = 1 if GameState.player_name == null else GameState.player_id
	var turn_index = order.find(current_player_id)
	players[current_player_id].ui_position = "center none"

	for i in range(1, order.size()):
		var index = (turn_index + i) % order.size()

		var p = players[order[index]]
		p.transform.origin = polar_zero.rotated(Vector3.UP, deg2rad(angle)) + circle_center
		p.transform.basis = Basis()
		p.rotate_y(deg2rad(angle/3 - 30))
		if angle > 90:
			p.ui_position = "top left"
		else:
			p.ui_position = "top right"
		angle += angle_diff

func clear(stack: Array, stack_obj: Node):
	stack.clear()
	for c in stack_obj.get_children():
		stack_obj.remove_child(c)
		c.queue_free()

func insert_in_deck(cards, index := -1):
	var i = index
	if index == -1:
		i = deck.size()

	for card in cards:
		deck.insert(i, card)
	
		deck_obj.get_node("Cards").add_child(card)
		deck_obj.get_node("CollisionShape").scale.z = deck.size() * 0.01 + 0.1
		
		card.face_down()

		i += 1

	_space_stacked_cards(deck)

func pop_deck():
	var card = deck.pop_back()
	deck_obj.get_node("CollisionShape").scale.z = deck.size() * 0.01 + 0.1
	if (deck.size() == 0):
		var collected = []
		for _i in range(pile.size() - 1):
			collected.append(pile.pop_front())
		collected.shuffle()
		var anim = null
		for i in range(collected.size()):
			collected[i].face_down()
			var pos = deck_obj.to_global(Vector3.FORWARD * i * 0.01)
			anim = collected[i].move_to(pos, deck_obj.transform.basis)
		yield(get_tree().create_timer(0.25), "timeout")
		_space_stacked_cards(pile)
		yield(anim, "completed")
		insert_in_deck(collected)
	else:
		yield(get_tree(), "idle_frame")
	return card

func top_card():
	return pile[-1]

func _space_stacked_cards(stack):
	var i = 0
	for card in stack:
		card.transform.origin.z = -i * 0.01
		i += 1

func discard(card, force_align = false, wiggle = true):
	var target_position = discard_pile_obj.to_global(Vector3.FORWARD * pile.size() * 0.01)
	yield (card.move_and_reparent(discard_pile_obj, target_position, force_align, deg2rad(rand_range(-30, 30)) if wiggle else 0.0), "completed")
	pile.append(card)
	_space_stacked_cards(pile)

remotesync func shuffle_deck(rng_seed: int):
	seed(rng_seed)
	deck.shuffle()
	_space_stacked_cards(deck)

func start():
	for p in remaining:
		if p == remaining[-1]:
			yield(p.draw(initial_hand_size), "completed")
		else:
			p.draw(initial_hand_size)

	yield(discard(yield(pop_deck(), "completed"), true, false), "completed")

	next_player()
	player.enable_playing()

func _on_cards_drawn(_cards, p):
	if p == player && p.can_play && player.playable.size() == 0:
		yield(get_tree().create_timer(1.0), "timeout")
		next_player()

func _on_playable_cards_changed(_playable, p):
	if p == player:
		if p.can_draw() && (GameState.player_name == null || GameState.player_id == p.player_id):
			deck_obj.enable_hover()
		else:
			deck_obj.disable_hover()

func _on_card_played(card, p):
	print("card played " + str(card.symbol))
	process_card(card.name, p.player_id)

func process_card(card_name, p_id):
	var card = discard_pile_obj.get_node(card_name)
	var p = players[p_id]

	processing_card = card
	yield(processing_card.process_effects(p, self), "completed")
	print("card processed")
	
	yield(get_tree().create_timer(1.75), "timeout")

	if (p.cards.size() == 0):
		end_game(p)
		return
	next_player(false)
	post_process_card(card, p)
	
func post_process_card(card, p):
	if p.cards.size() == 0:
		var index = remaining.find(p)
		remaining.remove(index)
		if index < current:
			current -= 1
	
	yield(card.post_process_effects(player, self), "completed")
	print("card postprocessed")
	
	processing_card = null
	player.start_turn()
	player.enable_playing()

func next_player(enable_playing := true):
	if current >= 0:
		player.end_turn()
		# print("ending player " + str(player.player_id) + " turn")

	current += -1 if order_reversed else 1
	if current < 0:
		current = remaining.size() - 1
	elif current >= remaining.size():
		current = 0
	player = remaining[current]

	print("now its player " + str(player.player_id))

	player.start_turn()
	if enable_playing:
		player.enable_playing()

func _on_uno_called_out(_p):
	player.draw(2)

func set_order_reversed(value):
	order_reversed = value
	turn_flow.angular_velocity = -turn_flow.angular_velocity
	turn_flow.current_angle = turn_flow.current_angle + (30 if !order_reversed else -30)

	var uv_scale = turn_flow.mesh.material.uv1_scale
	turn_flow.mesh.material.uv1_scale = Vector3(-uv_scale.x,1,1)

func end_game(winner):
	match_result.get_node("ColorRect/CenterContainer/Panel/MarginContainer/Control/VBox/PlayerName").text = winner.get_name()
	yield(get_tree().create_timer(0.5), "timeout")
	continue_button.connect("button_up", self, "_navigate_lobby")
	rematch_button.connect("button_up", self, "restart")
	match_result.show()

func _navigate_lobby():
	get_tree().change_scene("scenes/Lobby.tscn")
	queue_free()

func restart():
	continue_button.disconnect("button_up", self, "_navigate_lobby")
	rematch_button.disconnect("button_up", self, "restart")
	_setup_new_game()
	if GameState.player_name == null:
		start()
