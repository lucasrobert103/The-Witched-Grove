extends TestCase
## Fluxo completo do Ato I por cada rota de solução (missões completáveis).


func _do_mq01() -> void:
	Game.read_page("ondina_1")
	Game.refresh_quests()
	assert_eq(Game.quests.current_objective("mq01_grimorio"), "lancar", "após ler: lançar")
	Game.cast_spell("botany:crescimento_rapido")
	Game.refresh_quests()
	assert_eq(Game.quests.current_objective("mq01_grimorio"), "salvia", "após lançar: visitar Sálvia")
	talk("salvia")
	assert_true(Game.has_flag("falou_salvia_1"), "conversou com Sálvia")
	assert_true(Game.spells.is_known("botany:identificar_propriedades"), "caderno de Sálvia ensina Identificação")
	assert_true(Game.grimoire.knows_recipe("cha_calmante"), "caderno ensina Chá Calmante")
	Game.refresh_quests()
	assert_true(Game.quests.is_done("mq01_grimorio"), "mq01 concluída")
	choose_option("bosque")
	choose_option("ajudar o Guardião")
	assert_true(Game.quests.is_active("mq02_raizes"), "mq02 iniciada")


func _do_mq02_until_purify() -> void:
	Game.give_item("folha_orvalho", 3)
	Game.refresh_quests()
	assert_eq(Game.quests.current_objective("mq02_raizes"), "tonico", "folhas coletadas")
	Game.brew(["folha_orvalho", "agua_manancial"], ["moer", "aquecer"])
	Game.refresh_quests()
	assert_eq(Game.quests.current_objective("mq02_raizes"), "levar", "tônico preparado")
	talk("musgo")
	choose_option("Derramar")
	assert_eq(Game.quests.current_objective("mq02_raizes"), "purificar", "Guardião acordou")


func test_rota_alquimica() -> void:
	_do_mq01()
	_do_mq02_until_purify()
	Game.stats.schools["alchemy"] = 6.0
	Game.give_item("petala_claridade", 1)
	Game.give_item("cristal_lunar", 1)
	Game.give_item("trevo_quatro", 1)
	var r := Game.brew(["petala_claridade", "cristal_lunar", "trevo_quatro"], ["destilar", "aquecer", "esfriar"])
	assert_eq(r.get("output", ""), "tintura_purificadora", "tintura preparada")
	talk("musgo")
	choose_option("Tintura")
	assert_true(Game.has_flag("musgo_purificado"), "Guardião purificado")
	assert_true(Game.quests.is_active("mq03_selo"), "mq03 iniciada pelo Guardião")
	assert_eq(Game.inventory.count("lagrima_guardiao"), 1, "Lágrima do Guardião")
	talk("salvia")
	assert_true(Game.quests.is_done("mq02_raizes"), "mq02 concluída")
	assert_eq(Game.quests.outcome("mq02_raizes"), "harmonia", "desfecho harmonia")
	assert_true(Game.reputation("druidas") > 20, "Druidas aprovam")


func test_rota_atalho_de_kael() -> void:
	_do_mq01()
	_do_mq02_until_purify()
	var druid_before := Game.reputation("druidas")
	talk("kael")
	choose_option("Aceitar")
	assert_eq(Game.inventory.count("po_cinzento"), 1, "recebeu o pó")
	talk("musgo")
	choose_option("Pó Cinzento")
	talk("salvia")
	assert_eq(Game.quests.outcome("mq02_raizes"), "atalho", "desfecho atalho")
	assert_true(Game.has_flag("consequencia_musgo_violeta"), "consequência registrada")
	assert_true(Game.reputation("druidas") < druid_before, "Druidas desaprovam")
	talk("musgo")
	assert_eq(Game.dialogue.node_id, "corrompido", "o Guardião lembra da escolha")


