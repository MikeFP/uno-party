extends Spatial

var name_control_scene = preload("res://scenes/ui/PlayerName.tscn")
var event_popup_scene = preload("res://scenes/ui/EventPopup.tscn")

export var player_id := 0
export var controller_path: NodePath
export var deck_path: NodePath
export var uno_path: NodePath

onready var controller = get_node(controller_path)
onready var deck_obj = get_node(deck_path)
onready var uno_button = get_node(uno_path)

var name_ui
var ui_position = "top center"

var cards = []
var playable = []

var highlighted_card

var max_space_between_cards = 0.35
var max_width = 4
var card_width = 1.0
var card_height = 1.5

var can_play = false
var uno = false
var played_turn = false

signal card_played
signal drawn
signal playable_changed
signal uno_called
signal called_out_uno

func _ready():
	for c in $Cards.get_children():
		if GameState.player_name == null:
			add_card(c)
		else:
			remove_child(c)
			c.queue_free()

	deck_obj.connect("input_event", self, "_handle_deck_input")
	uno_button.connect("pressed", self, "_uno_pressed")

	if has_node("PlayerName"):
		name_ui = get_node("PlayerName")
	else:
		name_ui = name_control_scene.instance()
		add_child(name_ui)
	
	name_ui.get_node("Label").text = ("Player " + str(player_id)) if GameState.player_name == null else GameState.get_player_by_id(player_id)

func _process(_delta):
	var y_shift = 0
	var x_shift = 0
	var vert_just = ui_position.split(" ")[0]
	var hor_just = ui_position.split(" ")[1]
	if vert_just == "bottom":
		y_shift = -1
	if vert_just == "top":
		y_shift = 1
	if hor_just == "left":
		x_shift = -1
	if hor_just == "right":
		x_shift = 1
	
	var shift = Vector3(x_shift, y_shift, 0)
	var old_pos = name_ui.rect_position
	var world_pos = get_viewport().get_camera().unproject_position(transform.origin + shift)
	name_ui.rect_position = world_pos - name_ui.rect_size / 2
	if vert_just == "none":
		name_ui.rect_position.y = old_pos.y
	if hor_just == "none":
		name_ui.rect_position.x = old_pos.x
		
func _handle_deck_input(_camera, event, _click_pos, _normal, _shape):
	if event is InputEventMouseButton && event.pressed:
		if can_draw():
			if GameState.player_name == null && controller.player == self:
				draw()
			elif GameState.player_id == player_id:
				if not get_tree().is_network_server():
					rpc_id(1, "handle_draw")
				else:
					handle_draw()

remote func handle_draw():
	if can_draw():
		rpc("draw")

func can_draw():
	return can_play && playable.size() == 0

func lookat_camera():
	transform.basis = Basis()
	rotate_x(deg2rad(45))
	rotate_y(deg2rad(-180))

func start_turn():
	played_turn = false
	name_ui["custom_styles/panel"].modulate_color = Color8(251, 157, 59)

func enable_playing():
	can_play = true
	_update_playable()

func _update_playable():
	if controller.pile.size() > 0 && can_play:
		playable = Utils.get_playable_cards(cards, controller.top_card())
		emit_signal("playable_changed", playable)

		if GameState.player_name == null || player_id == GameState.player_id:
			for c in playable:
				c.enable_highlight()

func add_card(card):
	if !cards.has(card):

		if cards.size() > 0:
			uno = false

		cards.append(card)
		if !$Cards.get_children().has(card):
			Utils.reparent(card, $Cards)
			card.transform.basis = Basis()

		card.face_up()
		card.disable_area()
		card.hl_area.connect("mouse_entered", self, "_on_mouse_entered_hl_area", [card])
		card.hl_area.connect("input_event", self, "_on_card_click", [card])

		_update_playable()

func remove_card(card):
	var i = cards.find(card)
	if i != -1:
		cards.remove(i)
		if $Cards.get_children().has(card):
			$Cards.remove_child(card)
		card.hl_area.disconnect("mouse_entered", self, "_on_mouse_entered_hl_area")
		card.hl_area.disconnect("input_event", self, "_on_card_click")
		card.disable_highlight()
		card.enable_area()

		space_out()

remotesync func draw(amount := 1):
	var new_cards = []
	var size = cards.size()
	for i in range(amount):
		var c = yield(controller.pop_deck(), "completed")
		if i == amount - 1:
			yield(_delayed_add_drawn_card(c, size + i), "completed")
		else:
			_delayed_add_drawn_card(c, size + i)
			yield(get_tree().create_timer(0.275), "timeout")
		new_cards.append(c)
	emit_signal("drawn", new_cards)

