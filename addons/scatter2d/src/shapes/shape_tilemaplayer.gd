@tool
class_name ScatterShapeTileMapLayer
extends ScatterShapeBase


@export var tilemap_layer_name: String:
	set(val):
		tilemap_layer_name = val
		emit_changed()

@export var size := Vector2i.ONE:
	set(val):
		size = val
		_size_in_pixels = size * tile_size
		_half_size = size / 2
		emit_changed()

@export var tile_size := Vector2i(32,32):
	set(val):
		tile_size = val
		_size_in_pixels = size * tile_size
		emit_changed()

var _layer_node: TileMapLayer = null
var _size_in_pixels := Vector2.ZERO
var _half_size := Vector2.ONE


func get_copy():
	var copy = get_script().new()
	copy.tilemap_layer_name = tilemap_layer_name
	copy.size = size
	copy.tile_size = tile_size
	return copy


func is_point_inside(point: Vector2, global_transform: Transform2D) -> bool:
	_get_layer_node()
	if _layer_node:
		var local_point = global_transform.affine_inverse() * point
		var map_pos = _layer_node.local_to_map(local_point)
		return _layer_node.get_cell(map_pos) == 1
	return false


func get_corners_global(gt: Transform2D) -> Array:
	_get_layer_node()
	var res := []
	if _layer_node:
		res.append(gt * Vector2(0, 0))
		res.append(gt * Vector2(0, _size_in_pixels.y))
		res.append(gt * Vector2(_size_in_pixels.x, _size_in_pixels.y))
		res.append(gt * Vector2(_size_in_pixels.x, 0))
	return res


func get_closed_edges(shape_t: Transform2D) -> Array[PackedVector2Array]:
	var box_edges := [
		[Vector2(0, 0), Vector2(0, 1)],
		[Vector2(0, 1), Vector2(1, 1)],
		[Vector2(1, 1), Vector2(1, 0)],
		[Vector2(1, 0), Vector2(0, 0)]
	]
	var points_unordered := PackedVector2Array()
	var shape_t_inverse := shape_t.affine_inverse()

	for edge in box_edges:
		var p1 = (edge[0] * _size_in_pixels) * shape_t_inverse
		var p2 = (edge[1] * _size_in_pixels) * shape_t_inverse
		points_unordered.push_back(p1)
		points_unordered.push_back(p2)

	var polygon := Geometry2D.convex_hull(points_unordered)
	return [polygon]


func _get_layer_node():
	if not _layer_node:
		var scene := (Engine.get_main_loop() as SceneTree).current_scene
		if scene:
			_layer_node = scene.find_child(tilemap_layer_name, true, false) as TileMapLayer
