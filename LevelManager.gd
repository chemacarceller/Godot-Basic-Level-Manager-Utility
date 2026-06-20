extends Node
# This class is used for changing the game scene (level)
# This class mandatorily uses a Global Object called MyLogger, which must provide the methods info(), warn(), and error() to manage log storage
# This class would also serve to check that MyLogger ( C++ Singleton or Autoload ) is available 
# and make it mandatory for the project as well as the existence of the methods mentioned, and if these conditions are not met, the game will close immediately.
# The GameInstance Autoload is checked for its existence,  
# implementing the GameInstance._quit_gracefully() method for controlled application closure rather than an uncontrolled closure
# and storing the prefabs to make a GPU warmup of them
# The EventBus Autoload is also checked for its existence reseting it on scene change

# Indicates the current scene we are in - in the _ready method it is got the default level
var actual_level : Node3D = null

# Indicates that the scene change process has begun
var _is_loading : bool = false

func _enter_tree() -> void : 
	if has_node("/root/MyLogger") or is_instance_valid(Engine.get_singleton("MyLogger")):
		var _target = get_node("/root/MyLogger") if has_node("/root/MyLogger") else Engine.get_singleton("MyLogger")
		if _target.has_method("info") and _target.has_method("warn") and _target.has_method("error") :
			MyLogger.info(name + " Instantiated ... ","levelManager.gd",21, true)
			MyLogger.info(name + " Checked the success of MyLogger existence ... ","levelManager.gd",22, true)
		else : 
			print("Error: The C++ class MyLogger does not have the appropriate methods")
			# Close the game completely and make sure the script stops running immediately at that point.
			get_tree().quit()
			return
	else:
		print("Error: The C++ class MyLogger is not registered")
		# Close the game completely and make sure the script stops running immediately at that point.
		get_tree().quit()
		return

func _ready() -> void :

	MyLogger.info(name + " Ready ... ","levelManager.gd",36, true)

	# List of required singletons
	var required_globals = ["GameInstance","EventBus"]
	var missing_globals = []
	
	# We checked that all the necessary global classes are actually available
	for global_name in required_globals : 
		if not is_instance_valid(get_node_or_null("/root/" + global_name)) : 
			missing_globals.append(global_name)

	# If anyone is missing, we abort the mission
	if missing_globals.size() > 0 :

		var error_msg = "CRITICAL ERROR: Missing Autoloads : " + str(missing_globals)
		
		MyLogger.error(error_msg, 'LevelManager.gd', 43, true)

		# Completely disable the _process(delta) method on the node where you execute it
		set_process(false) 

		# Close the game completely and make sure the script stops running immediately at that point.
		get_tree().quit()
		return

	MyLogger.info(name + str(required_globals) + "  available ... ","levelManager.gd",59, true)

	# If everything is correct, let's begin
	# I need to know what the initial scene (the node) is, for this this method is launched
	_initialize_initial_level()

# Private function to initialize the first level of the game, which is set in the project settings
# Only called once in the _ready method 
func _initialize_initial_level() -> void :
	
	# The LevelManager must wait until the scene set as the default scene is ready 
	# to set as the default actual_level
	
	# Looking for the node to wait until is ready
	var path : String = ResourceUID.get_id_path(ResourceUID.text_to_id(ProjectSettings.get_setting("application/run/main_scene")))
	var resource_scene : PackedScene = load(path) as PackedScene
	var scene_state : SceneState = resource_scene.get_state()
	var node_name : String = scene_state.get_node_name(0)
	
	while true :
		for theNode in get_tree().root.get_children() :
			# We wait for the scene node to be ready
			if theNode.name == node_name :
				if not theNode.is_node_ready() :
					await theNode.ready

				# Setting the actual level taken from the projet settings
				if actual_level == null : actual_level = get_tree().current_scene

				MyLogger.info(" Set the First Level Loaded as " + str(actual_level),"LevelManager.gd",68, true)

				return
		await get_tree().process_frame



# Public function called each time a level changed is requested
func load_new_level(scene_path: String):

	# While a scene change is in progress, another scene change cannot be requested.
	if _is_loading : return
	else : _is_loading = true

	# The scene is checked before attempting to load it.
	if not ResourceLoader.exists(scene_path) : 
		_handle_fatal_error("Level not found : " + scene_path)
		return

	# Start loading this resource in a separate processing thread (in the background) so that the game does not freeze while the disc is being read
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
	MyLogger.info(str(next_level) + "  instantiated but hidden ... ","levelManager.gd",127, true)

	if actual_level and actual_level.name == next_level.name :
		MyLogger.warn("Attempted to load the same level: " + next_level.name, 'LevelManager.gd', 141, true)

		next_level.free()
		_is_loading = false
		return

	# The prefabs are added to the new scene so they can be preloaded onto the GPU.
	_warmup_prefabs(next_level)
	
	# The scene change takes place; the prefabs are removed from the scene
	# Prefabs are objects that are not in the scene but can be spawned
	_switch_scene(next_level)

	actual_level.visible = true
	MyLogger.info(str(next_level) + " is now visble : ","LevelManager.gd",68, true)

	# We indicate that the scene change process has ended and another scene change may occur.
	_is_loading = false


# Fuction to handle fatal errors, log them, and quit the game gracefully if possible
func _handle_fatal_error(error_message: String):
	MyLogger.error(error_message, 'LevelManager.gd', 86, true)
	if GameInstance._quit_gracefully : GameInstance._quit_gracefully()
	else : get_tree().quit()


# This function adds the GameInstance._prefabs objects to the scene
func _warmup_prefabs(target_node: Node):
	MyLogger.info("Starting GPU Warmup for prefabs...", "LevelManager.gd", 156, true)
	if GameInstance._prefabs :
		for key in GameInstance._prefabs:
			var prefab = GameInstance._prefabs[key]
			if is_instance_valid(prefab) :
				if prefab.get_parent(): prefab.reparent(target_node)
				else: target_node.add_child(prefab)


# This function is used to switch the current scene to the new level, and remove the old level from the scene tree
func _switch_scene(next_level: Node3D) :

	MyLogger.info("EventBus has been reset... ", "LevelManager.gd", 168, true)	

	# From the event manager, all references to the previous level must be removed
	EventBus._reset()

	# The prefabs are removed from the new scene
	# Prefabs should be objects that were not in the scene
	# but objects that could spawn in it already preheated in the GPU
	MyLogger.info("Finishing GPU Warmup for prefabs removed from scene...", "LevelManager.gd", 176, true)
	if GameInstance._prefabs :
		for key in GameInstance._prefabs:
			var prefab = GameInstance._prefabs[key]
			if is_instance_valid(prefab) and prefab.get_parent() : 
				prefab.get_parent().remove_child(prefab)

	# Add new level to root
	MyLogger.info("Adding the new level : " + next_level.name, 'LevelManager.gd', 186, true)
	get_tree().root.add_child(next_level)
	get_tree().current_scene = next_level

	# Release old level
	if is_instance_valid(actual_level) : actual_level.queue_free()
	actual_level = next_level

	MyLogger.info("Level changed successfully: " + next_level.name, 'LevelManager.gd', 194, true)


# This function is called when the application is closed, and it logs the event
func _notification(what) : 
	if what == NOTIFICATION_WM_CLOSE_REQUEST : 
		MyLogger.info("Exiting LevelManager ...", 'LevelManager.gd', 173, true)
