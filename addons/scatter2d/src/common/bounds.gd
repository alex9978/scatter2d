@tool
extends Resource

var size: Vector2
var center: Vector2
var min: Vector2
var max: Vector2

var _points := 0


func clear() -> void:
	size = Vector2.ZERO
	center = Vector2.ZERO
	min = Vector2.ZERO
	max = Vector2.ZERO
	_points = 0


func feed(point: Vector2) -> void:
	if _points == 0:
		min = point
		max = point

	min = _minv(min, point)
	max = _maxv(max, point)
	_points += 1


# Call this after you've called feed() with all the points in your data set
func compute_bounds() -> void:
	if min == null or max == null:
		return

	size = max - min
	center = min + (size / 2.0)


# Returns a vector with the smallest values in each of the 2 input vectors
func _minv(v1: Vector2, v2: Vector2) -> Vector2:
	return Vector2(min(v1.x, v2.x), min(v1.y, v2.y))


# Returns a vector with the highest values in each of the 2 input vectors
func _maxv(v1: Vector2, v2: Vector2) -> Vector2:
	return Vector2(max(v1.x, v2.x), max(v1.y, v2.y))
