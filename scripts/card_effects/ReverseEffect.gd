extends CardEffect
class_name ReverseEffect

func process(_player, controller):
	if controller.remaining.size() > 2:
		controller.set_order_reversed(!controller.order_reversed)
	emit_signal("processed")

func post_process(player, controller):
	if controller.remaining.size() == 2 && (player in controller.remaining):
		player.show_event_popup("Turn blocked")
		yield(get_tree().create_timer(1.0), "timeout")
		controller.next_player(false)
	emit_signal("post_processed")
