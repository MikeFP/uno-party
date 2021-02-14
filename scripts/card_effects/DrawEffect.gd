extends CardEffect
class_name DrawEffect

var amount : int

func _init(cards_amount):
    self.amount = cards_amount

func post_process(player, controller):
    player.show_event_popup("Drawing " + str(amount))
    yield(get_tree().create_timer(0.25), "timeout")
    yield(player.draw(amount), "completed")
    yield(get_tree().create_timer(0.25), "timeout")
    controller.next_player(false)
    emit_signal("post_processed")