func test_rota_contra_magia_e_ato_final() -> void:
	_do_mq01()
	_do_mq02_until_purify()
	talk("tome")
	choose_option("estrela de cinco pontas")
	assert_true(Game.spells.is_known("protection:limpeza_magica"), "aprendeu Limpeza Mágica")
	# O mundo marca a purificação quando o feitiço atinge o Guardião:
	Game.set_flag("purificado_magia")
	Game.set_flag("musgo_purificado")
	Game.apply_effects([{"give_item": ["lagrima_guardiao", 1]}, {"start_quest": "mq03_selo"}])
	talk("salvia")
	assert_eq(Game.quests.outcome("mq02_raizes"), "contra_magia", "desfecho contra-magia")
	Game.read_page("diario_ondina")
	Game.refresh_quests()
	talk("tome")
	assert_eq(Game.dialogue.node_id, "selo", "Tomé explica o selo")
	Game.refresh_quests()
	assert_true(Game.quests.is_done("mq03_selo"), "Ato I concluído")
	assert_true(Game.has_flag("ato1_concluido"), "flag de fim do Ato I")


func test_cogumelo_amizade() -> void:
	Game.start_quest("sq_cogumelo")
	Game.set_flag("cogumelo_calmo")
	Game.refresh_quests()
	assert_eq(Game.quests.outcome("sq_cogumelo"), "amizade", "desfecho amizade")


func test_mirela_vitoria_e_derrota() -> void:
	talk("mirela")
	choose_option("Continuar")
	choose_option("Desafio aceito")
	assert_eq(Game.quests.current_objective("sq_mirela"), "entregar", "desafio aceito")
	Game.give_item("pocao_foco_claro", 1, 0.95)
	talk("mirela")
	choose_option("(Refinada)")
	assert_eq(Game.quests.outcome("sq_mirela"), "vitoria", "venceu")
	assert_eq(Game.house.level("laboratorio"), 2, "ganhou o alambique")
	before_each()
	talk("mirela")
	choose_option("Continuar")
	choose_option("Desafio aceito")
	Game.give_item("pocao_foco_claro", 1, 0.6)
	talk("mirela")
	choose_option("Aqui está minha Poção de Foco Claro.")
	assert_eq(Game.quests.outcome("sq_mirela"), "derrota", "perdeu, mas ganhou dica")


func test_juniper_libertar_exige_conhecimento() -> void:
	talk("juniper")
	choose_option("encontrá-la")
	Game.give_item("lanterna_faisca", 1)
	talk("juniper")
	var has_free := false
	for o in Game.dialogue.options():
		if "feliz" in o.text:
			has_free = true
	assert_false(has_free, "sem conhecimento do bestiário, não há opção de libertar")
	Game.add_bestiary("lumecula", 3)
	talk("juniper")
	choose_option("feliz")
	choose_option("soltá-la")
	assert_eq(Game.quests.outcome("sq_juniper"), "libertada", "Faísca libertada")


func test_lyra_marcas() -> void:
	talk("lyra")
	for i in [1, 2, 3]:
		Game.set_flag("marca_estelar_%d" % i)
	Game.refresh_quests()
	talk("lyra")
	assert_true(Game.quests.is_done("sq_lyra"), "Lyra concluída")
	assert_true(Game.spells.is_known("astral:visao_noturna"), "Visão Noturna aprendida")
	assert_eq(Game.inventory.count("po_estrela"), 2, "pó de estrela")


func test_bento_encomenda_e_loja() -> void:
	talk("bento")
	choose_option("Precisa")
	Game.give_item("tonico_revigorante", 2)
	talk("bento")
	choose_option("dois tônicos")
	assert_true(Game.quests.is_done("sq_bento"), "encomenda entregue")
	var ep := Game.inventory.currency
	var r := Game.buy("semente_lavanda")
	assert_true(r.ok, "comprou semente")
	assert_eq(Game.inventory.currency, ep - Game.buy_price("semente_lavanda"), "pagou o preço")
	assert_true(Game.sell_price("semente_lavanda") < Game.buy_price("semente_lavanda"), "sem arbitragem")
