@tool
extends Button


@onready var _popup: PopupPanel = $ModifiersPopup


func _ready() -> void:
	_popup.popup_hide.connect(_on_popup_closed)


func _toggled(btn_pressed):
	if btn_pressed:
		_popup.popup_centered()


func _on_popup_closed() -> void:
	button_pressed = false
