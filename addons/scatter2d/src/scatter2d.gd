@tool
class_name Scatter2D
extends Node2D


@warning_ignore("unused_signal")
signal shape_changed
@warning_ignore("unused_signal")
signal thread_completed
signal build_completed


const ScatterDomain := preload("common/domain.gd")
const ScatterModifierStack := preload("stack/modifier_stack.gd")
const ScatterTransformList := preload("common/transform_list.gd")
const ScatterUtils := preload('common/scatter_utils.gd')


@export_group("General")
@export var enabled := true:
	set(val):
		enabled = val
		if is_ready:
			rebuild()
@export var global_seed := 0:
	set(val):
		global_seed = val
		rebuild()
@export var enable_y_sorting := true:
	set(val):
		enable_y_sorting = val
		rebuild()
@export var show_output_in_tree := false:
	set(val):
		show_output_in_tree = val
		if output_root:
			ScatterUtils.enforce_output_root_owner(self)

@export_group("Performance")
@export_enum("Use Instancing:0",
			"Create Copies:1",
			"Use Particles:2")\
		var render_mode := 1:
	set(val):
		render_mode = val
		notify_property_list_changed()
		if is_ready:
			full_rebuild.call_deferred()

@export var keep_static_colliders := false
@export var force_rebuild_on_load := true
@export var enable_updates_in_game := false

@export_group("Dependency")
@export var scatter_parent: NodePath:
	set(val):
		if not is_inside_tree():
			scatter_parent = val
			return

		scatter_parent = NodePath()
		if is_instance_valid(_dependency_parent):
			_dependency_parent.build_completed.disconnect(rebuild)
			_dependency_parent = null

		var node = get_node_or_null(val)
		if not node:
			return

		var type = node.get_script()
		var scatter_type = get_script()
		if type != scatter_type:
			push_warning("Scatter warning: Please select a Scatter node as a parent dependency.")
			return

		# TODO: Check for cyclic dependency

		scatter_parent = val
		_dependency_parent = node
		_dependency_parent.build_completed.connect(rebuild, CONNECT_DEFERRED)


@export_group("Debug", "dbg_")
@export var dbg_disable_thread := false
@export var dbg_color = Color(1, 0.4, 0)
@export var dbg_loading_color = Color(0, 0.4, 1)


var undo_redo # EditorUndoRedoManager - Can't type this, class not available outside the editor

var modifier_stack: ScatterModifierStack:
	set(val):
		if modifier_stack:
			if modifier_stack.value_changed.is_connected(rebuild):
				modifier_stack.value_changed.disconnect(rebuild)
			if modifier_stack.stack_changed.is_connected(rebuild):
				modifier_stack.stack_changed.disconnect(rebuild)
			if modifier_stack.transforms_ready.is_connected(_on_transforms_ready):
				modifier_stack.transforms_ready.disconnect(_on_transforms_ready)

		modifier_stack = val.get_copy() # Enfore uniqueness
		modifier_stack.value_changed.connect(rebuild, CONNECT_DEFERRED)
		modifier_stack.stack_changed.connect(rebuild, CONNECT_DEFERRED)
		modifier_stack.transforms_ready.connect(_on_transforms_ready, CONNECT_DEFERRED)

var domain: ScatterDomain:
	set(_val):
		domain = ScatterDomain.new() # Enforce uniqueness

var items: Array = []
var total_item_proportion: int
var output_root: Marker2D
var transforms: ScatterTransformList
var editor_plugin # Holds a reference to the EditorPlugin. Used by other parts.
var is_ready := false
var build_version := 0

# Internal variables
var _thread: Thread
var _rebuild_queued := false
var _dependency_parent
var _body_rid: RID
var _collision_shapes: Array[RID]
var _ignore_transform_notification = false

var _drawing_color: Color
var _light_color: Color
var _curves: Array[Curve2D]


func _ready() -> void:
	if Engine.is_editor_hint() or enable_updates_in_game:
		set_notify_transform(true)
		child_exiting_tree.connect(_on_child_exiting_tree)

	_perform_sanity_check()
	_discover_items()
	update_configuration_warnings.call_deferred()
	is_ready = true

	if force_rebuild_on_load and not is_instance_valid(_dependency_parent):
		full_rebuild.call_deferred()


func _process(_delta: float) -> void:
	queue_redraw()


