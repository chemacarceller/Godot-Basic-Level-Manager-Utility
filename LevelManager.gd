extends Node

var actual_level : Node3D = null

func _ready() -> void :
	MyLogger.info(name + " Instantiated ... ","levelManager.gd",6, true)
	
	# We wait for the next frame for the current scene to be loaded
	await get_tree().process_frame

	# Setting the actual level taken from the projet settings
	if actual_level == null : actual_level = get_tree().current_scene

# Each time a level changed is requested
func load_new_level(scene_path: String):

	if (ResourceLoader.exists(scene_path)) :
		# Setting the actual level
		if actual_level == null : actual_level = get_tree().current_scene

		# Instantiating the next level
		var scene_resource = load(scene_path)
		var next_level = scene_resource.instantiate()

		# To prevent switching to the same level, the name is checked because otherwise a new level with the same name would be created.
		# Each time we enter the trigger, it fires several times while the level loads; only the first time should the level change.
		if actual_level.name != next_level.name :

			MyLogger.info("Changing Level from " + str(actual_level) + " to : " + str(next_level),'level_manager.gd', 19, true)

			# free the actual_level
			if actual_level.is_inside_tree() : actual_level.queue_free()
			else : actual_level.free()

			# From the event manager, all references to the previous level must be removed.
			EventBus._reset()

			# Setting the new actual_level
			actual_level = next_level

			get_tree().root.add_child(actual_level)

			# Showing the hud messages
			GameInstance._on_timer_timeout(false)

			MyLogger.info("The actual level is ready : " + str(actual_level),'level_manager.gd',34, true)
			
		else :
			MyLogger.warn("An attempt has been made to change to the same level : " + str(actual_level),'level_manager.gd',43, true)
			next_level.free()
	else :
		MyLogger.error("[" + scene_path + "] doesnt exist, cannot be changed to it",'level_manager.gd',38, true)
		get_tree().quit(3)


# How to handle a save quiting in the LevelManager
func _notification(what) : 
	if what == NOTIFICATION_WM_CLOSE_REQUEST : 
		MyLogger.info("Exiting LevelManager ...", 'LevelManager.gd', 40, true)
		actual_level.queue_free()
