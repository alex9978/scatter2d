@tool
extends "modifier_base.gd"

# Adds a single object with the given transform

@export var offset := Vector2.ZERO
@export var rotation:float = 0.0
@export var scale := Vector2.ONE


func _init() -> void:
	display_name = "Create Single Item"
	category = "Create"
	warning_ignore_no_shape = true
	warning_ignore_no_transforms = true
	global_reference_frame_available = true
	local_reference_frame_available = true
	individual_instances_reference_frame_available = false
	use_local_space_by_default()


func _process_transforms(transforms, domain, random_seed) -> void:
	var gt: Transform2D = domain.get_global_transform()
	var gt_inverse := gt.affine_inverse()
	gt_inverse.origin = Vector2.ZERO

	var t_origin := offset
	var t: Transform2D

	var pos: Vector2
	var new_transforms: Array[Transform2D] = []

	if is_using_global_space():
		t_origin = gt_inverse * t_origin
		t = gt_inverse

	t = t.rotated(deg_to_rad(rotation))

	if is_using_global_space():
		var global_t: Transform2D = gt * t
		global_t = global_t.scaled(scale)
		t = gt_inverse * global_t
	else:
		t = t.scaled_local(scale)

	t.origin = t_origin

	transforms.list.append(t)
