extends Node
## Teste de fumaça do mundo 3D: carrega o Vale, joga trechos do Ato I usando os
## objetos reais (interações, feitiços, painéis) e verifica o estado resultante.
## Uso: godot --headless res://tests/smoke_world.tscn   (código de saída 0 = ok)

var world: GameWorld
var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
		printerr("  ✗ " + msg)
	else:
		print("  ✓ " + msg)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func find_station(kind: String) -> Station:
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is Station and n.kind == kind:
			return n
	return null


func find(cls_name: String, pred: Callable = Callable()) -> Node:
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.get_script() and n.get_script().get_global_name() == cls_name and (not pred.is_valid() or pred.call(n)):
			return n
	return null


func goto(p: Vector3) -> void:
	world.player.place_at(world.builder.at(p.x, p.z, 0.2), 0.0)
	await frames(3)


func close_modal() -> void:
	var hud = world.hud
	if hud.modal and is_instance_valid(hud.modal):
		hud.modal.close()
	await frames(2)


func cast(spell_id: String, at: Node3D = null) -> Dictionary:
	Game.stats.mana = Game.stats.max_mana()
	Game.spells.cooldowns.clear()
	if at:
		var d := at.global_position - world.player.global_position
		world.player.cam_yaw = atan2(-d.x, -d.z)
	var r := Game.cast_spell(spell_id)
	await get_tree().create_timer(0.9).timeout
	await frames(2)
	return r


