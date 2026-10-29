class_name ReaderPanel
extends ModalPanel
## Leitura de páginas do grimório: ler ensina; reler aprofunda (até 5 vezes).

var page_id := ""
var _body: VBoxContainer


func open(payload: Dictionary) -> void:
	page_id = payload.get("page", "")
	var page: Dictionary = DataRegistry.pages.get(page_id, {})
	build_frame(page.get("title", "Página"), 0.78, 0.9)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	content.add_child(_body)
	_read()


func _read() -> void:
	for c in _body.get_children():
		c.queue_free()
	var r := Game.read_page(page_id)
	AudioManager.play_sfx("page_turn")
	var page: Dictionary = DataRegistry.pages.get(page_id, {})
	var parch := UITheme.card(UITheme.PARCHMENT, UITheme.GOLD_DIM)
	var txt := UITheme.rich("[i]%s[/i]" % page.get("text", ""), 1.05)
	txt.add_theme_color_override("default_color", UITheme.INK)
	parch.add_child(txt)
	_body.add_child(parch)
	var info: Array = []
	var teaches: Dictionary = page.get("teaches", {})
	if teaches.has("spell"):
		var sid: String = teaches.spell
		var d := Game.spells.def(sid)
		var k := Game.spells.get_knowledge(sid)
		info.append("[color=#f3c74f]Feitiço:[/color] %s (%s) — compreensão [b]%d%%[/b]" % [d.name, DataRegistry.school_name(d.school), int(k)])
		if r.learned == sid:
			info.append("[color=#7dffa0]Você compreendeu o padrão! O feitiço foi colocado na sua barra de magia.[/color]")
		var req := int(d.get("level_required", 0))
		if Game.stats.school(d.school) < req:
			info.append("[color=#ff9a8a]Para lançar: %s nível %d (você tem %d).[/color]" % [DataRegistry.school_name(d.school), req, int(Game.stats.school(d.school))])
	if teaches.has("recipe"):
		info.append("[color=#f3c74f]Receita anotada:[/color] %s" % DataRegistry.recipes[teaches.recipe].name)
	if not page.get("symbols", {}).is_empty():
		var syms: Array = []
		for s in page.symbols:
			syms.append("%s = %s" % [s.replace("_", " "), page.symbols[s]])
		info.append("[color=#c9a5ff]Símbolos compreendidos:[/color] " + ", ".join(syms))
	var reads := Game.grimoire.times_read(page_id)
	info.append("Leituras: %d/5 %s" % [mini(reads, 5), "(compreensão máxima pela leitura)" if reads >= 5 else "— reler aprofunda a compreensão (+30 min)"])
	_body.add_child(UITheme.rich("\n".join(info), 0.9))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	if reads < 5:
		row.add_child(UITheme.button("Reler com atenção", _read))
	row.add_child(UITheme.button("Fechar", close))
	_body.add_child(row)
