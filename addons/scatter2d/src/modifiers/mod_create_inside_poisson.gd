@tool
extends "modifier_base.gd"

# Poisson disc sampling based on Sebastian Lague implementation.
# Reference: https://www.youtube.com/watch?v=7WcmyxyFO7o

# TODO: This doesn't work if the valid space isn't one solid space
# (fails to fill the full domain if it's made of discrete, separate shapes)


const Bounds := preload("../common/bounds.gd")

@export_range(1, 1000) var radius := 25.0
@export var samples_before_rejection := 15


var _rng: RandomNumberGenerator
var _squared_radius: float
var _domain
var _bounds: Bounds

var _gt: Transform2D
var _points: Array[Transform2D] # Stores the generated points
var _grid: Array[int] = [] # Flattened array
var _grid_size := Vector2i.ZERO
var _cell_size: float
var _cell_x: int
var _cell_y: int
var _starting_point_found = false


func _init() -> void:
	display_name = "Create Inside (Poisson)"
	category = "Create"
	warning_ignore_no_transforms = true
	warning_ignore_no_shape = false
	can_override_seed = true
	global_reference_frame_available = true
	local_reference_frame_available = true
	individual_instances_reference_frame_available = false
	use_local_space_by_default()

	documentation.add_paragraph(
		"Place transforms without overlaps. Transforms are assumed to have a
		spherical shape.")

	var p := documentation.add_parameter("Radius")
	p.set_type("float")
	p.set_description("Transform size.")
	p.add_warning(
		"The larger the radius, the harder it will be to place the transform,
		resulting in a faster early exit.
		On the other hand, smaller radius means more room for more points,
		meaning more transforms to generate so it will take longer to complete.")

	p = documentation.add_parameter("Samples before rejection")
	p.set_type("int")
	p.set_description(
		"The algorithm tries a point at random until it finds a valid one. This
		parameter controls how many attempts before moving to the next
		iteration. Lower values are faster but gives poor coverage. Higher
		values generates better coverage but are slower.")
	p.set_cost(2)

	documentation.add_warning(
		"This modifier uses a poisson disk sampling algorithm which can be
		quite slow.")


func _process_transforms(transforms, domain, seed) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.set_seed(seed)
	_domain = domain
	_bounds = _domain.bounds_local
	_gt = domain.get_global_transform()
	_points = []
	_init_grid()

	# Stores the possible starting points from where we run the sampling.
	# This array will progressively be emptied as the algorithm progresses.
	var spawn_points: Array[Transform2D]
	spawn_points.push_back(_get_starting_point())

	if not _starting_point_found:
		push_warning("Poisson: no starting point found")
		enabled = false
		return

	# Sampler main loop
	while not spawn_points.is_empty():

		# Pick a starting point at random from the existing list
		var spawn_index: int = _rng.randi_range(0, spawn_points.size() - 1)
		var spawn_center := spawn_points[spawn_index]

		var tries := 0
		var candidate_accepted := false

		while tries < samples_before_rejection:
			tries += 1

			# Generate a random point in space, outside the radius of the spawn point
			var dir: Vector2 = _generate_random_vector()
			var candidate: Vector2 = spawn_center.origin + dir * _rng.randf_range(radius, radius * 2.0)

			if _is_valid(candidate):
				candidate_accepted = true

				# Add new points to the lists
				var t = Transform2D()

				if is_using_global_space():
					t = _gt.affine_inverse()

				t.origin = candidate
				_points.push_back(t)
				spawn_points.push_back(t)

				var index = _cell_x + _cell_y * _grid_size.y
				if index >= 0 and index < _grid.size():
					_grid[index] = _points.size() - 1

				break

		# Failed to find a point after too many tries. The space around this
		# spawn point is probably full, discard it.
		if not candidate_accepted:
			spawn_points.remove_at(spawn_index)

	transforms.append(_points)
	transforms.shuffle(seed)


func _init_grid() -> void:
	_squared_radius = radius * radius
	_cell_size = radius / sqrt(2)
	_grid_size.x = ceil(_bounds.size.x / _cell_size)
	_grid_size.y = ceil(_bounds.size.y / _cell_size)

	_grid_size = _grid_size.clamp(Vector2.ONE, _grid_size)

	_grid = []
	_grid.resize(_grid_size.x * _grid_size.y)


# Starting point must be inside the domain, or we run the risk to never generate
# any valid point later on
# TODO: Domain may have islands, so we should use multiple starting points
func _get_starting_point() -> Transform2D:
	var point: Vector2 = _bounds.center
	_starting_point_found = false

	var tries := 0
	while not _domain.is_point_inside(point) and tries < 200:
		tries += 1
		point.x = _rng.randf_range(_bounds.bmin.x, _bounds.bmax.x)
		point.y = _rng.randf_range(_bounds.bmin.y, _bounds.bmax.y)

	_starting_point_found = tries < 200

	var starting_point := Transform2D()
	starting_point.origin = point
	return starting_point


func _is_valid(candidate: Vector2) -> bool:
	if not _domain.is_point_inside(candidate):
		return false

	# compute candidate current cell
	var t_candidate = candidate - _bounds.bmin
	_cell_x = floor(t_candidate.x / _cell_size)
	_cell_y = floor(t_candidate.y / _cell_size)

	# Search the surrounding cells for other points
	var search_start_x: int = max(0, _cell_x - 2)
	var search_end_x: int = min(_cell_x + 2, _grid_size.x - 1)
	var search_start_y: int = max(0, _cell_y - 2)
	var search_end_y: int = min(_cell_y + 2, _grid_size.y - 1)

	for x in range(search_start_x, search_end_x + 1):
		for y in range(search_start_y, search_end_y + 1):
			var array_index = x + y * _grid_size.y
			if array_index >= _grid.size():
				return false
			var point_index = _grid[array_index]
			if _is_point_too_close(candidate, point_index):
				return false

	return true


func _is_point_too_close(candidate: Vector2, point_index: int) -> bool:
	if point_index >= _points.size():
		return false

	var other_point := _points[point_index]
	var squared_dist: float = candidate.distance_squared_to(other_point.origin)
	return squared_dist < _squared_radius


func _generate_random_vector() -> Vector2:
	var angle = _rng.randf_range(0.0, TAU)
	return Vector2(sin(angle), cos(angle))