func _exit_tree():
	if is_thread_running():
		modifier_stack.stop_update()
		_thread.wait_to_finish()
		_thread = null

	_clear_collision_data()


func _get_property_list() -> Array:
	var list := []
	list.push_back({
		name = "modifier_stack",
		type = TYPE_OBJECT,
		hint_string = "ModifierStack",
	})
	return list


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if items.is_empty():
		warnings.push_back("At least one ScatterItem node is required.")

	if modifier_stack and not modifier_stack.does_not_require_shapes():
		if domain and domain.is_empty():
			warnings.push_back("At least one ScatterShape node is required.")

	return warnings


func _notification(what):
	if not is_ready:
		return
	match what:
		NOTIFICATION_TRANSFORM_CHANGED:
			if _ignore_transform_notification:
				_ignore_transform_notification = false
				return
			_perform_sanity_check()
			domain.compute_bounds()
			rebuild.call_deferred()
		NOTIFICATION_ENTER_TREE:
			_ignore_transform_notification = true


func _set(property, value):
	if not Engine.is_editor_hint():
		return false

	# Workaround to detect when the node was duplicated from the editor.
	if property == "transform":
		_on_node_duplicated.call_deferred()

	# Backward compatibility.
	# Convert the value of previous property "use_instancing" into the proper render_mode.
	elif property == "use_instancing":
		render_mode = 0 if value else 1
		return true

	return false


func _get(_property):
	#if property == "Performance/use_chunks":
		#return use_chunks
#
	#elif property == "Performance/chunk_dimensions":
		#return chunk_dimensions
	pass


func is_thread_running() -> bool:
	return _thread != null and _thread.is_started()


# Deletes what the Scatter node generated.
func clear_output() -> void:
	if not output_root:
		output_root = get_node_or_null("ScatterOutput")

	if output_root:
		remove_child(output_root)
		output_root.queue_free()
		output_root = null

	ScatterUtils.ensure_output_root_exists(self)
	_clear_collision_data()


func _clear_collision_data() -> void:
	if _body_rid.is_valid():
		PhysicsServer2D.free_rid(_body_rid)
		_body_rid = RID()

	for rid in _collision_shapes:
		if rid.is_valid():
			PhysicsServer2D.free_rid(rid)

	_collision_shapes.clear()


# Wrapper around the _rebuild function. Clears previous output and force
# a clean rebuild.
func full_rebuild():

	if not is_inside_tree():
		return

	_rebuild_queued = false

	if is_thread_running():
		await _thread.wait_to_finish()
		_thread = null

	clear_output()
	_rebuild(true)


# A wrapper around the _rebuild function. Ensure it's not called more than once
# per frame. (Happens when the Scatter node is moved, which triggers the
# TRANSFORM_CHANGED notification in every children, which in turn notify the
# parent Scatter node back about the changes).
func rebuild(force_discover := false) -> void:

	if not is_inside_tree() or not is_ready:
		return

	if is_thread_running():
		_rebuild_queued = true
		return

	force_discover = true # TMP while we fix the other issues
	_rebuild(force_discover)


# Re compute the desired output.
# This is the main function, scattering the objects in the scene.
# Scattered objects are stored under a Marker2D node called "ScatterOutput"
# DON'T call this function directly outside of the 'rebuild()' function above.
func _rebuild(force_discover) -> void:
	if not enabled:
		_clear_collision_data()
		clear_output()
		build_completed.emit()
		return

	_perform_sanity_check()

	if force_discover:
		_discover_items()
		domain.discover_shapes(self)


	if items.is_empty() or (domain.is_empty() and not modifier_stack.does_not_require_shapes()):
		clear_output()
		push_warning("Scatter warning: No items or shapes, abort")
		return

	if render_mode == 1:
		clear_output() # TMP, prevents raycasts in modifier to self intersect with previous output

	if keep_static_colliders:
		_clear_collision_data()

	if dbg_disable_thread:
		modifier_stack.start_update(self, domain)
		return

	if is_thread_running():
		await _thread.wait_to_finish()

	_thread = Thread.new()
	_thread.start(_rebuild_threaded, Thread.PRIORITY_NORMAL)


func _rebuild_threaded() -> void:
	# Disable thread safety, but only after 4.1 beta 3
	if _thread.has_method("set_thread_safety_checks_enabled"):
		# Calls static method on instance, otherwise it crashes in 4.0.x
		@warning_ignore("static_called_on_instance")
		_thread.set_thread_safety_checks_enabled(false)

	modifier_stack.start_update(self, domain.get_copy())


