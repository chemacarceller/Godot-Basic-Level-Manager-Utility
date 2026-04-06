extends Node

var actual_level: Node = null

func load_new_level(scene_path: String):
	if (ResourceLoader.exists(scene_path)) :
		# The first time we change the level there is no reference to the current_scene
		if actual_level == null : actual_level = get_tree().current_scene
		for child in actual_level.get_children():
			# 'notification' sends the message ONLY to this specific node without going down to its own children.
			MyLogger.info("Changing Level from " + str(actual_level) + ": Notification sent only to :" + child.name,'level_manager.gd', 11, true)
			child.notification(NOTIFICATION_WM_CLOSE_REQUEST)

		# awaiting to the next frame so that the notifications sent are processed
		await get_tree().process_frame

		# queue_free the actual_level
		actual_level.queue_free()

		# From the event manager, all references to the previous level must be removed.
		EventBus._reset()

		# Setting the new actual_level
		var scene_resource = load(scene_path)
		actual_level = scene_resource.instantiate()
		add_child(actual_level)

		# Showing the hud messages
		GameInstance._on_timer_timeout(false)

		MyLogger.info("The actual level is : " + str(actual_level),'level_manager.gd',31)
	else :
		MyLogger.error("The actual level : " + str(actual_level) + " cannot be loaded",'level_manager.gd',33)
