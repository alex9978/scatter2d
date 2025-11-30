@tool
extends "modifier_base.gd"


@export var rotation:float = 360.0
@export var snap_angle:float = 0

var _rng: RandomNumberGenerator


func _init() -> void:
	display_name = "Randomize Rotation"
	category = "Edit"
	can_override_seed = true
	global_reference_frame_available = true
	local_reference_frame_available = true
	individual_instances_reference_frame_available = true
	use_individual_instances_space_by_default()

	documentation.add_paragraph("Randomly rotate every transforms individually.")

	var p := documentation.add_parameter("Rotation")
	p.set_type("float")
	p.set_description("Rotation angle (in degrees)")

	p = documentation.add_parameter("Snap angle")
	p.set_type("Vector2")
	p.set_description(
		"When set to any value above 0, the rotation will be done by increments
		of the snap angle.")
	p.add_warning(
		"Example: When Snap Angle is set to 90, the possible random rotation
		offsets around an axis will be among [0, 90, 180, 360].")


func _process_transforms(transforms, domain, random_seed) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.set_seed(random_seed)

	var t: Transform2D
	var _gt: Transform2D = domain.get_global_transform()

	for i in transforms.size():
		t = transforms.list[i]
		var basis:Transform2D = t
		basis.origin = Vector2.ZERO

		# Apply rotation
		if is_using_individual_instances_space():
			basis = basis.orthonormalized()

		basis = basis.rotated(_random_angle(rotation, snap_angle))

		basis.origin = t.origin
		t = basis
		transforms.list[i] = t


func _random_vec2() -> Vector2:
	var vec2 = Vector2.ZERO
	vec2.x = _rng.randf_range(-1.0, 1.0)
	vec2.y = _rng.randf_range(-1.0, 1.0)
	return vec2


func _random_angle(rot: float, snap: float) -> float:
	return deg_to_rad(snapped(_rng.randf_range(-1.0, 1.0) * rot, snap))


func _clamp_vector(vec2, vmin, vmax) -> Vector2:
	vec2.x = clamp(vec2.x, vmin.x, vmax.x)
	vec2.y = clamp(vec2.y, vmin.y, vmax.y)
	return vec2
