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
var player

var current = 0

func _ready():
	for h in hands.get_children():
		_setup_player(h)

	clear(deck, deck_obj.get_node("Cards"))
	clear(pile, discard_pile_obj)

	_generate_deck()
	shuffle(deck)

	players[1].draw(3)
	players[2].draw(3)

	discard(pop_deck())

	deck_obj.connect("input_event", self, "_handle_deck_input")

	start()

func instance_new_player(player_id):
	var p = player_scene.instance()
	p.player_id = player_id
	p.controller_path = get_path()
	hands.add_child(p)
	p.transform.origin = main_hand_pos.transform.origin

	_setup_player(p)

func _setup_player(p):
	players[p.player_id] = p
	p.connect("turn_over", self, "_on_turn_played", [p])
	p.connect("playable_changed", self, "_on_playable_cards_changed", [p])

func clear(stack: Array, stack_obj: Node):
	stack.clear()
	for c in stack_obj.get_children():
		stack_obj.remove_child(c)
		c.queue_free()

func _generate_deck():
	for color in Utils.CardColor.values().slice(0, -2):
		for i in range(10):
			insert_in_deck(_instance_card(str(i), color))

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

func _handle_deck_input(_camera, event, _click_pos, _normal, _shape):
	if event is InputEventMouseButton && event.pressed:
		if can_draw():
			player.draw()
			if player.playable.size() == 0:
				player.pass_turn()

func can_draw():
	return player.can_play && player.playable.size() == 0

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

func _on_turn_played(_player):
	next_player()

func _on_playable_cards_changed(playable, _player):
	if playable.size() == 0:
		deck_obj.enable_hover()
	else:
		deck_obj.disable_hover()

func next_player():
	current += 1
	if current > players.size():
		current = 1
	player = players[current]
	player.start_turn()
