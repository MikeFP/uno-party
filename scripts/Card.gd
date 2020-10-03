tool
extends Spatial

enum CardColor { RED, YELLOW, GREEN, BLUE, BLACK }

export(CardColor) var color := CardColor.RED setget set_color
export var symbol := "1" setget set_symbol

onready var symbol_obj := $"Viewport/Card Texture/symbol"
onready var fg := $"Viewport/Card Texture/foreground"
onready var hl_area := $"Highlight Area"

var is_face_up = true
var type

func _ready():
	set_color(color)
	set_symbol(symbol)

func set_symbol(new_value: String):
	symbol = new_value
	type = Utils.card_type_for_symbol(symbol)
	_update_symbol()

func set_color(new_color):
	color = new_color
	
	if is_inside_tree():
		fg.modulate = Utils.COLORS[Utils.enum_to_string(CardColor, color)]

func _update_symbol():
	if is_inside_tree():
		symbol_obj.texture = Utils.get_symbol_texture(symbol)

func face_up():
	transform.basis = Basis()
	is_face_up = true

func face_down():
	transform.basis = Basis()
	rotate_y(deg2rad(180))
	is_face_up = false

func disable_highlight():
	hl_area.get_node("CollisionShape").disabled = true

func enable_highlight():
	hl_area.get_node("CollisionShape").disabled = false

func disable_area():
	get_node("CollisionShape").disabled = true

func enable_area():
	get_node("CollisionShape").disabled = false