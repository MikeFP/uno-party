extends CardEffect
class_name PickColorEffect

var color_selector_scene = preload("res://scenes/ui/Color Picker.tscn")

signal color_picked

func process(player, _controller):
	if GameState.player_name == null || player.player_id == GameState.player_id:
		var color_selector = color_selector_scene.instance()
		color_selector.hide()
		add_child(color_selector)
		color_selector.show()
		var color = yield(color_selector, "color_picked")
		color_selector.hide()
		if GameState.player_name != null:
			rpc("_on_color_picked", color)
		else:
			_on_color_picked(color)
	else:
		yield (self, "color_picked")
	
	emit_signal("processed")

remotesync func _on_color_picked(color):
	card.color = color
	emit_signal("color_picked")
