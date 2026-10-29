extends SceneTree
## Captura de tela para revisão visual (desenvolvimento).
## Uso: godot --path . -s tools/screenshot.gd -- <cena.tscn> <saida.png> [frames] [hora]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path := args[0] if args.size() > 0 else "res://src/scenes/ui/main_menu.tscn"
	var out := args[1] if args.size() > 1 else "user://shot.png"
	var frames := int(args[2]) if args.size() > 2 else 90
	if args.size() > 3:
		root.set_meta("debug_hour", float(args[3]))
	if args.size() > 4:
		root.set_meta("debug_cam", args[4])
	if args.size() > 5:
		root.set_meta("debug_panel", args[5])
	var scene: PackedScene = load(scene_path)
	root.add_child(scene.instantiate())
	for i in frames:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("Captura salva: ", out)
	quit()
