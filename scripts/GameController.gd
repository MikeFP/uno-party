extends Node

var player_scene = preload("res://scenes/Player Hand.tscn")
var card_scene = preload("res://scenes/Card.tscn")

onready var hands = $Hands
onready var deck_obj = $Deck
onready var discard_pile_obj = $Discard
onready var main_hand_pos = $MainHandPosition
onready var color_selector = $"UI/Color Picker"

var players = {}
var deck = []
var pile = []
var player

var processing_card

var current = 0
var order_reversed = false

func _ready():
	for h in hands.get_children():
		_setup_player(h)

	clear(deck, deck_obj.get_node("Cards"))
	clear(pile, discard_pile_obj)

	_generate_deck()
	shuffle(deck)

	players[1].max_width = 8
	players[1].max_space_between_cards = 0.6

	for p in players.values():
		p.draw(6)

	discard(pop_deck())

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
	p.connect("drawn", self, "_on_cards_drawn", [p])
	p.connect("playable_changed", self, "_on_playable_cards_changed", [p])
	p.connect("card_played", self, "_on_card_played", [p])

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
	if p == player && player.playable.size() == 0:
		next_player()

func _on_playable_cards_changed(_playable, p):
	if p == player:
		if p.can_draw():
			deck_obj.enable_hover()
		else:
			deck_obj.disable_hover()

func _on_card_played(card, _p):
	processing_card = card

	# process card effects when played, before passing turn
	if card.color == Utils.CardColor.BLACK:
		color_selector.show()
		var color = yield(color_selector, "color_picked")
		card.color = color
		color_selector.hide()
	
	if card.type == Utils.CardType.REVERSE && players.size() > 2:
		order_reversed = !order_reversed

	next_player()

	# process card effects after passing turn to next player
	processing_card = null

	if card.type == Utils.CardType.PLUS2:
		player.draw(2)
		next_player()
	elif card.type == Utils.CardType.PLUS4:
		player.draw(4)
		next_player()
	elif card.type == Utils.CardType.BLOCK:
		next_player()
	elif card.type == Utils.CardType.REVERSE && players.size() == 2:
		next_player()

	yield(get_tree(), "idle_frame")
	player.start_turn()

func next_player():
	if current > 0:
		player.end_turn()

	current += -1 if order_reversed else 1
	if current < 1:
		current = players.size()
	if current > players.size():
		current = 1
	player = players[current]

	if processing_card == null:
		yield(get_tree(), "idle_frame")
		player.start_turn()
