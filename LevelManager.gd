extends Node

var actual_level : Node3D = null

func load_new_level(scene_path: String):
	
	if (ResourceLoader.exists(scene_path)) :
		
		# The first time we change the level there is no reference to the current_scene
		if actual_level == null : actual_level = get_tree().current_scene
		
		for child in actual_level.get_children():
			# 'notification' sends the message ONLY to this specific node without going down to its own children.
			MyLogger.info("Changing Level from " + str(actual_level) + ": Notification sent only to :" + child.name,'level_manager.gd', 14, true)
			child.notification(NOTIFICATION_WM_CLOSE_REQUEST)

		# awaiting to the next frame so that the notifications sent are processed
		await get_tree().process_frame

		# free the actual_level
		actual_level.free()

		# From the event manager, all references to the previous level must be removed.
		EventBus._reset()

		# Setting the new actual_level
		var scene_resource = load(scene_path)
		actual_level = scene_resource.instantiate()
		add_child(actual_level)

		# Showing the hud messages
		GameInstance._on_timer_timeout(false)

		MyLogger.info("The actual level is : " + str(actual_level),'level_manager.gd',34, true)
	else :
		MyLogger.error("The actual level : " + str(actual_level) + " cannot be loaded",'level_manager.gd',36, true)


# How to handle a save quiting in the LevelManager
func _notification(what) :
	
	if what == NOTIFICATION_WM_CLOSE_REQUEST :

		MyLogger.info("Exiting LevelManager ...", 'LevelManager.gd', 40, true)
		for child in actual_level.get_children():
			# 'notification' sends the message ONLY to this specific node without going down to its own children.
			MyLogger.info("Exiting LevelManager ... " + str(actual_level) + " : Notification sent only to :" + child.name,'level_manager.gd', 47, true)
			child.notification(NOTIFICATION_WM_CLOSE_REQUEST)

		# awaiting to the next frame so that the notifications sent are processed
		await get_tree().process_frame

		actual_level.queue_free()
