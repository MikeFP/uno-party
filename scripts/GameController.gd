extends Node

var player_scene = preload("res://scenes/Player Hand.tscn")
var card_scene = preload("res://scenes/Card.tscn")

onready var hands = $Hands
onready var deck_obj = $Deck
onready var discard_pile_obj = $Discard
onready var main_hand_pos = $MainHandPosition

var players = {}
var deck = []
var pile = []

var current = 0

signal current_player_changed

func _ready():
	for h in hands.get_children():
		_setup_player(h)

	_generate_deck()
	shuffle(deck)

	players[1].draw(3)
	players[2].draw(3)

	discard(pop_deck())

	start()

func instance_new_player(player_id):
	var player = player_scene.instance()
	player.player_id = player_id
	player.controller_path = get_path()
	hands.add_child(player)
	player.transform.origin = main_hand_pos.transform.origin

	_setup_player(player)

func _setup_player(player):
	players[player.player_id] = player
	player.connect("turn_over", self, "_on_turn_played", [player])

func _generate_deck():
	for color in Utils.CardColorType.values():
		for i in range(10):
			insert_in_deck(_instance_card(str(i), color))

func _instance_card(symbol_name: String, color):
	var card = card_scene.instance()

	if symbol_name.is_valid_integer():
		card.type = Utils.CardType.NUMBER
	else:
		card.type = Utils.CardType[symbol_name.to_upper()]
	
	if color != null:
		card.color = color
	if card.type == Utils.CardType.NUMBER:
		card.value = symbol_name
	return card

func insert_in_deck(card, index := -1):
	if index == -1:
		deck.append(card)
	else:
		deck.insert(index, card)
	deck_obj.add_child(card)
	card.face_down()
	_space_stacked_cards(deck)

func pop_deck():
	var card = deck.pop_back()
	deck_obj.remove_child(card)
	return card

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
	stack.shuffle()
	_space_stacked_cards(stack)

func start():
	next_player()

func _on_turn_played(_player):
	next_player()

func next_player():
	current += 1
	if current > players.size():
		current = 1
	emit_signal("current_player_changed", current)
