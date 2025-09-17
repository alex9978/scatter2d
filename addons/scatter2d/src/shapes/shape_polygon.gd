@tool
class_name ScatterShapePolygon
extends ScatterShapeBase


@export var polygon_points: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)]) :
	set(value):
		polygon_points = value
		_update_internal_points()
		emit_changed()


@export var simplify_polygon: bool = false :
	set(value):
		simplify_polygon = value
		_update_internal_points()
		emit_changed()
		
		
@export var epsilon: float = 1.0 :
	set(value):
		epsilon = value
		_update_internal_points()
		emit_changed()
		
		
var _internal_points: PackedVector2Array


func get_copy():
	var copy = get_script().new()
	copy.polygon_points = polygon_points.duplicate()
	copy.simplify_polygon = simplify_polygon
	copy.epsilon = epsilon
	return copy


func is_point_inside(point: Vector2, global_transform: Transform2D) -> bool:
	var local_point = global_transform.affine_inverse() * point
	return Geometry2D.is_point_in_polygon(local_point, _internal_points)


func get_corners_global(gt: Transform2D) -> Array:
	var res := []
	for p in _internal_points:
		res.push_back(gt * p)
	return res


func get_closed_edges(shape_t: Transform2D) -> Array[PackedVector2Array]:
	var edges: Array[PackedVector2Array]
	for i in range(_internal_points.size()):
		var p1 = _internal_points[i]
		var p2 = _internal_points[(i + 1) % _internal_points.size()]
		edges.append(PackedVector2Array([shape_t * p1, shape_t * p2]))
	return edges


func _update_internal_points():
	if simplify_polygon:
		_internal_points = _simplify_polygon(polygon_points, epsilon)
	else:
		_internal_points = polygon_points


func _simplify_polygon(points: PackedVector2Array, epsilon: float) -> PackedVector2Array:
	if points.size() < 3:
		return points

	# find the point furthest from the line between the first and last points
	var dmax = 0.0
	var index = 0
	var start_point = points[0]
	var end_point = points[points.size() - 1]
	
	for i in range(1, points.size() - 1):
		var d = _perpendicular_distance(points[i], start_point, end_point)
		if d > dmax:
			index = i
			dmax = d

	# if the maximum distance is greater than epsilon, recursively simplify
	if dmax > epsilon:
		var left_points = PackedVector2Array()
		var right_points = PackedVector2Array()

		for i in range(0, index + 1):
			left_points.append(points[i])
		for i in range(index, points.size()):
			right_points.append(points[i])

		var rec_results1 = _simplify_polygon(left_points, epsilon)
		var rec_results2 = _simplify_polygon(right_points, epsilon)

		# combine without duplicating the junction point
		var result = PackedVector2Array()
		for i in range(rec_results1.size() - 1):
			result.append(rec_results1[i])
		for i in range(rec_results2.size()):
			result.append(rec_results2[i])
		return result
	else:
		return PackedVector2Array([start_point, end_point])
	
	
func _perpendicular_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var numerator = abs((line_end.y - line_start.y) * point.x - (line_end.x - line_start.x) * point.y + line_end.x * line_start.y - line_end.y * line_start.x)
	var denominator = line_start.distance_to(line_end)
	if denominator == 0:
		return point.distance_to(line_start)
	return numerator / denominator
	
