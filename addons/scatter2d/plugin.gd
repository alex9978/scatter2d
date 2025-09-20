@tool
extends EditorPlugin


const ModifierStackPlugin := preload("./src/stack/inspector_plugin/modifier_stack_plugin.gd")
const ScatterCachePlugin := preload("./src/cache/inspector_plugin/scatter_cache_plugin.gd")

const MAX_PHYSICS_QUERIES_SETTING := "addons/scatter2d/max_physics_queries_per_frame"

var _modifier_stack_plugin := ModifierStackPlugin.new()
var _selected_scatter_group: Array[Node] = []
var _scatter_cache_plugin := ScatterCachePlugin.new()


func _get_plugin_name():
	return "Scatter2D"


func _enter_tree() -> void:
	_ensure_setting_exists(MAX_PHYSICS_QUERIES_SETTING, 500)

	add_inspector_plugin(_modifier_stack_plugin)
	add_inspector_plugin(_scatter_cache_plugin)
	add_custom_type("Scatter2D", "Node2D", preload("src/scatter2d.gd"), preload("icons/scatter.svg"))
	add_custom_type("ScatterItem", "Node2D", preload("src/scatter_item.gd"), preload("icons/item.svg"))
	add_custom_type("ScatterShape", "Node2D", preload("src/scatter_shape.gd"), preload("icons/shape.svg"))
	add_custom_type("ScatterCache",	"Node2D", preload("src/cache/scatter_cache.gd"), preload("./icons/cache.svg"))

	var editor_selection = EditorInterface.get_selection()
	editor_selection.selection_changed.connect(_on_selection_changed)
	scene_changed.connect(_on_scene_changed)


func _exit_tree() -> void:
	remove_custom_type("Scatter2D")
	remove_custom_type("ScatterItem")
	remove_custom_type("ScatterShape")
	remove_custom_type("ScatterCache")
	remove_inspector_plugin(_modifier_stack_plugin)
	remove_inspector_plugin(_scatter_cache_plugin)


func _handles(node) -> bool:
	return node is ScatterShape


func _ensure_setting_exists(setting: String, default_value) -> void:
	if not ProjectSettings.has_setting(setting):
		ProjectSettings.set_setting(setting, default_value)
		ProjectSettings.set_initial_value(setting, default_value)

		if ProjectSettings.has_method("set_as_basic"): # 4.0 backward compatibility
			ProjectSettings.call("set_as_basic", setting, true)


func _on_selection_changed() -> void:
	# Clean the gizmos on the previous node selection
	#_refresh_scatter_gizmos(_selected_scatter_group)
	_selected_scatter_group.clear()

	# Get the currently selected nodes
	var selected = EditorInterface.get_selection().get_selected_nodes()
	#_path_panel.selection_changed(selected)

	if selected.is_empty():
		return

	# Update the selected local scatter group.
	# If the user selects a shape, the scatter group will contain the ScatterShape,
	# all the sibling shapes, and the parent scatter node, even if they are not
	# selected. This is required to make their gizmos appear.
	for node in selected:
		var scatter_node

		if node is Scatter2D:
			scatter_node = node

		elif node is ScatterShape and is_instance_valid(node):
			scatter_node = node.get_parent()

		if not is_instance_valid(scatter_node):
			continue

		_selected_scatter_group.push_back(scatter_node)
		scatter_node.undo_redo = get_undo_redo()
		scatter_node.editor_plugin = self

		for c in scatter_node.get_children():
			if c is ScatterShape:
				_selected_scatter_group.push_back(c)


func _on_scene_changed(_scene_root) -> void:
	pass