func _delayed_add_drawn_card(card, current_amount):
	var anim = card.move_to(next_card_position(current_amount), self.global_transform.basis)
	yield(get_tree().create_timer(0.25), "timeout")
	space_out(current_amount + 1)
	yield(anim, "completed")
	add_card(card)

func space_out(override_amount = null, duration := 0.25):
	var amount = override_amount if override_amount != null else cards.size()
	var positions = _spaced_positions_for(amount)
	for i in range(min(cards.size(), positions.size())):
		var c = cards[i]
		c.move_to(to_global(positions[i]), null, true, 0, duration, 0)
	return positions

func _spaced_positions_for(cards_amount: int) -> Array:
	var res = []
	if cards_amount == 0:
		return res
	var bounds = _local_bounds_for(cards_amount)
	var width = bounds.size.x
	var sbc = max_space_between_cards if (width < max_width || cards_amount == 1) else ((max_width - card_width)/(cards_amount - 1))
	var x = bounds.position.x - card_width/2
	var z = bounds.size.z

	for _i in range(cards_amount):
		res.append(Vector3(x, 0, -z * 0.01))
		x -= sbc
		z += 1
	return res

func _local_bounds_for(cards_amount: int) -> AABB:
	var width = 0
	var x = 0
	if cards_amount > 0:
		width = (cards_amount - 1) * max_space_between_cards + card_width		
		width = min(width, max_width)
		x = width/2
	return AABB(Vector3.RIGHT * x, Vector3(width, 0, cards_amount * 0.01))

func next_card_position(override_amount = null) -> Vector3:
	var amount = override_amount if override_amount != null else cards.size()
	var bounds = _local_bounds_for(amount + 1)
	return to_global(Vector3.RIGHT * (-bounds.position.x + card_width/2)) - global_transform.basis.z * bounds.size.z

func _on_card_click(_camera, event, _click_pos, _normal, _shape, card):
	if can_play && playable.has(card) && event is InputEventMouseButton && event.pressed:
		if GameState.player_name == null:
			play_card(card.name)
		elif GameState.player_id == player_id:
			if not get_tree().is_network_server():
				rpc_id(1, "handle_play_card", card.name)
			else:
				handle_play_card(card.name)

remote func handle_play_card(card_name):
	if can_play:
		rpc("play_card", card_name)

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

remotesync func play_card(card_name):
	if $Cards.has_node(card_name):
		var card = $Cards.get_node(card_name)
		remove_card(card)
		can_play = false
		played_turn = true
		stop_highlight()
		for c in playable:
			c.disable_highlight()

		add_child(card)

		yield (controller.discard(card), "completed")

		emit_signal("card_played", card)

func end_turn():
	stop_highlight()
	playable = []
	name_ui["custom_styles/panel"].modulate_color = Color8(44, 145, 194)
	for c in cards:
		c.disable_highlight()
	emit_signal("playable_changed", playable)

func has_to_uno():
	return !uno && cards.size() == 1 && played_turn && player_id == controller.player.player_id

func can_uno():
	return !uno && cards.size() == 2 && can_play && playable.size() > 0

remotesync func call_uno():
	uno = true
	print("uno called")
	emit_signal("uno_called")

remotesync func call_out_uno():
	print("uno called out")
	emit_signal("called_out_uno")

remote func handle_call_uno():
	if can_uno():
		rpc("call_uno")

remote func handle_call_out_uno():
	if controller.player.has_to_uno() && player_id != controller.player.player_id:
		rpc("call_out_uno")

func _uno_pressed():
	if can_uno():
		if GameState.player_name == null:
			call_uno()
		else:
			if not get_tree().is_network_server():
				rpc_id(1, "handle_call_uno")
			else:
				handle_call_uno()
	elif controller.player.has_to_uno():
		if player_id == controller.player.player_id:
			if GameState.player_name == null:
				call_uno()
			else:
				if not get_tree().is_network_server():
					rpc_id(1, "handle_call_uno")
				else:
					handle_call_uno()
		else:
			if GameState.player_name == null:
				call_out_uno()
			else:
				if not get_tree().is_network_server():
					rpc_id(1, "handle_call_out_uno")
				else:
					handle_call_out_uno()

func ui_hand_center() -> Vector2:
	return get_viewport().get_camera().unproject_position(to_global(Vector3.UP * card_height)) + Vector2.UP * 20
				
func show_event_popup(event_text: String):
	var popup = event_popup_scene.instance()
	add_child(popup)
	popup.popup(ui_hand_center(), event_text, 2.0)
