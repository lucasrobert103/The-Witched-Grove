extends TestCase


func test_adicionar_remover() -> void:
	var inv := Inventory.new()
	assert_eq(inv.add("folha_orvalho", 3), 3, "adiciona 3")
	assert_true(inv.has("folha_orvalho", 3), "tem 3")
	assert_true(inv.remove("folha_orvalho", 2), "remove 2")
	assert_eq(inv.count("folha_orvalho"), 1, "sobra 1")
	assert_false(inv.remove("folha_orvalho", 5), "não remove mais do que tem")
	assert_true(inv.remove("folha_orvalho", 1), "remove o último")
	assert_false(inv.stacks.has("folha_orvalho"), "pilha vazia some")


func test_qualidade_media() -> void:
	var inv := Inventory.new()
	inv.add("petala_claridade", 1, 1.0)
	inv.add("petala_claridade", 1, 0.5)
	assert_near(inv.quality("petala_claridade"), 0.75, 0.001, "qualidade média ponderada")


func test_capacidade_por_peso() -> void:
	var inv := Inventory.new()
	inv.capacity = 1.0
	var added := inv.add("pedra_comum", 5)   # 0.6 cada
	assert_eq(added, 1, "só cabe 1 pedra em 1.0 de capacidade")


func test_item_inexistente() -> void:
	var inv := Inventory.new()
	assert_eq(inv.add("nao_existe", 1), 0, "item desconhecido é ignorado")


func test_moeda() -> void:
	var inv := Inventory.new()
	inv.add_currency(100)
	assert_false(inv.spend_currency(150), "não gasta além do saldo")
	assert_true(inv.spend_currency(40), "gasta 40")
	assert_eq(inv.currency, 60, "saldo 60")


func test_passivas_de_ferramentas() -> void:
	var inv := Inventory.new()
	inv.add("tesoura_poda", 1)
	assert_eq(int(inv.passive_value("harvest_bonus", 0)), 1, "tesoura dá +1 colheita")
	assert_false(bool(inv.passive_value("water_all", false)), "sem regador")
