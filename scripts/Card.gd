tool
extends Spatial

enum CardColor { RED, YELLOW, GREEN, BLUE, BLACK }

export(CardColor) var color := CardColor.RED setget set_color
export var symbol := "1" setget set_symbol

onready var symbol_obj := $"Viewport/Card Texture/symbol"
onready var fg := $"Viewport/Card Texture/foreground"
onready var hl_area := $"Highlight Area"
onready var tween := $Tween

var is_face_up = true
var type

signal move_over

func _ready():
	set_color(color)
	set_symbol(symbol)
	tween.connect("tween_all_completed", self, "_movement_animation_over")

func set_symbol(new_value: String):
	symbol = new_value
	type = Utils.card_type_for_symbol(symbol)
	if type != Utils.CardType.NONE:
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

# Animates the card's origin to `target_pos` and, optionally, its basis to `target_basis`.
# 
# If `force_align` is false, the card will only be rotated to match the target forward axis,
# but its up axis will be aligned to the distance vector to the target.
#
# A final rotation of `wiggle_angle` in radians will be added around the final forward axis, so the card's up axis will not be completely aligned with the target up axis.
# Operations take place in global space.
func move_to(target_pos: Vector3, target_basis, force_align := true, wiggle_angle := 0.0, duration := 0.5, jump_height := 1.0):

	# interpolate position
	tween.interpolate_property(self, "global_transform:origin:x", \
		null, target_pos.x, \
		duration, Tween.TRANS_QUAD, Tween.EASE_IN)
	tween.interpolate_property(self, "global_transform:origin:z", \
		null, target_pos.z, \
		duration, Tween.TRANS_QUAD, Tween.EASE_IN)
	tween.interpolate_property(self, "global_transform:origin:y", \
		null, global_transform.origin.y + jump_height, \
		duration/2, Tween.TRANS_QUAD, Tween.EASE_OUT)
	tween.interpolate_property(self, "global_transform:origin:y", \
		global_transform.origin.y + jump_height, target_pos.y, \
		duration/2, Tween.TRANS_QUAD, Tween.EASE_IN, duration/2)
	
	# interpolate rotation and scale
	if target_basis != null:
		if !force_align:
			var original_basis = global_transform.basis
			
			# align distance direction
			var distance = target_pos - global_transform.origin
			look_at(global_transform.origin - distance, global_transform.basis.y)
			# match target forward
			look_at(global_transform.origin - target_basis.z, global_transform.basis.z)
			# wiggle around forward
			rotate(-transform.basis.z, wiggle_angle)

			var target_scale = Vector3(target_basis.x.length(), target_basis.y.length(), target_basis.z.length())
			scale = target_scale

			target_basis = global_transform.basis
			global_transform.basis = original_basis

		tween.interpolate_property(self, "global_transform:basis", \
			null, target_basis, \
			duration/2, Tween.TRANS_QUAD, Tween.EASE_IN, duration/4)

	# wait animation
	tween.start()
	yield (self, "move_over")

func _movement_animation_over():
	emit_signal("move_over")

# Animates the card's transform to the `parent`'s transform and then gets reparented to it.
# If `custom_position` is provided, it overrides the target position.
# The parameters `force_align` and `wiggle_angle` may be set, as in `move_to()`.
# Operations take place in global space.
func move_and_reparent(parent: Spatial, custom_position = null, force_align = true, wiggle_angle := 0.0):
	var target_basis = parent.global_transform.basis
	var target_pos = parent.global_transform.origin

	if custom_position != null:
		target_pos = custom_position
	
	yield(move_to(target_pos, target_basis, force_align, wiggle_angle), "completed")
	Utils.reparent(self, parent)
