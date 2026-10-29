class_name RestPanel
extends ModalPanel
## Dormitório: descansar (avança o tempo, recupera saúde e mana) e salvar.

func open(_payload: Dictionary) -> void:
	build_frame("Dormitório", 0.6, 0.66)
	var h := Game.clock.hour()
	var night := h >= 18.0 or h < 5.0
	content.add_child(UITheme.label("A cama de Ondina ainda cheira a lavanda. Nimbus já está enrolado no travesseiro.", 1.0, Color(0, 0, 0, 0), true))
	content.add_child(UITheme.label("Agora: %s · Saúde %d/%d · Mana %d/%d" % [Game.clock.time_string(), int(Game.stats.health), int(Game.stats.max_health()), int(Game.stats.mana), int(Game.stats.max_mana())], 0.85, UITheme.PARCHMENT, true))
	if night:
		content.add_child(UITheme.button("Dormir até o amanhecer (recupera tudo)", _rest))
	else:
		content.add_child(UITheme.button("Cochilar 3 horas (recupera metade)", _rest))
	content.add_child(UITheme.button("Salvar o jogo", _save))
	content.add_child(UITheme.button("Voltar", close))


func _rest() -> void:
	var r := Game.rest()
	AudioManager.play_sfx("rest")
	var world := get_tree().get_first_node_in_group("game_world")
	if world:
		world.save_now()
	EventBus.notify.emit("Você %s. São %s do dia %d. (Jogo salvo)" % ["dormiu como uma pedra" if r.kind == "sono" else "cochilou", Game.clock.time_string(), Game.clock.day()], "info")
	close()


func _save() -> void:
	var world := get_tree().get_first_node_in_group("game_world")
	if world:
		world.save_now()
	EventBus.notify.emit("Jogo salvo.", "info")
	close()
