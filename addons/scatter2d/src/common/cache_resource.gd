@tool
class_name ScatterCacheResource
extends Resource


@export var data = {}


func clear() -> void:
	data.clear()


func store(node_path: String, transforms: Array[Transform2D]) -> void:
	data[node_path] = transforms


func erase(node_path: String) -> void:
	data.erase(node_path)


func get_transforms(node_path: String) -> Array[Transform2D]:
	var res: Array[Transform2D]

	if node_path in data:
		res.assign(data[node_path])

	return res
