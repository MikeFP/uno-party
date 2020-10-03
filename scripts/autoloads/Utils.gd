extends Node
tool

enum CardType { NUMBER, WILDCARD, BLOCK, REVERSE, PLUS4, PLUS2 }
enum CardColorType { RED, YELLOW, GREEN, BLUE }
var CardColor = {
    "RED": Color8(209, 61, 61),
    "YELLOW": Color8(240, 212, 68),
    "GREEN": Color8(112, 182, 94),
    "BLUE": Color8(2, 101, 203)
}

const COLORED_CARD_TYPES = [CardType.NUMBER, CardType.PLUS2, CardType.BLOCK, CardType.REVERSE]

var symbols_map = {}

func enum_to_string(enum_type, value):
    return enum_type.keys()[value]

func get_symbol_texture(symbol_name: String):
    if !symbols_map.has(symbol_name):
        symbols_map[symbol_name] = load("res://textures/symbols/" + symbol_name + ".png")
    return symbols_map[symbol_name]