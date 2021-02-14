extends Node
class_name CardEffect

var card

signal processed
signal post_processed

func process(_player, _controller):
	emit_signal("processed")

func post_process(_player, _controller):
	emit_signal("post_processed")
