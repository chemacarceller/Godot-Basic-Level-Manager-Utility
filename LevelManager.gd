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

# Function that receives notifications
func _notification(what) : 
	# When a game closure is requested
	if what == NOTIFICATION_WM_CLOSE_REQUEST : 
		MyLogger.info("FRAME : " + str(Engine.get_process_frames()) + " : " + "Exiting LevelManager ...", 'LevelManager.gd', 18, true)

# It does nothing
func _exit_tree() -> void : pass

# Function that executes first when the node is added to the scene
func _enter_tree() -> void : 
	
	# Check if the mandatory MyLogger exists
	if has_node("/root/MyLogger") or is_instance_valid(Engine.get_singleton("MyLogger")) :
		
		var _target = get_node("/root/MyLogger") if has_node("/root/MyLogger") else Engine.get_singleton("MyLogger")
		if _target.has_method("info") and _target.has_method("warn") and _target.has_method("error") :
			MyLogger.info("FRAME : " + str(Engine.get_process_frames()) + " : " + name + " Checked the success of MyLogger existence ... ","LevelManager.gd",31, true)
		else : 
			print("FRAME : " + str(Engine.get_process_frames()) + " : " + "Error: The C++ class MyLogger does not have the appropriate methods")
			
			# Close the game completely and make sure the script stops running immediately at that point.
			get_tree().quit()
	else :

		print("FRAME : " + str(Engine.get_process_frames()) + " : " + "Error: The C++ class MyLogger is not registered")
		
		# Close the game completely and make sure the script stops running immediately at that point.
		get_tree().quit()

	MyLogger.info("FRAME : " + str(Engine.get_process_frames()) + " : " + name + " Instantiated ... ","levelManager.gd",44, true)


# Function that executes second when the node is added to the scene
func _ready() -> void :

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
		
		MyLogger.error("FRAME : " + str(Engine.get_process_frames()) + " : " + error_msg, 'LevelManager.gd', 64, true)

		# Completely disable the _process(delta) method on the node where you execute it
		set_process(false) 

		# Close the game completely and make sure the script stops running immediately at that point.
		get_tree().quit()

	MyLogger.info("FRAME : " + str(Engine.get_process_frames()) + " : " + name + str(required_globals) + "  available ... ","levelManager.gd",72, true)

	# I need to know what the initial scene is once is ready
	await _initialize_initial_level()

	MyLogger.info("FRAME : " + str(Engine.get_process_frames()) + " : " + name + " Ready ... ","levelManager.gd",77, true)


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

				if not theNode.is_node_ready() : await theNode.ready

				# Setting the actual level taken from the projet settings
				if actual_level == null : actual_level = get_tree().current_scene

				await get_tree().process_frame

				MyLogger.info("FRAME : " + str(Engine.get_process_frames()) + " : " + " Set the First Level Loaded as " + str(actual_level),"LevelManager.gd",107, true)

				MyLogger.info("FRAME : " + str(Engine.get_process_frames()) + " : " + " Unhandled Input enabled " + str(actual_level),"LevelManager.gd",109, true)

				GameInstance.is_ready_to_unhandled_input = true

				return



# Public function called each time a level changed is requested

# Indicates that the scene change process has begun, preventing it from being launched twice in a row
var _is_loading : bool = false

