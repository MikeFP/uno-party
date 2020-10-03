tool
extends Spatial

enum CardType { NUMBER, WILDCARD, BLOCK, REVERSE, PLUS4, PLUS2 }
enum CardColor { RED, YELLOW, GREEN, BLUE }

const RED = Color8(209, 61, 61)
const GREEN = Color8(112, 182, 94)
const BLUE = Color8(2, 101, 203)
const YELLOW = Color8(240, 212, 68)

export(CardType) var type := CardType.NUMBER setget set_type
export(CardColor) var color := CardColor.RED setget set_color
export var value := "" setget set_value

onready var symbol := $"Viewport/Card Texture/symbol"
onready var fg := $"Viewport/Card Texture/foreground"
onready var hl_area := $"Highlight Area"

var is_face_up = true

func _ready():
	set_type(type)
	set_color(color)
	set_value(value)


func set_type(new_type):
	type = new_type
	_update_symbol()

func set_value(new_value: String):
	value = new_value
	if type == CardType.NUMBER:
		_update_symbol()

func set_color(new_color):
	color = new_color
	
	if is_inside_tree():
		var rgb
		match color:
			CardColor.RED:
				rgb = RED
			CardColor.YELLOW:
				rgb = YELLOW
			CardColor.GREEN:
				rgb = GREEN
			CardColor.BLUE:
				rgb = BLUE
		fg.modulate = rgb

func _update_symbol():
	if is_inside_tree():
		if type in Utils.COLORED_CARD_TYPES:
			symbol.texture = Utils.get_symbol_texture(value)
		else:
			symbol.texture = Utils.get_symbol_texture(Utils.enum_to_string(CardType, type).to_lower())

func face_up():
	transform.basis = Basis()
	is_face_up = true

func face_down():
	transform.basis = Basis()
	rotate_y(deg2rad(180))
	is_face_up = false