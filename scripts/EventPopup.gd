extends Panel

onready var label := $"MarginContainer/Label"

func popup(position: Vector2, text: String, duration := 0.0):
	label.text = text
	rect_position = position - Vector2.RIGHT * rect_size.x / 2
	if (duration > 0):
		yield(get_tree().create_timer(duration), "timeout")
		close()

func close():
	hide()
	queue_free()