func _discover_items() -> void:
	items.clear()
	total_item_proportion = 0

	for c in get_children():
		if is_instance_of(c, ScatterItem):
			items.push_back(c)
			total_item_proportion += c.proportion

	update_configuration_warnings()


# Creates one MultimeshInstance2D for each ScatterItem node.
func _update_multimeshes() -> void:
	if items.is_empty():
		_discover_items()

	var offset := 0
	var transforms_count: int = transforms.size()

	for item in items:
		var count = int(round(float(item.proportion) / total_item_proportion * transforms_count))
		var mmi = ScatterUtils.get_or_create_multimesh(item, count)
		if not mmi:
			continue
		var static_body := ScatterUtils.get_collision_data(item)

		var t: Transform2D
		for i in range(count):
			# Extra check because of how 'count' is calculated
			if (offset + i) >= transforms_count:
				mmi.multimesh.instance_count = i - 1
				continue

			t = item.process_transform(transforms.list[offset + i])
			mmi.multimesh.set_instance_transform_2d(i, t)
			_create_collision(static_body, t)

		if enable_y_sorting:
			_sort_multimesh_by_y(mmi.multimesh)

		static_body.queue_free()
		offset += count



func _update_duplicates() -> void:
	var offset := 0
	var transforms_count: int = transforms.size()

	for item in items:
		var count := int(round(float(item.proportion) / total_item_proportion * transforms_count))
		var root: Node2D = ScatterUtils.get_or_create_item_root(item)
		var child_count := root.get_child_count()

		for i in range(count):
			if (offset + i) >= transforms_count:
				return

			var instance
			if i < child_count: # Grab an instance from the pool if there's one available
				instance = root.get_child(i)
			else:
				instance = _create_instance(item, root)

			if not instance:
				break

			var t: Transform2D = item.process_transform(transforms.list[offset + i])
			instance.transform = t
			#ScatterUtils.set_visibility_layers(instance, item.visibility_layers)

		# Delete the unused instances left in the pool if any
		if count < child_count:
			for i in (child_count - count):
				root.get_child(-1).queue_free()

		offset += count


func _update_particles_system() -> void:
	var offset := 0
	var transforms_count: int = transforms.size()

	for item in items:
		var count := int(round(float(item.proportion) / total_item_proportion * transforms_count))
		var particles = ScatterUtils.get_or_create_particles(item)
		if not particles:
			continue

		particles.visibility_rect = Rect2(domain.bounds_local.min, domain.bounds_local.size)
		particles.amount = count

		var static_body := ScatterUtils.get_collision_data(item)
		var t: Transform2D

		for i in count:
			if (offset + i) >= transforms_count:
				particles.amount = i - 1
				return

			t = item.process_transform(transforms.list[offset + i])
			particles.emit_particle(
				t,
				Vector2.ZERO,
				Color.WHITE,
				Color.BLACK,
				GPUParticles2D.EMIT_FLAG_POSITION | GPUParticles2D.EMIT_FLAG_ROTATION_SCALE)
			_create_collision(static_body, t)

		offset += count