# AutoLoad function to be called when we need to switch scenes (levels)
func load_new_level(scene_path: String):

	# While a scene change is in progress, another scene change cannot be requested.
	if _is_loading : return
	else : _is_loading = true

	# Disable key presses until the level is 100% loaded.
	MyLogger.info("FRAME : " + str(Engine.get_process_frames()) + " : " + " Unhandled Input disabled " + str(actual_level),"LevelManager.gd",130, true)
	GameInstance.is_ready_to_unhandled_input = false

	# The scene is checked before attempting to load it.
	if not ResourceLoader.exists(scene_path) : _handle_fatal_error("Level not found : " + scene_path)

	# Start loading this resource in a separate processing thread (in the background) so that the game does not freeze while the disc is being read
	ResourceLoader.load_threaded_request(scene_path, "", true)
	
	var progress = []
	var status = 0

	while status != ResourceLoader.THREAD_LOAD_LOADED :

		status = ResourceLoader.load_threaded_get_status(scene_path, progress)

		if status == ResourceLoader.THREAD_LOAD_FAILED : _handle_fatal_error("Error loading resource in thread : " + scene_path)

		await get_tree().process_frame

	# Once the scena is loaded we create the node and hide
	var scene_resource = ResourceLoader.load_threaded_get(scene_path)
	var next_level = scene_resource.instantiate()
	next_level.visible = false
	MyLogger.info("FRAME : " + str(Engine.get_process_frames()) + " : " + str(next_level) + "  instantiated but hidden ... ","levelManager.gd",154, true)

	if actual_level and actual_level.name == next_level.name :

		MyLogger.warn("FRAME : " + str(Engine.get_process_frames()) + " : " + "Attempted to load the same level: " + next_level.name, 'LevelManager.gd', 158, true)

		next_level.free()
		_is_loading = false
		return

	# The prefabs are added to the new scene so they can be preloaded onto the GPU.
	_warmup_prefabs(next_level)

	# The scene change takes place; the prefabs are removed from the scene
	# Prefabs are objects that are not in the scene but can be spawned
	_switch_scene(next_level)

	# We wait until the scene is 100% loaded.
	# Same procedure applied at game startup for loading the default scene
	while true :

		for theNode in get_tree().root.get_children() :
			
			# We wait for the scene node to be ready
			if theNode.name == actual_level.name :
				
				if not theNode.is_node_ready() : await theNode.ready

				await get_tree().process_frame

				MyLogger.info("FRAME : " + str(Engine.get_process_frames()) + " : " + "Finished GPU Warmup for prefabs removed from scene...", "LevelManager.gd", 184, true)

				MyLogger.info("FRAME : " + str(Engine.get_process_frames()) + " : " + "Level changed successfully: " + next_level.name, 'LevelManager.gd', 186, true)

				actual_level.visible = true
				MyLogger.info("FRAME : " + str(Engine.get_process_frames()) + " : " + str(actual_level) + " is now visble : ","LevelManager.gd",189, true)

				# We indicate that the scene change process has ended and another scene change may occur.
				MyLogger.info("FRAME : " + str(Engine.get_process_frames()) + " : " + " Another scene change may occur : ","LevelManager.gd",192, true)
				_is_loading = false

				# Here we can re-enable keyboard order entry.
				MyLogger.info("FRAME : " + str(Engine.get_process_frames()) + " : " + " Unhandled Input enabled " + str(actual_level),"LevelManager.gd",196, true)
				GameInstance.is_ready_to_unhandled_input = true

				return


# Fuction to handle fatal errors, log them, and quit the game gracefully if possible
func _handle_fatal_error(error_message: String) :
	
	MyLogger.error("FRAME : " + str(Engine.get_process_frames()) + " : " + error_message, 'LevelManager.gd', 205, true)
	
	if GameInstance._quit_gracefully : GameInstance._quit_gracefully()
	else : get_tree().quit()


# This function adds the GameInstance._prefabs objects to the scene
func _warmup_prefabs(target_node: Node) :

	MyLogger.info("FRAME : " + str(Engine.get_process_frames()) + " : " + "Starting GPU Warmup for prefabs...", "LevelManager.gd", 214, true)

	if GameInstance._prefabs :

		for key in GameInstance._prefabs :

			var prefab = GameInstance._prefabs[key]
			if is_instance_valid(prefab) :
				if prefab.get_parent(): prefab.reparent(target_node)
				else: target_node.add_child(prefab)


# This function is used to switch the current scene to the new level, and remove the old level from the scene tree
func _switch_scene(next_level: Node3D) :

	MyLogger.info("FRAME : " + str(Engine.get_process_frames()) + " : " + "EventBus has been reset... ", "LevelManager.gd", 229, true)	

	# From the event manager, all references to the previous level must be removed
	EventBus._reset()

	# The prefabs are removed from the new scene
	# Prefabs should be objects that were not in the scene
	# but objects that could spawn in it already preheated in the GPU
	if GameInstance._prefabs :
		for key in GameInstance._prefabs :

			var prefab = GameInstance._prefabs[key]
			if is_instance_valid(prefab) and prefab.get_parent() : 
				prefab.get_parent().remove_child(prefab)

	# Add new level to root
	MyLogger.info("FRAME : " + str(Engine.get_process_frames()) + " : " + "Adding the new level : " + next_level.name, 'LevelManager.gd', 245, true)
	get_tree().root.add_child(next_level)
	get_tree().current_scene = next_level

	# Release old level
	if is_instance_valid(actual_level) : actual_level.queue_free()
	actual_level = next_level