func _run() -> void:
	SaveManager.delete_save()
	Game.new_game()
	Game.set_flag("intro_vista")
	var scene: PackedScene = load("res://src/scenes/world/game_world.tscn")
	world = scene.instantiate()
	get_tree().root.add_child(world)
	await frames(10)
	check(world.player != null, "protagonista criada")
	check(get_tree().get_nodes_in_group("interactable").size() > 60, "mundo povoado (%d interativos)" % get_tree().get_nodes_in_group("interactable").size())

	# --- caminhar com o joystick
	var start := world.player.global_position
	world.hud._joy.value = Vector2(0, -1)
	await frames(40)
	world.hud._joy.value = Vector2.ZERO
	check(world.player.global_position.distance_to(start) > 0.5, "joystick move a protagonista")

	check(world.current_room != null and world.current_room.room_id == "cabana", "novo jogo começa dentro da cabana")

	# --- ler o grimório no atril (painel real, dentro de casa)
	var lectern := find_station("lectern")
	await goto(lectern.global_position + Vector3(0, 0, 1.2))
	lectern.interact(world.player)
	await frames(2)
	check(world.hud.modal is LecternPanel, "atril abre a biblioteca")
	world.hud.modal._open_page("ondina_1")
	await frames(2)
	check(world.hud.modal is ReaderPanel, "página abre o leitor")
	check(Game.spells.is_known("botany:crescimento_rapido"), "leitura ensina Crescimento Rápido")
	await close_modal()

	# --- baú abre o armazém com ícones
	find_station("chest").interact(world.player)
	await frames(2)
	check(world.hud.modal is StoragePanel, "baú abre o armazém")
	await close_modal()

	# --- sair pela porta
	var exit_door: Station = find("Station", func(n): return n.kind == "door_exit" and n.data.get("room", "") == "cabana")
	exit_door.interact(world.player)
	await get_tree().create_timer(1.0).timeout
	check(world.current_room == null, "porta leva de volta ao vale")
	check(world.player.global_position.x < 100.0, "protagonista do lado de fora")

	# --- lançar no jardim (a lógica de flag + jardim reage)
	Game.add_school_xp("botany", 1.0)
	await goto(Vector3(-6.6, 0, 3.6))
	Game.give_item("semente_orvalheira", 1, 1.0, true)
	Game.garden_plant(1, "semente_orvalheira")
	var before := float(Game.garden.plot(1).growth)
	await cast("botany:crescimento_rapido")
	Game.refresh_quests()
	check(float(Game.garden.plot(1).growth) > before, "Crescimento Rápido acelera o canteiro")
	check(Game.quests.current_objective("mq01_grimorio") == "salvia", "mq01 avança para Sálvia")

	# --- transformações: pedra vira sapo, abóbora levita, caixa pega fogo
	var rock: MagicProp = find("MagicProp", func(n): return n.prop_id == "casa_pedra_1")
	await goto(rock.global_position + Vector3(0, 0, 4.0))
	await cast("transmutation:transfigurar", rock)
	check(rock.form == "frog", "Transfiguração: pedra vira sapo")
	check(Game.has_flag("transf.rock.transfigurar"), "transformação registrada como descoberta")
	var pumpkin: MagicProp = find("MagicProp", func(n): return n.prop_id == "casa_abobora_1")
	await goto(pumpkin.global_position + Vector3(3.0, 0, 3.0))
	await cast("transmutation:levitar", pumpkin)
	check(pumpkin._lev_t > 0.0, "Levitação faz a abóbora flutuar")
	await cast("elemental:chama_controlada", pumpkin)
	check(pumpkin.status == "lit", "Chama acende a abóbora (lanterna)")
	var crate: MagicProp = find("MagicProp", func(n): return n.prop_id == "casa_caixa_1")
	await goto(crate.global_position + Vector3(0, 0, 4.0))
	await cast("elemental:cristal_gelo", crate)
	check(crate.status == "frozen", "Gelo congela a caixa")
	await cast("transmutation:forma_alterada")
	check(Game.has_buff("cat") and world.player.cat.visible, "Metamorfose: vira gato")
	await cast("transmutation:forma_alterada")
	check(not Game.has_buff("cat"), "Metamorfose de novo: volta ao normal")

	# --- todos os painéis abrem e fecham sem erro
	for panel in [["book", {"tab": "grimorio"}], ["book", {"tab": "inventario"}], ["book", {"tab": "missoes"}], ["book", {"tab": "escolas"}],
			["book", {"tab": "mapa"}], ["book", {"tab": "casa"}], ["book", {"tab": "diario"}], ["book", {"tab": "opcoes"}],
			["lab", {}], ["garden", {"plot": 4}], ["shop", {"shop": "bento"}], ["rest", {}], ["message", {"title": "t", "text": "x"}], ["intro", {}], ["storage", {}]]:
		world.hud.open_panel(panel[0], panel[1])
		await frames(2)
		check(world.hud.modal != null, "painel %s/%s abre" % [panel[0], str(panel[1].get("tab", ""))])
		await close_modal()

	# --- laboratório pelo painel
	Game.give_item("folha_orvalho", 1, 1.0, true)
	world.hud.open_panel("lab", {})
	await frames(2)
	var lab: LabPanel = world.hud.modal
	lab._add_ing("folha_orvalho")
	lab._add_ing("agua_manancial")
	lab._add_tech("moer")
	lab._add_tech("aquecer")
	lab._brew()
	await frames(2)
	check(Game.inventory.count("tonico_revigorante") >= 1, "painel do laboratório prepara Tônico")
	await close_modal()

	# --- diálogo com Sálvia pelo NPC real
	var salvia: NPCActor = find("NPCActor", func(n): return n.npc_id == "salvia")
	await goto(salvia.global_position + Vector3(0, 0, 1.5))
	salvia.interact(world.player)
	await frames(3)
	check(world.hud.modal is DialoguePanel, "Sálvia abre diálogo")
	var dp: DialoguePanel = world.hud.modal
	check(dp._typing, "texto aparece letra a letra")
	for i in 8:
		dp._advance()
		await frames(2)
	check(dp._opt_scroll.visible, "opções aparecem ao fim do texto")
	await close_modal()
	Game.refresh_quests()
	check(Game.quests.is_done("mq01_grimorio"), "mq01 concluída conversando com Sálvia")

	# --- Cogumelo Resmungão: empurra sem chá, acalma com chá
	var mush: CreatureActor = find("CreatureActor", func(n): return n.kind == "mushroom")
	await goto(mush.home + Vector3(-2.0, 0, 0))
	await frames(10)
	check(Game.quests.is_active("sq_cogumelo") or Game.quests.is_done("sq_cogumelo"), "aproximar inicia a missão do cogumelo")
	check(world.player.global_position.distance_to(mush.global_position) > 2.5, "cogumelo empurra quem chega sem Véu")
	Game.give_item("cha_calmante", 1, 1.0, true)
	mush.interact(world.player)
	await frames(3)
	check(Game.has_flag("cogumelo_calmo"), "Chá Calmante acalma o cogumelo")

	# --- ponte de vinhas com Crescimento Rápido
	var bridge: Obstacle = find("Obstacle", func(n): return n.kind == "vine_bridge")
	await goto(bridge.global_position + Vector3(-5.0, 0, 0))
	await cast("botany:crescimento_rapido", bridge)
	check(Game.has_flag("obst.ponte_vinhas"), "vinha desperta e vira ponte")

	# --- sarças com Chama Controlada
	Game.spells.add_knowledge("elemental:chama_controlada", 20.0)
	var bramble: Obstacle = find("Obstacle", func(n): return n.kind == "bramble")
	await goto(bramble.global_position + Vector3(0, 0, 2.5))
	await cast("elemental:chama_controlada", bramble)
	check(Game.has_flag("obst.sarca_oeste"), "Chama Controlada queima as sarças")
	check(Game.inventory.count("espinho_sarca") >= 3, "sarças deixam espinhos")

	# --- noite na lagoa: Lume + Faísca
	Game.start_quest("sq_juniper")
	Game.clock.total_minutes = 22.0 * 60.0
	Game.spells.add_knowledge("astral:lume", 20.0)
	await goto(Vector3(-22.0, 0, -14.0))
	await cast("astral:lume")
	check(Game.has_buff("light_orb"), "Lume Estelar ativo")
	for n in get_tree().get_nodes_in_group("interactable"):
		n.refresh_state()
	var faisca: CreatureActor = find("CreatureActor", func(n): return n.kind == "faisca")
	check(faisca.visible, "Faísca aparece à noite durante a missão")
	faisca.interact(world.player)
	await frames(2)
	check(Game.inventory.count("lanterna_faisca") == 1, "Faísca encontrada com luz estelar")

	# --- marca estelar à noite com Lume
	var mark: StarMark = find("StarMark", func(n): return n.mark_index == 1)
	check(mark.can_interact(), "marca estelar revelada à noite com luz")
	mark.interact(world.player)
	check(Game.has_flag("marca_estelar_1"), "marca estelar registrada")

	# --- gelo na lagoa
	Game.spells.add_knowledge("elemental:cristal_gelo", 20.0)
	Game.stats.schools["elemental"] = 12.0
	var pond_target := Node3D.new()
	world.add_child(pond_target)
	pond_target.global_position = Vector3(ValleyTerrain.POND_CENTER.x, 0, ValleyTerrain.POND_CENTER.y)
	await cast("elemental:cristal_gelo", pond_target)
	check(world.builder.pond.is_frozen(), "Cristal de Gelo congela a lagoa")

	# --- Guardião: purificação por contra-magia
	Game.start_quest("mq02_raizes")
	for oid in ["folhas", "tonico", "levar"]:
		Game.quests.states["mq02_raizes"].objectives[oid] = true
	Game.spells.add_knowledge("protection:limpeza_magica", 20.0)
	Game.stats.schools["protection"] = 20.0
	await goto(Vector3(0, 0, -32.0))
	var musgo: NPCActor = find("NPCActor", func(n): return n.npc_id == "musgo")
	await cast("protection:limpeza_magica", musgo)
	await frames(3)
	check(Game.has_flag("musgo_purificado") and Game.has_flag("purificado_magia"), "Limpeza Mágica purifica o Guardião")
	check(world.hud.modal is DialoguePanel, "Guardião fala ao ser curado")
	await close_modal()
	check(not world.builder.corruption.visible, "mancha cinza desaparece")

	# --- padaria da Dorinha: entrar, fazer a massa crescer, receber pão
	var bakery_door: Station = find("Station", func(n): return n.kind == "door" and n.data.get("room", "") == "padaria")
	check(bakery_door != null, "a aldeia tem a porta da padaria")
	await goto(bakery_door.global_position)
	bakery_door.interact(world.player)
	await get_tree().create_timer(1.0).timeout
	check(world.current_room != null and world.current_room.room_id == "padaria", "entrou na padaria")
	var dorinha: NPCActor = find("NPCActor", func(n): return n.npc_id == "dorinha")
	check(dorinha.visible and dorinha.global_position.x > 300.0, "Dorinha está dentro da padaria")
	dorinha.interact(world.player)
	await frames(3)
	await close_modal()
	check(Game.quests.is_active("sq_padaria"), "Dorinha pede ajuda com a massa")
	var dough: MagicProp = find("MagicProp", func(n): return n.kind == "dough")
	world.player.place_at(dough.global_position + Vector3(0, -0.9, 2.2), 0.0)
	await frames(3)
	await cast("botany:crescimento_rapido", dough)
	check(Game.has_flag("massa_crescida"), "Crescimento faz a massa crescer")
	Game.refresh_quests()
	Game.dialogue.start("dorinha")
	check(Game.quests.is_done("sq_padaria"), "Dorinha agradece e conclui a missão")
	check(Game.inventory.count("pao_mel") >= 3, "ganhou pães de mel")
	world.exit_interior()
	await get_tree().create_timer(1.0).timeout

	# --- desmaio e teleporte para casa
	Game.buffs.erase("shield")
	Game.damage(9999.0)
	await frames(3)
	check(world.player.global_position.distance_to(world.builder.at(0, -1)) < 3.0, "desmaio leva para casa")

	# --- salvar e carregar
	world.save_now()
	check(SaveManager.has_save(), "jogo salvo")
	var day := Game.clock.day()
	Game.new_game()
	check(SaveManager.load_game(), "jogo carregado")
	check(Game.clock.day() == day and Game.has_flag("obst.ponte_vinhas"), "estado restaurado do save")
	SaveManager.delete_save()

	world.queue_free()
	await frames(3)
	Toon._cache.clear()
	MeshKit._meshes.clear()
	UITheme._theme = null
	print("")
	if failures.is_empty():
		print("SMOKE OK — mundo 3D jogável sem falhas")
		get_tree().quit(0)
	else:
		printerr("SMOKE FALHOU: %d verificação(ões)" % failures.size())
		get_tree().quit(1)
