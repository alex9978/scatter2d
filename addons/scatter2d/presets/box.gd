@tool
extends Node2D

@export var size := Vector2(20, 20)
@export var color := Color(0, 0.8, 0)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-size/2, size), color / 2, true)
	draw_rect(Rect2(-size/2, size), color, false, 1, true)
