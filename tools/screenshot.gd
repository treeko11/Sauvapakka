extends SceneTree
## Saves a PNG of a screen for checking layouts without a device. Needs a display
## (xvfb-run works) and --fixed-fps so time advances per frame:
##   xvfb-run godot --path . --fixed-fps 30 --script res://tools/screenshot.gd -- duel burn turtle 8 out.png
##   ... -- app 0 out.png
## Add "inspect" to pause and select a projectile, or "end" to skip to the result.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[-1]
	var seconds := float(args[-2])
	var screen: Control
	if args[0] == "duel":
		var db := SpellDB.load_default()
		var d := DuelScreen.new()
		d.setup(load("res://data/builds/%s.tres" % args[1]), load("res://data/builds/%s.tres" % args[2]), db)
		screen = d
	else:
		screen = (load("res://ui/app.tscn") as PackedScene).instantiate()
	root.add_child(screen)
	for i in maxi(2, roundi(seconds * Engine.physics_ticks_per_second / 2.0)):
		await process_frame
	if screen is DuelScreen:
		var d := screen as DuelScreen
		if "end" in args:
			while not d._ended:
				d._process(0.5)
		if "inspect" in args:
			for i in 60:
				if not d.duel.in_flight.is_empty():
					break
				await process_frame
			d._set_paused(true)
			if not d.duel.in_flight.is_empty():
				var ev := InputEventMouseButton.new()
				ev.pressed = true
				ev.button_index = MOUSE_BUTTON_LEFT
				ev.position = d._overlay.shot_position(d.duel.in_flight[0])
				d._unhandled_input(ev)
		for i in 3:
			await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()
