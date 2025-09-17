@tool
extends "modifier_base.gd"


@export var instance_count := 10
@export var align_to_path := false

var _rng: RandomNumberGenerator


func _init() -> void:
	display_name = "Create Along Edge (Random)"
	category = "Create"
	warning_ignore_no_transforms = true
	warning_ignore_no_shape = false
	use_edge_data = true
	global_reference_frame_available = true
	local_reference_frame_available = true
	individual_instances_reference_frame_available = false


func _process_transforms(transforms, domain, random_seed) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.set_seed(random_seed)

	var gt_inverse: Transform2D = domain.get_global_transform()#.affine_inverse()
	var new_transforms: Array[Transform2D] = []
	var curves: Array[Curve2D] = domain.get_edges()
	var total_curve_length := 0.0

	for curve in curves:
		var length: float = curve.get_baked_length()
		total_curve_length += length

	for curve in curves:
		var length: float = curve.get_baked_length()
		var local_instance_count: int = round((length / total_curve_length) * instance_count)

		for i in local_instance_count:
			var pos = get_pos(curve, _rng.randf() * length)
			var t := Transform2D()

			t.origin = pos
			if align_to_path:
				t = t.looking_at(pos)
			elif is_using_global_space():
				t *= gt_inverse

			new_transforms.push_back(t)

	transforms.append(new_transforms)


func get_pos(curve: Curve2D, offset : float) -> Vector2:
	var pos: Vector2 = curve.sample_baked(offset)

	var pos1
	if offset + curve.get_bake_interval() < curve.get_baked_length():
		pos1 = curve.sample_baked(offset + curve.get_bake_interval())
	else:
		pos1 = curve.sample_baked(offset - curve.get_bake_interval())

	return pos
