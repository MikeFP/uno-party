tool
extends Spatial

export var current_angle := 0.0 setget set_angle
export var angular_velocity := PI
export var axis := Vector3.UP
export var node_path: NodePath

var node: Spatial

func _ready():
	node = self
	if is_inside_tree() && node_path != '':
		node = get_node(node_path)

func _process(delta):
	set_angle(current_angle + angular_velocity * delta)
	if current_angle > 360:
		current_angle -= 360

func set_angle(angle):
	node.rotate(axis, -current_angle)
	current_angle = angle
	node.rotate(axis, current_angle)
	