extends Spatial

export var player_id := 0
export var controller_path: NodePath
export var deck_path: NodePath
export var uno_path: NodePath

onready var controller = get_node(controller_path)
onready var deck_obj = get_node(deck_path)
onready var uno_button = get_node(uno_path)

var cards = []
var playable = []

var highlighted_card

var max_space_between_cards = 0.35
var max_width = 4

var can_play = false
var uno = false
var played_turn = false

signal card_played
signal drawn
signal playable_changed
signal uno_called
signal called_out_uno

func _ready():
	for c in get_children():
		add_card(c)
	deck_obj.connect("input_event", self, "_handle_deck_input")
	uno_button.connect("pressed", self, "_uno_pressed")

func _handle_deck_input(_camera, event, _click_pos, _normal, _shape):
	if event is InputEventMouseButton && event.pressed:
		if can_draw():
			draw()

func can_draw():
	return can_play && playable.size() == 0

func lookat_camera():
	transform.basis = Basis()
	rotate_x(deg2rad(45))
	rotate_y(deg2rad(-180))

func start_turn():
	can_play = true
	played_turn = false
	_update_playable()

func _update_playable():
	if controller.pile.size() > 0:
		playable = Utils.get_playable_cards(cards, controller.top_card())
		emit_signal("playable_changed", playable)
		for c in playable:
			c.enable_highlight()

func add_card(card):
	if !cards.has(card):

		if uno:
			uno = false

		cards.append(card)
		if !get_children().has(card):
			add_child(card)
			card.transform.basis = Basis()

		card.face_up()
		card.disable_area()
		card.hl_area.connect("mouse_entered", self, "_on_mouse_entered_hl_area", [card])
		card.hl_area.connect("input_event", self, "_on_card_click", [card])

		space_out()
		_update_playable()

func remove_card(card):
	var i = cards.find(card)
	if i != -1:
		cards.remove(i)
		if get_children().has(card):
			remove_child(card)
		card.hl_area.disconnect("mouse_entered", self, "_on_mouse_entered_hl_area")
		card.hl_area.disconnect("input_event", self, "_on_card_click")
		card.disable_highlight()
		card.enable_area()

		space_out()

func draw(amount := 1):
	var new_cards = []
	for _i in range(amount):
		var c = controller.pop_deck()
		add_card(c)
		new_cards.append(c)
	emit_signal("drawn", new_cards)

func space_out():
	if cards.size() > 0:
		var width = (cards.size() - 1) * max_space_between_cards + 1.0
		var sbc = max_space_between_cards if width < max_width else ((max_width - 1.0)/(cards.size() - 1))
		
		width = min(width, max_width)

		var x = -width/2 + 0.5
		var i = cards.size() - 1
		for c in cards:
			c.transform.origin.x = x
			c.transform.origin.z = - i * 0.01
			x += sbc
			i -= 1

func _on_card_click(_camera, event, _click_pos, _normal, _shape, card):
	if can_play && playable.has(card) && event is InputEventMouseButton && event.pressed:
		play_card(card)

func _on_mouse_entered_hl_area(card):
	if highlighted_card == null && card in playable:
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
		remove_card(card)
		controller.discard(card)
		played_turn = true
		emit_signal("card_played", card)

func end_turn():
	stop_highlight()
	can_play = false
	for c in playable:
		c.disable_highlight()
	playable = []
	emit_signal("playable_changed", playable)

func has_to_uno():
	return !uno && cards.size() == 1 && played_turn && player_id == controller.player.player_id

func can_uno():
	return !uno && cards.size() == 2 && can_play && playable.size() > 0

func call_uno():
	uno = true
	emit_signal("uno_called")

func call_out_uno():
	emit_signal("called_out_uno")

func _uno_pressed():
	if can_uno():
		call_uno()
	elif controller.player.has_to_uno():
		if player_id == controller.player.player_id:
			call_uno()
		else:
			call_out_uno()
