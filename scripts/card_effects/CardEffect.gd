extends Node
class_name CardEffect

var card

signal processed

func process(_player):
	emit_signal("processed")
