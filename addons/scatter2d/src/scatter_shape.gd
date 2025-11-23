@tool
class_name ScatterShape
extends Node2D


const ScatterUtils := preload('common/scatter_utils.gd')


@export_category("ScatterShape")
@export var negative = false:
	set(val):
		negative = val
		ScatterUtils.request_parent_to_rebuild(self)

@export var shape: ScatterShapeBase:
	set(val):
		# Disconnect the previous shape if any
		if shape and shape.changed.is_connected(_on_shape_changed):
			shape.changed.disconnect(_on_shape_changed)

		shape = val
		if shape:
			shape.changed.connect(_on_shape_changed)

		ScatterUtils.request_parent_to_rebuild(self)

@export_group("Debug", "dbg_")
@export var dbg_color = Color(1, 0.4, 0)


var _ignore_transform_notification = false
var _drawing_color: Color
var _light_color: Color


func _ready() -> void:
	set_notify_transform(true)


func _process(_delta: float) -> void:
	queue_redraw()


func _notification(what):
	match what:
		NOTIFICATION_TRANSFORM_CHANGED:
			if _ignore_transform_notification:
				_ignore_transform_notification = false
				return
			ScatterUtils.request_parent_to_rebuild(self)

		NOTIFICATION_ENTER_TREE:
			_ignore_transform_notification = true


func _set(property, _value):
	if not Engine.is_editor_hint():
		return false

	# Workaround to detect when the node was duplicated from the editor.
	if property == "transform":
		_on_node_duplicated.call_deferred()

	return false


func _on_shape_changed() -> void:
	ScatterUtils.request_parent_to_rebuild(self)


func _on_node_duplicated() -> void:
	shape = shape.get_copy() # Enfore uniqueness on duplicate, could be an option


func _draw():
	if not Engine.is_editor_hint():
		return

	if not _is_selected(self):
		return

	_update_colors(dbg_color)

	if shape:
		if "curve" in shape and shape.thickness == 0:
			var curve: Curve2D = shape.curve
			if curve:
				var points := curve.tessellate(4, 8)
				if points.size() > 1:
					draw_polyline(points, _drawing_color, 2, true)
		else:
			var edges = shape.get_closed_edges(Transform2D())
			for edge in edges:
				draw_colored_polygon(edge, _light_color)
				draw_polyline(edge, _drawing_color, 2, true)


func _is_selected(node: Node) -> bool:
	var editor_selection = Engine.get_singleton(&"EditorInterface").get_selection()
	var selected = node in editor_selection.get_selected_nodes()
	if negative and not selected:
		selected = get_parent() in editor_selection.get_selected_nodes()
	return selected


func _update_colors(base_color:Color):
	_drawing_color = base_color
	_light_color = base_color
	_light_color.a /= 4
	if negative:
		_drawing_color = _drawing_color.inverted()
		_light_color = _light_color.inverted()
