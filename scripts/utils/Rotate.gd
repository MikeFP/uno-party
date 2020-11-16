tool
extends Spatial

export var initial_angle := 0.0
export var angular_velocity := PI
export var axis := Vector3.UP
export var node_path: NodePath

var node: Spatial

func _ready():
	node = self
	if is_inside_tree() && node_path != '':
		node = get_node(node_path)

func _process(delta):
	node.rotate(axis, angular_velocity * delta)
