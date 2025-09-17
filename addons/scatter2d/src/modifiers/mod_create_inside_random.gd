@tool
extends "modifier_base.gd"


@export var amount := 10

var _rng: RandomNumberGenerator


func _init() -> void:
	display_name = "Create Inside (Random)"
	category = "Create"
	warning_ignore_no_transforms = true
	warning_ignore_no_shape = false
	can_override_seed = true
	global_reference_frame_available = true
	local_reference_frame_available = true
	use_local_space_by_default()
	
	documentation.add_paragraph(
		"Randomly place new transforms inside the area defined by
		the ScatterShape nodes.")

	var p := documentation.add_parameter("Amount")
	p.set_type("int")
	p.set_description("How many transforms will be created.")
	p.set_cost(2)

	documentation.add_warning(
		"In some cases, the amount of transforms created by this modifier
		might be lower than the requested amount (but never higher). This may
		happen if the provided ScatterShape has a huge bounding box but a tiny
		valid space, like a curved and narrow path.")


func _process_transforms(transforms, domain, random_seed) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.set_seed(random_seed)

	var gt: Transform2D = domain.get_global_transform()
	var center: Vector2 = domain.bounds_local.center
	var half_size: Vector2 = domain.bounds_local.size / 2.0
	var height: float = domain.bounds_local.center.y

	# Generate a random point in the bounding box. Store if it's inside the
	# domain, or discard if invalid. Repeat until enough valid points are found.
	var t: Transform2D
	var pos: Vector2
	var new_transforms: Array[Transform2D] = []
	var max_retries = amount * 10
	var tries := 0

	while new_transforms.size() != amount:
		t = Transform2D()
		pos = _random_vec2() * half_size + center

		if is_using_global_space():
			t = gt.affine_inverse()

		if domain.is_point_inside(pos):
			t.origin = pos
			new_transforms.push_back(t)
			continue

		# Prevents an infinite loop
		tries += 1
		if tries > max_retries:
			break

	transforms.append(new_transforms)


func _random_vec2() -> Vector2:
	var vec2 = Vector2.ZERO
	vec2.x = _rng.randf_range(-1.0, 1.0)
	vec2.y = _rng.randf_range(-1.0, 1.0)
	return vec2
