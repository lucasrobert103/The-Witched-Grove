class_name LecternPanel
extends ModalPanel
## Atril/biblioteca: o grimório de Ondina e todas as páginas já encontradas.

const ALWAYS := ["ondina_1", "ondina_2"]


func open(_payload: Dictionary) -> void:
	build_frame("Biblioteca — Grimório de Ondina", 0.72, 0.88)
	content.add_child(UITheme.label("O grimório está aberto onde Ondina parou. Folhas soltas que você encontrar pelo vale também podem ser relidas aqui.", 0.95, UITheme.PARCHMENT, true))
	var ids: Array = ALWAYS.duplicate()
	for pid in Game.grimoire.page_reads:
		if not pid in ids:
			ids.append(pid)
	for pid in ids:
		var page: Dictionary = DataRegistry.pages.get(pid, {})
		var n := Game.grimoire.times_read(pid)
		var b := UITheme.button("%s   (%s)" % [page.get("title", pid), "nova" if n == 0 else "lida %d/5" % mini(n, 5)], func(): _open_page(pid))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		content.add_child(b)
	var missing := DataRegistry.pages.size() - ids.size()
	content.add_child(UITheme.label("%d página(s) ainda espalhadas pelo mundo..." % missing, 0.85, UITheme.GOLD_DIM))


func _open_page(pid: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	close()
	if hud:
		hud.open_panel("reader", {"page": pid})
