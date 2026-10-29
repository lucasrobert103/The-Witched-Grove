class_name IntroPanel
extends ModalPanel
## Abertura narrativa em cartões.

const CARDS := [
	["O Vale dos Sussurros", "Há magia em tudo o que cresce. Ela vem do Éter — um rio de luz que corre atrás do céu — e escorre para as folhas, as pedras e as pessoas que sabem escutar.\n\nOs antigos chamavam quem escuta de \"bruxa\". Hoje, no vale, ainda chamam."],
	["A Estrela Caída", "Dezessete invernos atrás, numa chuva de estrelas, o Círculo de Pedras brilhou como nunca. No meio dele havia um cesto de vime, e dentro dele uma menina de cabelos de trigo, quentinha como pão.\n\nOndina Vael, a bruxa mais teimosa do vale, deu a ela o nome de uma estrela: Asterion."],
	["Ondina Vael", "Ondina ensinou tudo o que cabia num dia: a ouvir as raízes, a falar baixo com o fogo, a nunca ferver a sálvia.\n\nNa noite do eclipse, saiu sem chá e sem casaco para \"buscar a fonte\". Deixou um bilhete embaixo do seu travesseiro. Não voltou."],
	["O Silêncio Cinzento", "Desde então, um cinza silencioso avança pelo bosque. As flores esquecem a própria cor. O Guardião Musgo, a árvore mais antiga do vale, dorme um sono sem sonhos.\n\nNa aldeia, o pão não cresce e as crianças sonham em preto e branco."],
	["O Círculo Sombra", "Um homem educado demais chegou ao vale vestindo cinza. Kael Morvane diz que o Éter é perigoso e precisa de dono.\n\nEle oferece atalhos. Atalhos sempre cobram depois."],
	["Varinha de Salgueiro", "Ondina deixou para você a varinha de salgueiro, seis feitiços já gravados no cabo e Nimbus, um gato-mariposa convencido.\n\nToque num feitiço e ele sai da ponta da varinha na hora — fogo que acende, gelo que congela, penas que levitam, pedras que viram sapos."],
	["Asterion", "Não há espada nesta história: só estudo, curiosidade e escolhas. Cada coisa que você transformar ensina algo ao grimório.\n\nVocê acorda na cabana da Clareira. O grimório de Ondina espera no atril, e há uma carta embaixo do travesseiro."],
]

var _i := 0
var _title: Label
var _text: Label
var _tw: Tween


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
	_tw = create_tween()
	_tw.tween_property(_text, "visible_ratio", 1.0, clampf(_text.text.length() / 38.0, 1.2, 7.0))


func _next() -> void:
	if _text.visible_ratio < 1.0:
		_tw.kill()
		_text.visible_ratio = 1.0
		return
	_i += 1
	if _i >= CARDS.size():
		close()
		return
	AudioManager.play_sfx("page_turn")
	_show()


func close() -> void:
	Game.set_flag("intro_vista")
	super.close()
