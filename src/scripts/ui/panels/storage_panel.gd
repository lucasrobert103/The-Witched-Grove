class_name StoragePanel
extends ModalPanel
## Armazém da cabana: tudo o que Asterion guarda, com ícones.

func open(_payload: Dictionary) -> void:
	build_frame("Armazém da Cabana", 0.94, 0.92, false)
	var lvl := Game.house.level("armazem")
	content.add_child(UITheme.label("Baú encantado de Ondina — nível %d (%s). Melhore no Livro → Casa para guardar mais." % [lvl, DataRegistry.house_rooms["armazem"].upgrade_desc[clampi(lvl, 0, 2)]], 0.85, UITheme.PARCHMENT, true))
	var view := InventoryView.new()
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(view)
