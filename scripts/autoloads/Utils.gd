extends Node
tool

enum CardType { NUMBER, WILDCARD, BLOCK, REVERSE, PLUS4, PLUS2, NONE }
enum CardColor { RED, YELLOW, GREEN, BLUE, BLACK }
const COLORS = {
	"RED": Color8(209, 61, 61),
	"YELLOW": Color8(240, 212, 68),
	"GREEN": Color8(112, 182, 94),
	"BLUE": Color8(2, 101, 203),
	"BLACK": Color8(0, 0, 0)
}

var symbols_map = {}

var card_scene = preload("res://scenes/Card.tscn")
var card_id = 0

func enum_to_string(enum_type, value):
	return enum_type.keys()[value]

func get_symbol_texture(symbol_name: String):
	if !symbols_map.has(symbol_name):
		symbols_map[symbol_name] = load("res://textures/symbols/" + symbol_name + ".png")
	return symbols_map[symbol_name]

func card_type_for_symbol(symbol_name: String):
	if symbol_name.is_valid_integer():
		return CardType.NUMBER
	if symbol_name.to_upper() in CardType:
		return CardType[symbol_name.to_upper()]
	return CardType.NONE

func color_type_from_value(color: Color):
	for k in CardColor:
		if Color8(color.r8, color.g8, color.b8) == COLORS[k]:
			return CardColor[k]

func is_card_playable(card, top_card):
	if top_card.color == CardColor.BLACK || card.color == CardColor.BLACK:
		return true
	
	if card.color == top_card.color || card.symbol == top_card.symbol:
		return true
	return false

func get_playable_cards(cards, top_card):
	var res = []
	for card in cards:
		if is_card_playable(card, top_card):
			res.append(card)
	return res

func get_new_card_id():
	card_id += 1
	return card_id

func instance_card(symbol_name: String, color: int):
	var card = card_scene.instance()
	card.symbol = symbol_name
	card.color = color
	card.name = str(get_new_card_id())

	if card.color == CardColor.BLACK:
		card.add_effect(PickColorEffect.new())
	if card.type == CardType.REVERSE:
		card.add_effect(ReverseEffect.new())
	if card.type == CardType.PLUS2:
		card.add_effect(DrawEffect.new(2))
	if card.type == CardType.PLUS4:
		card.add_effect(DrawEffect.new(4))
	if card.type == CardType.BLOCK:
		card.add_effect(BlockEffect.new())

	return card

func generate_deck(force_cards: Array = []):
	var deck = []

	for color in Utils.CardColor.values().slice(0, -2):
		for i in range(10):
			deck.append(instance_card(str(i), color))
		for _i in range(2):
			deck.append(instance_card("block", color))
			deck.append(instance_card("reverse", color))
			deck.append(instance_card("plus2", color))
	
	for _i in range(4):
		deck.append(instance_card("plus4", Utils.CardColor.BLACK))
		deck.append(instance_card("wildcard", Utils.CardColor.BLACK))

	var i = 0
	for c in force_cards:
		deck[deck.size() - 1 - i] = instance_card(c.split(" ")[0], Utils.CardColor[c.split(" ")[1]])
		i += 1

	return deck

func randomize_seed():
	randomize()
	var ns = randi()
	seed(ns)
	return ns

func reparent(node: Node, new_parent: Node, keep_global = true, request_ready = false):
	var old_transform = node.global_transform
	node.get_parent().remove_child(node)

	if request_ready:
		node.request_ready()

	new_parent.add_child(node)
	
	if keep_global:
		node.global_transform = old_transform

func change_scene(scene: PackedScene):
	var instance = scene.instance()
	var root = get_tree().get_root()
	root.get_children()[0].hide()
	root.add_child(instance)
