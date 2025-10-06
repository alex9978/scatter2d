@tool
extends "modifier_base.gd"


const Utils := preload("../common/scatter_utils.gd")


# TODO :
# + change alignement parameters to something more usable and intuitive
# + Use the curve up vector, default to local Y+ when not available
@export var spacing := 25.0
@export var offset := 0.0
@export var align_to_path := false

var _min_spacing := 0.05


func _init() -> void:
	display_name = "Create Along Edge (Even)"
	category = "Create"
	warning_ignore_no_transforms = true
	warning_ignore_no_shape = false
	global_reference_frame_available = true
	local_reference_frame_available = true
	individual_instances_reference_frame_available = false
	use_edge_data = true

	var p

	documentation.add_paragraph(
		"Evenly create transforms along the edges of the ScatterShapes")

	p = documentation.add_parameter("Spacing")
	p.set_type("float")
	p.set_description("How much space between the transforms origin")
	p.set_cost(3)
	p.add_warning("The smaller the value, the denser the resulting transforms list.", 1)
	p.add_warning(
		"A value of 0 would result in infinite transforms, so it's capped
		to 0.05 at least.")


func _process_transforms(transforms, domain, seed) -> void:
	spacing = max(_min_spacing, spacing)

	var gt_inverse: Transform2D = domain.get_global_transform().affine_inverse()
	var new_transforms: Array[Transform2D] = []
	var curves: Array[Curve2D] = domain.get_edges()

	for curve in curves:
		var length: float = curve.get_baked_length()
		var count := int(round(length / spacing))
		var stepped_length: float = count * spacing

		for i in count:
			var curve_offset = i * spacing + abs(offset)

			while curve_offset > stepped_length: # Loop back to the curve start if offset is too large
				curve_offset -= stepped_length

			var data : Array = Utils.get_position_and_normal_at(curve, curve_offset)
			var pos: Vector2 = data[0]
			var normal: Vector2 = data[1]

			if domain.is_point_excluded(pos):
				continue

			var t := Transform2D()
			t.origin = pos
			if align_to_path:
				t = t.looking_at(normal + pos)
			elif is_using_global_space():
				t = gt_inverse

			new_transforms.push_back(t)

	transforms.append(new_transforms)
	transforms.shuffle(seed)
