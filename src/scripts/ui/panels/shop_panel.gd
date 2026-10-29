class_name ShopPanel
extends ModalPanel
## Loja do Bento: comprar, vender e pedido do dia.

var shop_id := "bento"
var _mode := "comprar"


func open(payload: Dictionary) -> void:
	shop_id = payload.get("shop", "bento")
	build_frame("Carroça do Bento", 0.84, 0.92)
	_refresh()


func _refresh() -> void:
	clear_content()
	var top := HBoxContainer.new()
	content.add_child(top)
	top.add_child(UITheme.button("Comprar", func(): _set_mode("comprar")))
	top.add_child(UITheme.button("Vender", func(): _set_mode("vender")))
	top.add_child(UITheme.button("Pedido do dia", func(): _set_mode("pedido")))
	var ep := UITheme.label("   %d EP" % Game.inventory.currency, 1.15, UITheme.GOLD)
	top.add_child(ep)
	match _mode:
		"comprar":
			for id in DataRegistry.npcs[shop_id].get("trade", []):
				var iid: String = id
				var it: Dictionary = DataRegistry.items[iid]
				var row := HBoxContainer.new()
				var l := UITheme.label("%s — %s" % [it.name, it.get("description", "")], 0.85, Color(0, 0, 0, 0), true)
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(l)
				var b := UITheme.button("%d EP" % Game.buy_price(iid), func(): _buy(iid))
				b.custom_minimum_size.x = 130
				b.disabled = Game.inventory.currency < Game.buy_price(iid)
				row.add_child(b)
				content.add_child(row)
		"vender":
			var ids := Game.inventory.all_ids()
			if ids.is_empty():
				content.add_child(UITheme.label("Nada para vender.", 1.0))
			for id in ids:
				var iid: String = id
				if DataRegistry.items[iid].get("category", "") == "artefato":
					continue
				var row := HBoxContainer.new()
				var l := UITheme.label("%s ×%d [%s]" % [DataRegistry.item_name(iid), Game.inventory.count(iid), DataRegistry.quality_tier(Game.inventory.quality(iid))], 0.9)
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(l)
				var b := UITheme.button("+%d EP" % Game.sell_price(iid), func(): _sell(iid))
				b.custom_minimum_size.x = 130
				row.add_child(b)
				content.add_child(row)
		"pedido":
			var o := Game.daily_order()
			content.add_child(UITheme.label("Pedido de hoje: %d× %s" % [o.count, DataRegistry.item_name(o.item)], 1.1, UITheme.GOLD))
			content.add_child(UITheme.label("Recompensa: %d EP e a gratidão da Aldeia Vime. Você tem %d." % [o.reward, Game.inventory.count(o.item)], 0.95, Color(0, 0, 0, 0), true))
			var b := UITheme.button("Entregar" if not o.done else "Já entregue hoje", _deliver)
			b.disabled = o.done
			content.add_child(b)


func _set_mode(m: String) -> void:
	_mode = m
	_refresh()


func _buy(id: String) -> void:
	var r := Game.buy(id)
	if r.ok:
		AudioManager.play_sfx("coin")
	else:
		EventBus.notify.emit(r.reason, "warning")
	_refresh()


func _sell(id: String) -> void:
	var r := Game.sell(id)
	if r.ok:
		AudioManager.play_sfx("coin")
	else:
		EventBus.notify.emit(r.reason, "warning")
	_refresh()


func _deliver() -> void:
	var r := Game.fulfill_daily_order()
	if r.ok:
		AudioManager.play_sfx("quest_complete")
	else:
		EventBus.notify.emit(r.reason, "warning")
	_refresh()
