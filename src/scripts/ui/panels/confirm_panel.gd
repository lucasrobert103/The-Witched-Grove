class_name ConfirmPanel
extends ModalPanel
## Confirmação simples (sim/não).

signal confirmed()


func open(payload: Dictionary) -> void:
	build_frame(payload.get("title", "Confirmar"), 0.56, 0.5)
	content.add_child(UITheme.label(payload.get("text", ""), 1.0, Color(0, 0, 0, 0), true))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(row)
	row.add_child(UITheme.button("Cancelar", close))
	row.add_child(UITheme.button("Confirmar", _yes))


func _yes() -> void:
	confirmed.emit()
	close()
