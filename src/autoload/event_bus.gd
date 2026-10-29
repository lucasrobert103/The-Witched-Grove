extends Node
## Barramento global de eventos. Sistemas emitem; UI e mundo escutam.
## Nenhum sistema deve depender diretamente da UI.

signal notify(text: String, kind: String)            # kind: info, discovery, quest, warning, error
signal discovery_made(category: String, id: String, text: String)

signal inventory_changed()
signal currency_changed(amount: int)
signal stats_changed()

signal spell_learned(spell_id: String)
signal spell_knowledge_changed(spell_id: String, value: float)
signal spell_cast(spell_id: String, result: Dictionary)
signal spell_slots_changed()

signal page_read(page_id: String, read_count: int)
signal recipe_learned(recipe_id: String)
signal brew_finished(result: Dictionary)

signal quest_started(quest_id: String)
signal quest_updated(quest_id: String)
signal quest_completed(quest_id: String, outcome: String)

signal reputation_changed(faction_id: String, value: int)
signal flag_changed(flag: String, value: bool)

signal time_changed(hour: float)
signal day_changed(day: int)
signal season_changed(season: String)
signal weather_changed(weather: String)

signal garden_changed()
signal house_changed()
signal buff_changed(buff: String, active: bool)

signal dialogue_requested(npc_id: String)
signal dialogue_closed(npc_id: String)
signal shop_requested(shop_id: String)
signal panel_requested(panel: String, payload: Dictionary)

signal player_health_depleted()
signal teleport_requested(target: String)
signal game_loaded()
