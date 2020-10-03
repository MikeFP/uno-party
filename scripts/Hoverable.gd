extends Node

export var area_path: NodePath
export var collider_path: NodePath
onready var area: Area = get_node(area_path)
onready var collider: CollisionShape = get_node(collider_path)

func _ready():
    area.connect("mouse_entered", self, "_on_mouse_entered")
    area.connect("mouse_exited", self, "_on_mouse_exited")

func disable_hover():
    collider.disabled = true

func enable_hover():
    collider.disabled = false

func _on_mouse_entered():
    Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

func _on_mouse_exited():
    Input.set_default_cursor_shape(Input.CURSOR_ARROW)