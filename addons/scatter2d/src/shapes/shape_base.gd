@tool
class_name ScatterShapeBase
extends Resource


func is_point_inside_global(_point_global: Vector2, _global_transform: Transform2D) -> bool:
	return false


func is_point_inside_local(_point_local: Vector2) -> bool:
	return false


# Returns an array of Vector2. This should contain enough points to compute
# a bounding box for the given shape.
func get_corners_global(_shape_global_transform: Transform2D) -> Array[Vector2]:
	return []


# Returns the closed contour of the shape (closed, inner and outer if
# applicable) as a 2D polygon, in local space relative to the scatter node.
func get_closed_edges(_shape_t: Transform2D) -> Array[PackedVector2Array]:
	return []


# Returns the open edges (in the case of a regular path, not closed)
# in local space relative to the scatter node.
func get_open_edges(_shape_t: Transform2D) -> Array[Curve2D]:
	return []


# Returns a copy of this shape.
# TODO: check later when Godot4 enters beta if we can get rid of this and use
# the built-in duplicate() method properly.
func get_copy() -> Resource:
	return null
