class_name MessagePanel
extends ModalPanel
## Mensagem simples (placas, portal, avisos).

func open(payload: Dictionary) -> void:
	build_frame(payload.get("title", ""), 0.62, 0.6)
	var t := UITheme.label(payload.get("text", ""), 1.0, Color(0, 0, 0, 0), true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(t)
	content.add_child(UITheme.button("Entendi", close))
