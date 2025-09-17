@tool
extends "modifier_base.gd"


@export var item_length := 25.0


var _current_offset = 0.0


func _init() -> void:
	display_name = "Create Along Edge (Continuous)"
	category = "Create"
	warning_ignore_no_transforms = true
	warning_ignore_no_shape = false
	use_edge_data = true
	global_reference_frame_available = false
	local_reference_frame_available = false
	individual_instances_reference_frame_available = false

	var p

	documentation.add_paragraph(
		"Create new transforms along the edges of the Scatter shapes. These
		transforms are placed so they touch each other but don't overlap, even
		if the curve has sharp turns.")

	documentation.add_paragraph(
		"This is useful to place props suchs as fences, walls or anything that
		needs to look organized without leaving gaps.")

	documentation.add_warning(
		"The transforms are placed starting from the begining of each curves.
		If the curve is closed, there will be a gap at the end if the total
		curve length isn't a multiple of the item length.")

	p = documentation.add_parameter("Item length")
	p.set_type("float")
	p.set_description("How long is the item being placed")
	p.set_cost(2)
	p.add_warning(
		"The smaller this value, the more transforms will be created.
		Setting a slightly different length than the actual model length
		allow for gaps between each transforms.")


# TODO: Use dichotomic search instead of fixed step length?
func _process_transforms(transforms, domain, seed) -> void:
	var new_transforms: Array[Transform2D] = []
	var curves: Array[Curve2D] = domain.get_edges()

	for curve in curves:
		curve = curve.duplicate()

		var length_squared = pow(item_length, 2)
		var offset_max = curve.get_baked_length()
		var offset = 0.0
		var step = item_length / 20.0

		while offset < offset_max:
			var start := curve.sample_baked(offset)
			var end: Vector2
			var dist: float
			offset += item_length * 0.9 # Saves a few iterations, the target
				# point will never be closer than the item length, only further

			while offset < offset_max:
				offset += step
				end = curve.sample_baked(offset)
				dist = start.distance_squared_to(end)

				if dist >= length_squared:
					var t = Transform2D()
					t.origin = start + ((end - start) / 2.0)
					new_transforms.push_back(t.looking_at(end))
					break

	transforms.append(new_transforms)
	transforms.shuffle(seed)


func get_projected_curve(curve: Curve2D, t: Transform2D) -> Curve2D:
	var points = curve.tessellate()
	var new_curve = Curve2D.new()
	for p in points:
		p.y = t.origin.y
		new_curve.add_point(p)

	return new_curve
