extends CanvasItem

signal color_picked

onready var lines = $"VBoxContainer".get_children()

var colors = []

func _ready():
	for l in lines:
		for c in l.get_children():
			colors.append(c)
			c.connect("pressed", self, "_color_pressed", [c])

func _color_pressed(color):
	emit_signal("color_picked", Utils.color_type_from_value(color.modulate))
