extends Node

var actual_level : Node3D = null

func _ready() -> void :

	MyLogger.info(name + " Instantiated ... ","levelManager.gd",6, true)
	_initialize_initial_level()

func _initialize_initial_level() -> void:
	
	# The LevelManager must wait until the LoadingScreen or or the scene set as the default scene is ready to set as the default actual_level
	var exiting : bool = false
	# Looking for the node to wait until is ready
	var path : String = ResourceUID.get_id_path(ResourceUID.text_to_id(ProjectSettings.get_setting("application/run/main_scene")))
	var resource_scene : PackedScene = load(path) as PackedScene
	var scene_state = resource_scene.get_state()
	var node_name = scene_state.get_node_name(0)
	
	while not exiting :
		for theNode in get_tree().root.get_children() :

			# If there is no LoadingScreen used, the characters must be loaded in GameInstance
			# And the timer must be started
			if node_name != 'LoadingScreen' :
				GameInstance.load_characters()
				GameInstance.start_game_timer()

			# We wait for the scene node to be ready
			if theNode.name == node_name :
				if not theNode.is_node_ready() :
					await theNode.ready
					exiting = true
					break
		if not exiting: await get_tree().process_frame

	# Setting the actual level taken from the projet settings
	if actual_level == null : actual_level = get_tree().current_scene

var _is_loading : bool = false

func _handle_fatal_error(path: String):
	MyLogger.error("Level not found: " + path, 'LevelManager.gd')
	GameInstance._quit_gracefully()
	for i in 60 : await get_tree().process_frame
	get_tree().quit(3)

func _warmup_prefabs(target_node: Node):
	MyLogger.info("Starting GPU Warmup for prefabs...", "LevelManager.gd")
	for key in GameInstance._prefabs:
		var prefab = GameInstance._prefabs[key]
		if is_instance_valid(prefab) :
			if prefab.get_parent(): prefab.reparent(target_node)
			else: target_node.add_child(prefab)

func _switch_scene(next_level: Node3D):
	
	# From the event manager, all references to the previous level must be removed.
	EventBus._reset()

	# The prefabs are removed from its parent
	for key in GameInstance._prefabs:
		var prefab = GameInstance._prefabs[key]
		if is_instance_valid(prefab) and prefab.get_parent() : 
			prefab.get_parent().remove_child(prefab)

	# Add new level to root
	get_tree().root.add_child(next_level)
	get_tree().current_scene = next_level

	# Release old level
	if is_instance_valid(actual_level) : actual_level.queue_free()

	actual_level = next_level

	MyLogger.info("Level changed successfully: " + next_level.name, 'LevelManager.gd')


# Each time a level changed is requested
func load_new_level(scene_path: String):

	if _is_loading : return
	else : _is_loading = true

	if not ResourceLoader.exists(scene_path): 
		_handle_fatal_error(scene_path)
		return
	
	ResourceLoader.load_threaded_request(scene_path, "", true)
	
	var progress = []
	var status = 0

	while status != ResourceLoader.THREAD_LOAD_LOADED :

		status = ResourceLoader.load_threaded_get_status(scene_path, progress)

		if status == ResourceLoader.THREAD_LOAD_FAILED:
			_handle_fatal_error("Error loading resource in thread : " + scene_path)
			return

		await get_tree().process_frame

	# Once the scena is loaded we create the node and hide
	var scene_resource = ResourceLoader.load_threaded_get(scene_path)
	var next_level = scene_resource.instantiate()
	next_level.visible = false

	if actual_level and actual_level.name == next_level.name :
		MyLogger.warn("Attempted to load the same level: " + next_level.name, 'LevelManager.gd')
		next_level.free()
		_is_loading = false
		return

	# The prefabs are reparent to the new level
	_warmup_prefabs(next_level)
	_switch_scene(next_level)

	# Showing the hud count message without incrmenting a second
	GameInstance._on_timer_timeout(false)

	_is_loading = false


# How to handle a save quiting in the LevelManager
func _notification(what) : 
	if what == NOTIFICATION_WM_CLOSE_REQUEST : 
		MyLogger.info("Exiting LevelManager ...", 'LevelManager.gd', 40, true)
