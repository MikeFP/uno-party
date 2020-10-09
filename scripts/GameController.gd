extends Node

var player_scene = preload("res://scenes/Player Hand.tscn")
var card_scene = preload("res://scenes/Card.tscn")

export var num_players := 2

onready var hands = $Hands
onready var deck_obj = $Deck
onready var discard_pile_obj = $Discard

onready var main_hand_pos = $MainHandPosition.transform.origin
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
		if h.player_id == 1:
			_setup_player(h)
		else:
			hands.remove_child(h)
			h.queue_free()
	
	for i in range(num_players - 1):
		instance_new_player(i + 2)

	clear(deck, deck_obj.get_node("Cards"))
	clear(pile, discard_pile_obj)

	_generate_deck()
	shuffle(deck)

	players[1].max_width = 8
	players[1].max_space_between_cards = 0.6

	space_out_players()
	for p in players.values():
		p.draw(2)

	discard(pop_deck())

	start()

func instance_new_player(player_id):
	var p = player_scene.instance()
	p.player_id = player_id
	p.controller_path = get_path()
	p.deck_path = deck_obj.get_path()
	p.uno_path = uno_button.get_path()
	hands.add_child(p)
	p.transform.origin = main_hand_pos

	_setup_player(p)

func _setup_player(p):
	players[p.player_id] = p
	order.append(p.player_id)
	remaining.append(p)
	p.connect("drawn", self, "_on_cards_drawn", [p])
	p.connect("playable_changed", self, "_on_playable_cards_changed", [p])
	p.connect("card_played", self, "_on_card_played", [p])
	p.connect("called_out_uno", self, "_on_uno_called_out", [p])

func space_out_players():
	var angle_diff = 0
	var angle = 90
	
	if players.size() > 2:
		angle_diff = 180 / (players.size() - 2)
		angle = 0

	var circle_center = left_hand_pos + (right_hand_pos - left_hand_pos)/2
	var polar_zero = right_hand_pos - circle_center

	var other = order
	other.remove(other.find(1)) # replace with client id

	for i in other:
		var p = players[i]
		p.transform.origin = polar_zero.rotated(Vector3.UP, deg2rad(angle)) + circle_center
		p.transform.basis = Basis()
		p.rotate_y(deg2rad(angle/3 - 30))
		angle += angle_diff

func clear(stack: Array, stack_obj: Node):
	stack.clear()
	for c in stack_obj.get_children():
		stack_obj.remove_child(c)
		c.queue_free()

func _generate_deck():
	for color in Utils.CardColor.values().slice(0, -2):
		for i in range(10):
			insert_in_deck(_instance_card(str(i), color))
		for _i in range(2):
			insert_in_deck(_instance_card("block", color))
			insert_in_deck(_instance_card("reverse", color))
			insert_in_deck(_instance_card("plus2", color))
	
	for _i in range(4):
		insert_in_deck(_instance_card("plus4", Utils.CardColor.BLACK))
		insert_in_deck(_instance_card("wildcard", Utils.CardColor.BLACK))

func _instance_card(symbol_name: String, color: int):
	var card = card_scene.instance()
	card.symbol = symbol_name
	card.color = color
	return card

func insert_in_deck(card, index := -1):
	if index == -1:
		deck.append(card)
	else:
		deck.insert(index, card)
	
	deck_obj.get_node("Cards").add_child(card)
	deck_obj.get_node("CollisionShape").scale.z = deck.size() * 0.01 + 0.1

	card.face_down()
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

func shuffle(stack):
	randomize()
	stack.shuffle()
	_space_stacked_cards(stack)

func start():
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