# Creates collision data with the Physics server directly.
# This does not create new nodes in the scene tree. This also means you can't
# see these colliders, even when enabling "Debug > Visible collision shapes".
func _create_collision(body: StaticBody2D, t: Transform2D) -> void:

	if not keep_static_colliders or render_mode == 1:
		return

	# Create a static body
	if not _body_rid.is_valid():
		_body_rid = PhysicsServer2D.body_create()
		PhysicsServer2D.body_set_mode(_body_rid, PhysicsServer2D.BODY_MODE_STATIC)
		PhysicsServer2D.body_set_state(_body_rid, PhysicsServer2D.BODY_STATE_TRANSFORM, global_transform)
		PhysicsServer2D.body_set_space(_body_rid, get_world_2d().space)

	for c in body.get_children():
		if c is CollisionShape2D:
			var shape_rid: RID
			var data: Variant

			if c.shape is CircleShape2D:
				shape_rid = PhysicsServer2D.circle_shape_create()
				data = c.shape.radius

			elif c.shape is RectangleShape2D:
				shape_rid = PhysicsServer2D.rectangle_shape_create()
				data = c.shape.size / 2.0

			elif c.shape is CapsuleShape2D:
				shape_rid = PhysicsServer2D.capsule_shape_create()
				data = {
					"radius": c.shape.radius,
					"height": c.shape.height,
				}

			elif c.shape is ConcavePolygonShape2D:
				shape_rid = PhysicsServer2D.concave_polygon_shape_create()
				data = {
					"faces": c.shape.get_faces(),
					"backface_collision": c.shape.backface_collision,
				}

			elif c.shape is ConvexPolygonShape2D:
				shape_rid = PhysicsServer2D.convex_polygon_shape_create()
				data = c.shape.points

			elif c.shape is SeparationRayShape2D:
				shape_rid = PhysicsServer2D.separation_ray_shape_create()
				data = {
					"length": c.shape.length,
					"slide_on_slope": c.shape.slide_on_slope,
				}

			else:
				print_debug("Scatter - Unsupported collision shape: ", c.shape)
				continue

			PhysicsServer2D.shape_set_data(shape_rid, data)
			PhysicsServer2D.body_add_shape(_body_rid, shape_rid, t * c.transform)
			_collision_shapes.push_back(shape_rid)


func _create_instance(item: ScatterItem, root: Node2D):
	if not item:
		return null

	var instance = item.get_item()
	if not instance:
		return null

	instance.visible = true
	root.add_child.bind(instance, true).call_deferred()

	if show_output_in_tree:
		# We have to use a lambda here because ScatterUtils isn't an
		# actual class_name, it's a const, which makes it impossible to reference
		# the callable, (but we can still call it)
		var defer_ownership := func(i, o):
			ScatterUtils.set_owner_recursive(i, o)
		defer_ownership.bind(instance, get_tree().get_edited_scene_root()).call_deferred()

	return instance


# Enforce the Scatter node has its required variables set.
func _perform_sanity_check() -> void:
	if not modifier_stack:
		modifier_stack = ScatterModifierStack.new()
		modifier_stack.just_created = true

	if not domain:
		domain = ScatterDomain.new()

	domain.discover_shapes(self)

	# Retrigger the parent setter, in case the parent node no longer exists or changed type.
	scatter_parent = scatter_parent


# Remove output coming from the source node to avoid linked multimeshes or
# other unwanted side effects
func _on_node_duplicated() -> void:
	clear_output()


func _on_child_exiting_tree(node: Node) -> void:
	if node is ScatterShape or node is ScatterItem:
		rebuild.bind(true).call_deferred()


# Called when the modifier stack is done generating the full transform list
func _on_transforms_ready(new_transforms: ScatterTransformList) -> void:
	if is_thread_running():
		await _thread.wait_to_finish()
		_thread = null

	_clear_collision_data()

	if _rebuild_queued:
		_rebuild_queued = false
		rebuild.call_deferred()
		return

	transforms = new_transforms

	if not transforms or transforms.is_empty():
		clear_output()
		return

	match render_mode:
		0:	_update_multimeshes()
		1:	_update_duplicates()
		2:	_update_particles_system()

	build_version += 1

	if is_inside_tree():
		await get_tree().process_frame

	build_completed.emit()


func _sort_multimesh_by_y(multimesh: MultiMesh):
	var trans := []
	var instance_count := multimesh.instance_count

	for i in range(instance_count):
		trans.append(multimesh.get_instance_transform_2d(i))

	# sort tansforms by y coord
	trans.sort_custom( func(a, b): return a.origin.y < b.origin.y )

	# update transforms
	for i in range(instance_count):
		multimesh.set_instance_transform_2d(i, trans[i])


func _draw():
	if not Engine.is_editor_hint():
		return

	if not _is_selected(self):
		return

	_update_colors(dbg_color)

	if modifier_stack:
		if is_thread_running():
			_update_colors(dbg_loading_color)

		_curves.clear()
		_curves = domain.get_edges()

		for curve in _curves:
			var points := curve.tessellate(4, 8)
			draw_colored_polygon(points, _light_color)
			draw_polyline(points, _drawing_color, 2, true)


func _is_selected(node: Node) -> bool:
	var editor_selection = Engine.get_singleton(&"EditorInterface").get_selection()
	return node in editor_selection.get_selected_nodes()


func _update_colors(base_color:Color):
	_drawing_color = base_color
	_light_color = base_color
	_light_color.a /= 4
