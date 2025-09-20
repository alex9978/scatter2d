@tool
extends "modifier_base.gd"


@export var position := Vector2.ZERO
@export var rotation:float = 0.0
@export var scale := Vector2.ZERO

var _rng: RandomNumberGenerator


func _init() -> void:
	display_name = "Randomize Transforms"
	category = "Edit"
	can_override_seed = true
	global_reference_frame_available = true
	local_reference_frame_available = true
	individual_instances_reference_frame_available = true
	use_individual_instances_space_by_default()


func _process_transforms(transforms, domain, random_seed) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.set_seed(random_seed)

	var t: Transform2D
	var global_t: Transform2D
	var random_scale: Vector2
	var random_position: Vector2
	var gt: Transform2D = domain.get_global_transform()
	var gt_inverse := gt.affine_inverse()

	for i in transforms.size():
		t = transforms.list[i]
		var basis:Transform2D = t
		basis.origin = Vector2.ZERO

		# Apply rotation
		if is_using_individual_instances_space():
			basis = basis.orthonormalized()

		basis = basis.rotated(deg_to_rad(_random_float() * rotation))

		# Apply scale
		random_scale = Vector2.ONE + (_rng.randf() * scale)

		if is_using_individual_instances_space():
			basis.x *= random_scale.x
			basis.y *= random_scale.y
		elif is_using_global_space():
			global_t = gt * basis
			global_t = global_t.scaled(random_scale)
			basis = gt_inverse * global_t
		else:
			basis = basis.scaled_local(random_scale)

		# Apply translation
		random_position = _random_vec2() * position

		if is_using_individual_instances_space():
			random_position = basis * random_position
		elif is_using_global_space():
			gt_inverse.origin = Vector2.ZERO
			random_position = gt_inverse * random_position

		basis.origin = t.origin + random_position
		t = basis
		transforms.list[i] = t



func _random_vec2() -> Vector2:
	var vec2 = Vector2.ZERO
	vec2.x = _rng.randf_range(-1.0, 1.0)
	vec2.y = _rng.randf_range(-1.0, 1.0)
	return vec2


func _random_float() -> float:
	return _rng.randf_range(-1.0, 1.0)


func _clamp_vector(vec2, vmin, vmax) -> Vector2:
	vec2.x = clamp(vec2.x, vmin.x, vmax.x)
	vec2.y = clamp(vec2.y, vmin.y, vmax.y)
	return vec2
