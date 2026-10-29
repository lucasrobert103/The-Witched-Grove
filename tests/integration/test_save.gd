extends TestCase


func test_ida_e_volta() -> void:
	Game.read_page("ondina_1")
	Game.give_item("musgo_lunar", 2, 0.8)
	Game.set_flag("teste_flag")
	Game.change_rep("escribas", 7)
	Game.clock.advance_minutes(3000.0)
	var d := Game.to_dict()
	var json := JSON.stringify(d)
	Game.new_game()
	Game.from_dict(JSON.parse_string(json))
	assert_true(Game.spells.is_known("botany:crescimento_rapido"), "feitiço restaurado")
	assert_eq(Game.inventory.count("musgo_lunar"), 2, "itens restaurados")
	assert_near(Game.inventory.quality("musgo_lunar"), 0.8, 0.001, "qualidade restaurada")
	assert_true(Game.has_flag("teste_flag"), "flag restaurada")
	assert_eq(Game.reputation("escribas"), 7, "reputação restaurada")
	assert_eq(Game.clock.day(), 3, "relógio restaurado")
	assert_eq(Game.quests.current_objective("mq01_grimorio"), "ler", "missão restaurada")


func test_save_manager_em_disco() -> void:
	Game.give_ep(77)
	assert_true(SaveManager.save_game(), "salvou")
	var ep := Game.inventory.currency
	Game.new_game()
	assert_true(SaveManager.load_game(), "carregou")
	assert_eq(Game.inventory.currency, ep, "moeda restaurada do disco")
	SaveManager.delete_save()
	assert_false(SaveManager.has_save(), "save apagado")


func test_save_corrompido_e_rejeitado() -> void:
	SaveManager.save_game()
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{\"meta\":{\"checksum\":\"x\"},\"data\":\"{}\"}")
	f.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.BACKUP_PATH))
	assert_false(SaveManager.load_game(), "checksum inválido rejeitado")
	SaveManager.delete_save()
