@tool
class_name ScatterShapeBox
extends ScatterShapeBase


@export var size := Vector2.ONE:
	set(val):
		size = val
		_half_size = size * 0.5
		emit_changed()

var _half_size := Vector2.ONE


func get_copy():
	var copy = get_script().new()
	copy.size = size
	return copy


func is_point_inside(point: Vector2, global_transform: Transform2D) -> bool:
	var local_point = global_transform.affine_inverse() * point
	return Rect2(-_half_size, size).has_point(local_point)


func get_corners_global(gt: Transform2D) -> Array:
	var res := []
	var corners := [
		Vector2(-1, -1),
		Vector2(-1,  1),
		Vector2( 1,  1),
		Vector2( 1,  -1),
		]

	for c in corners:
		c *= _half_size
		res.push_back(gt * c)

	return res


func get_closed_edges(shape_t: Transform2D) -> Array[PackedVector2Array]:

	var box_edges := [
		[Vector2(-1, -1), Vector2(-1,  1)],
		[Vector2(-1,  1), Vector2( 1,  1)],
		[Vector2( 1,  1), Vector2( 1, -1)],
		[Vector2( 1, -1), Vector2(-1, -1)]
	]
	var points_unordered := PackedVector2Array()
	var shape_t_inverse := shape_t.affine_inverse()

	for edge in box_edges:
		var p1 = (edge[0] * _half_size) * shape_t_inverse
		var p2 = (edge[1] * _half_size) * shape_t_inverse
		points_unordered.push_back(p1)
		points_unordered.push_back(p2)

	var polygon := Geometry2D.convex_hull(points_unordered)
	return [polygon]
