@tool
class_name ScatterShapeCircle
extends ScatterShapeBase


@export var radius := 1.0:
	set(val):
		radius = val
		_radius_squared = val * val
		emit_changed()

var _radius_squared := 0.0


func get_copy():
	var copy = get_script().new()
	copy.radius = radius
	return copy


func is_point_inside(point: Vector2, global_transform: Transform2D) -> bool:
	var shape_center = global_transform * Vector2.ZERO
	return shape_center.distance_squared_to(point) < _radius_squared


func get_corners_global(gt: Transform2D) -> Array:
	var res := []
	var corners := [
		Vector2(-1, -1), 
		Vector2(-1,  1),
		Vector2( 1,  1),
		Vector2( 1,  -1),
		]

	for c in corners:
		c *= radius
		res.push_back(gt * c)

	return res
	
	
func get_closed_edges(shape_t: Transform2D) -> Array[PackedVector2Array]:
	var edge := PackedVector2Array()

	var origin := shape_t.origin
	var steps: int = max(16, int(radius * 12))
	var angle: float = TAU / steps

	for i in steps + 1:
		var theta = angle * i
		var point := origin + Vector2(cos(theta), sin(theta)) * radius
		edge.push_back(point)

	return [edge]
