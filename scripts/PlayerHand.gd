extends Spatial

export var player_id := 0
export var controller_path: NodePath
onready var controller = get_node(controller_path)

var cards = []
var card_world

var highlighted_card

var max_space_between_cards = 0.6

var can_play = false

signal turn_over

func _ready():
	for c in get_children():
		add_card(c)
	controller.connect("current_player_changed", self, "_turn_changed")

func lookat_camera():
	transform.basis = Basis()
	rotate_x(deg2rad(45))
	rotate_y(deg2rad(-180))

func _turn_changed(cur_player):
	if cur_player == player_id:
		can_play = true

func add_card(card):
	if !cards.has(card):

		cards.append(card)
		if !get_children().has(card):
			add_child(card)
			card.transform.basis = Basis()

		card.face_up()
		card.transform.origin.z = cards.size() * 0.01
		card.hl_area.connect("mouse_entered", self, "_on_mouse_entered_hl_area", [card])
		card.hl_area.connect("input_event", self, "_on_card_click", [card])

		_space_cards()

func remove_card(card):
	var i = cards.find(card)
	if i != -1:
		cards.remove(i)
		if get_children().has(card):
			remove_child(card)
		card.hl_area.disconnect("mouse_entered", self, "_on_mouse_entered_hl_area")
		card.hl_area.disconnect("input_event", self, "_on_card_click")

func draw(amount := 1):
	for _i in range(amount):
		add_card(controller.pop_deck())

func _space_cards():
	if cards.size() > 0:
		var width = (cards.size() - 1) * max_space_between_cards + 1.0
		var x = -width/2 + 0.5
		for c in cards:
			c.transform.origin.x = x
			x += max_space_between_cards

func _on_card_click(_camera, event, _click_pos, _normal, _shape, card):
	if can_play && event is InputEventMouseButton && event.pressed:
		play_card(card)

func _on_mouse_entered_hl_area(card):
	if highlighted_card == null:
		highlight_card(card)

func _on_mouse_exited(card):
	if highlighted_card == card:
		stop_highlight()

func stop_highlight():
	if highlighted_card != null:
		var card = highlighted_card
		highlighted_card = null
		card.transform.origin.y = 0
		card.hl_area.disconnect("mouse_exited", self, "_on_mouse_exited")

func highlight_card(card):
	stop_highlight()
	highlighted_card = card
	card.transform.origin.y = 0.5
	card.hl_area.connect("mouse_exited", self, "_on_mouse_exited", [card])

func play_card(card):
	if cards.has(card):
		stop_highlight()
		can_play = false
		remove_card(card)
		controller.discard(card)
		emit_signal("turn_over")
