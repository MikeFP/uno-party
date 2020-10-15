extends Node

var player_scene = preload("res://scenes/Player Hand.tscn")

export var num_players := 2

onready var hands = $Hands
onready var deck_obj = $Deck
onready var discard_pile_obj = $Discard

onready var main_hand_pos = $MainHandPosition
onready var left_hand_pos = $LeftHandPosition.transform.origin
onready var right_hand_pos = $RightHandPosition.transform.origin

onready var color_selector = $"UI/Color Picker"
onready var uno_button = $"UI/UNO Button"

var players = {}
var remaining = []
var order = []

var deck = []
var pile = []
var player

var processing_card

var current = -1
var order_reversed = false

func _ready():
	for h in hands.get_children():
		if GameState.player_name == null && h.player_id == 1:
			_setup_player(h)
		else:
			hands.remove_child(h)
			h.queue_free()

	clear(deck, deck_obj.get_node("Cards"))
	clear(pile, discard_pile_obj)

	if GameState.player_name == null:
		for i in range(num_players - 1):
			instance_new_player(i + 2)
		insert_in_deck(Utils.generate_deck())
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

	var turn_index = order.find(GameState.player_id)

	for i in range(1, order.size()):
		var index = (turn_index + i) % order.size()

		var p = players[order[index]]
		p.transform.origin = polar_zero.rotated(Vector3.UP, deg2rad(angle)) + circle_center
		p.transform.basis = Basis()
		p.rotate_y(deg2rad(angle/3 - 30))
		angle += angle_diff

func clear(stack: Array, stack_obj: Node):
	stack.clear()
	for c in stack_obj.get_children():
		stack_obj.remove_child(c)
		c.queue_free()

func insert_in_deck(cards_settings, index := -1):
	var i = index
	if index == -1:
		i = deck.size()

	for c in range(cards_settings["symbols"].size()):
		var card = Utils.instance_card(cards_settings["symbols"][c], cards_settings["colors"][c])
		deck.insert(i, card)
	
		deck_obj.get_node("Cards").add_child(card)
		deck_obj.get_node("CollisionShape").scale.z = deck.size() * 0.01 + 0.1
		
		card.face_down()

		i += 1

	_space_stacked_cards(deck)

func pop_deck():
	var card = deck.pop_back()
	deck_obj.get_node("Cards").remove_child(card)
	deck_obj.get_node("CollisionShape").scale.z = deck.size() * 0.01 + 0.1
	return card

func top_card():
	return pile[-1]

func _space_stacked_cards(stack):
	var i = 0
	for card in stack:
		card.transform.origin.z = -i * 0.01
		i += 1

func discard(card):
	pile.append(card)
	discard_pile_obj.add_child(card)
	card.transform.origin = Vector3()
	card.face_up()
	_space_stacked_cards(pile)

remotesync func shuffle_deck(rng_seed: int):
	seed(rng_seed)
	deck.shuffle()
	_space_stacked_cards(deck)

func start():
	if get_tree().is_network_server():
		var s = Utils.randomize_seed()
		rpc("shuffle_deck", s)

	yield(get_tree().create_timer(2.0), "timeout")
	for p in players.values():
		p.draw(2)

	discard(pop_deck())

	next_player()

func _on_cards_drawn(_cards, p):
	if p == player && p.can_play && player.playable.size() == 0:
		next_player()

func _on_playable_cards_changed(_playable, p):
	if p == player:
		if p.can_draw():
			deck_obj.enable_hover()
		else:
			deck_obj.disable_hover()

func _on_card_played(card, p):
	processing_card = card

	# process card effects when played, before passing turn
	if card.color == Utils.CardColor.BLACK:
		color_selector.show()
		var color = yield(color_selector, "color_picked")
		card.color = color
		color_selector.hide()
	
	if card.type == Utils.CardType.REVERSE && remaining.size() > 2:
		order_reversed = !order_reversed

	# print("card played " + str(card.symbol))
	next_player()

	var player_removed = false
	if p.cards.size() == 0:
		var index = remaining.find(p)
		remaining.remove(index)
		if index < current:
			current -= 1
		player_removed = true

	# process card effects after passing turn to next player
	if card.type == Utils.CardType.PLUS2:
		player.draw(2)
		next_player()
	elif card.type == Utils.CardType.PLUS4:
		player.draw(4)
		next_player()
	elif card.type == Utils.CardType.BLOCK:
		next_player()
	elif card.type == Utils.CardType.REVERSE && remaining.size() == 2 && !player_removed:
		next_player()

	processing_card = null
	yield(get_tree(), "idle_frame")
	player.start_turn()

func next_player():
	if current >= 0:
		player.end_turn()
		# print("ending player " + str(player.player_id) + " turn")

	current += -1 if order_reversed else 1
	if current < 0:
		current = remaining.size() - 1
	elif current >= remaining.size():
		current = 0
	player = remaining[current]

	# print("now its player " + str(player.player_id))

	if processing_card == null:
		yield(get_tree(), "idle_frame")
		player.start_turn()

func _on_uno_called_out(_p):
	player.draw(2)
