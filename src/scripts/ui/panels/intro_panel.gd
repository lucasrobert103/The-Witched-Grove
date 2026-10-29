class_name IntroPanel
extends ModalPanel
## Abertura narrativa em cartões.

const CARDS := [
	["O Vale dos Sussurros", "Há magia em tudo o que cresce. Ela vem do Éter — uma camada do mundo atrás do céu — e escorre para as folhas, as pedras e as pessoas que sabem escutar."],
	["Ondina Vael", "Sua mestra, Ondina, era a bruxa mais teimosa do vale. Na noite do eclipse, saiu sem chá e sem casaco para \"buscar a fonte\". Não voltou."],
	["O Silêncio Cinzento", "Desde então, um cinza silencioso avança pelo bosque. As plantas esquecem a própria cor. O Guardião Musgo, a árvore mais antiga do vale, dorme um sono sem sonhos."],
	["Asterion", "Você ficou com a cabana, um grimório pela metade e Nimbus, um gato-mariposa convencido. Não há espada nesta história: só estudo, curiosidade e escolhas.\n\nComece pelo grimório de Ondina, no atril da varanda."],
]

var _i := 0
var _title: Label
var _text: Label


func open(_payload: Dictionary) -> void:
	build_frame("", 0.7, 0.62, false)
	_title = UITheme.label("", 1.5, UITheme.GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_title)
	_text = UITheme.label("", 1.1, Color(0, 0, 0, 0), true)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(row)
	row.add_child(UITheme.button("Pular", close))
	row.add_child(UITheme.button("Continuar", _next))
	_show()


func _show() -> void:
	_title.text = CARDS[_i][0]
	_text.text = CARDS[_i][1]
	_text.visible_ratio = 0.0
	var tw := create_tween()
	tw.tween_property(_text, "visible_ratio", 1.0, 1.4)


func _next() -> void:
	_i += 1
	if _i >= CARDS.size():
		close()
		return
	AudioManager.play_sfx("page_turn")
	_show()


func close() -> void:
	Game.set_flag("intro_vista")
	super.close()
