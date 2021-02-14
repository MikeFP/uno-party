extends CardEffect
class_name BlockEffect

func post_process(player, controller):
	player.show_event_popup("Turn blocked")
	yield(get_tree().create_timer(1.0), "timeout")
	controller.next_player(false)
	emit_signal("post_processed")