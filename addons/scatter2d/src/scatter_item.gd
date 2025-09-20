@tool
class_name ScatterItem
extends Node2D


const ScatterUtils := preload('common/scatter_utils.gd')


@export_category("ScatterItem")
@export var proportion := 100:
	set(val):
		proportion = val
		ScatterUtils.request_parent_to_rebuild(self)

@export_enum("From current scene:0", "From disk:1") var source = 1:
	set(val):
		source = val
		property_list_changed.emit()

@export_group("Source options", "source_")
@export var source_scale_multiplier := 1.0:
	set(val):
		source_scale_multiplier = val
		ScatterUtils.request_parent_to_rebuild(self)

@export var source_ignore_position := true:
	set(val):
		source_ignore_position = val
		ScatterUtils.request_parent_to_rebuild(self)

@export var source_ignore_rotation := true:
	set(val):
		source_ignore_rotation = val
		ScatterUtils.request_parent_to_rebuild(self)

@export var source_ignore_scale := true:
	set(val):
		source_ignore_scale = val
		ScatterUtils.request_parent_to_rebuild(self)

@export_group("Override options", "override_")
@export var override_material: Material:
	set(val):
		override_material = val
		ScatterUtils.request_parent_to_rebuild(self)

@export var override_process_material: Material:
	set(val):
		override_process_material = val
		ScatterUtils.request_parent_to_rebuild(self) # TODO - No need for a full rebuild here

var path: String:
	set(val):
		path = val
		source_data_ready = false
		_target_scene = load(path) if source != 0 else null
		ScatterUtils.request_parent_to_rebuild(self)

var source_position: Vector2
var source_rotation: float
var source_scale: Vector2
var source_data_ready := false

var _target_scene: PackedScene


func _get_property_list() -> Array:
	var list := []

	if source == 0:
		list.push_back({
			name = "path",
			type = TYPE_NODE_PATH,
		})
	else:
		list.push_back({
			name = "path",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_FILE,
		})

	return list


func get_item() -> Node2D:
	if path.is_empty():
		return null

	var node: Node2D

	if source == 0 and has_node(path):
		node = get_node(path).duplicate() # Never expose the original node
	elif source == 1:
		node = _target_scene.instantiate()

	if node:
		_save_source_data(node)
		return node

	return null


# Takes a transform in input, scale it based on the local scale multiplier
# If the source transform is not ignored, also copy the source position, rotation and scale.
# Returns the processed transform
func process_transform(t: Transform2D) -> Transform2D:
	if not source_data_ready:
		_update_source_data()

	var origin = t.origin
	t.origin = Vector2.ZERO

	t = t.scaled(Vector2.ONE * source_scale_multiplier)

	if not source_ignore_scale:
		t = t.scaled(source_scale)

	if not source_ignore_rotation:
		t = t.rotated(source_rotation)

	t.origin = origin

	if not source_ignore_position:
		t.origin += source_position

	return t


func _save_source_data(node: Node2D) -> void:
	if not node:
		return

	source_position = node.position
	source_rotation = node.rotation
	source_scale = node.scale
	source_data_ready = true


func _update_source_data() -> void:
	var node = get_item()
	if node:
		node.queue_free()
