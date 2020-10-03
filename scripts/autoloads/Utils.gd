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
