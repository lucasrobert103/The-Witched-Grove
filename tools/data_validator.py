#!/usr/bin/env python3
"""Valida os JSON de data/ sem precisar do Godot (útil em CI e para designers).

Verifica referências cruzadas (itens, feitiços, missões, páginas, facções) e
mostra o que cada par de ingredientes produz no caldeirão — ótimo para
balancear receitas.

Uso:
    python3 tools/data_validator.py            # valida
    python3 tools/data_validator.py --pares    # + tabela de combinações
"""
import itertools
import json
import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data")
errors = []


def load(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return json.load(f)


def err(msg):
    errors.append(msg)


schools = load("spells/schools.json")
spells = {s["id"]: s for s in load("spells/spells.json")["spells"]}
ingredients = {i["id"]: i for i in load("ingredients/ingredients.json")["ingredients"]}
items_doc = load("items/items.json")
items = dict(ingredients)
items.update({i["id"]: i for i in items_doc["items"]})
plants = {p["id"]: p for p in load("plants/plants.json")["plants"]}
rec_doc = load("recipes/recipes.json")
recipes = {r["id"]: r for r in rec_doc["recipes"]}
npcs = {n["id"]: n for n in load("npcs/npcs.json")["npcs"]}
dialogues = load("npcs/dialogues.json")
quests = {q["id"]: q for q in load("quests/quests.json")["quests"]}
factions = {f["id"]: f for f in load("world/factions.json")["factions"]}
rooms = {r["id"]: r for r in load("world/house.json")["rooms"]}
creatures = {c["id"]: c for c in load("world/creatures.json")["creatures"]}
pages_doc = load("lore/pages.json")
pages = {p["id"]: p for p in pages_doc["pages"]}
props = set(schools["property_names"].keys())
techniques = set(schools["techniques"].keys())

for s in spells.values():
    if s["school"] not in schools["schools"]:
        err(f"feitiço {s['id']}: escola {s['school']}")
    for ing in s.get("ingredient_cost", {}):
        if ing not in items:
            err(f"feitiço {s['id']}: custo {ing}")
for i in ingredients.values():
    if not 5 <= len(i["properties"]) <= 7:
        err(f"ingrediente {i['id']}: precisa de 5-7 propriedades")
    for p in i["properties"]:
        if p not in props:
            err(f"ingrediente {i['id']}: propriedade {p}")
for r in recipes.values():
    if r["output"] not in items:
        err(f"receita {r['id']}: saída {r['output']}")
    for t in r["technique"]:
        if t not in techniques:
            err(f"receita {r['id']}: técnica {t}")
    for p in r["requires"] + r.get("forbids", []):
        if p not in props:
            err(f"receita {r['id']}: propriedade {p}")
for p in plants.values():
    if p["produces"] not in ingredients:
        err(f"planta {p['id']}: produz {p['produces']}")
    if items.get(p["seed"], {}).get("plant") != p["id"]:
        err(f"planta {p['id']}: semente {p['seed']} não aponta de volta")
for pg in pages.values():
    t = pg.get("teaches", {})
    if "spell" in t and t["spell"] not in spells:
        err(f"página {pg['id']}: feitiço {t['spell']}")
    if "recipe" in t and t["recipe"] not in recipes:
        err(f"página {pg['id']}: receita {t['recipe']}")
for n in npcs.values():
    if n["faction"] not in factions:
        err(f"npc {n['id']}: facção {n['faction']}")
    for it in n.get("trade", []):
        if it not in items:
            err(f"npc {n['id']}: vende {it}")


def check_effects(effs, where):
    for e in effs:
        for k, v in e.items():
            if k in ("give_item", "take_item") and v[0] not in items:
                err(f"{where}: item {v[0]}")
            if k == "start_quest" and v not in quests:
                err(f"{where}: missão {v}")
            if k == "complete_quest" and v[0] not in quests:
                err(f"{where}: missão {v[0]}")
            if k == "rep" and v[0] not in factions:
                err(f"{where}: facção {v[0]}")
            if k == "read_page" and v not in pages:
                err(f"{where}: página {v}")
            if k == "bestiary" and v[0] not in creatures:
                err(f"{where}: criatura {v[0]}")
            if k == "upgrade_room" and v not in rooms:
                err(f"{where}: cômodo {v}")


for npc, tree in dialogues.items():
    nodes = tree["nodes"]
    for e in tree["entries"]:
        if e["node"] not in nodes:
            err(f"diálogo {npc}: entrada {e['node']}")
    for nid, node in nodes.items():
        check_effects(node.get("effects", []), f"diálogo {npc}/{nid}")
        for o in node.get("options", []):
            g = o.get("goto", "end")
            if g != "end" and g not in nodes:
                err(f"diálogo {npc}/{nid}: goto {g}")
            check_effects(o.get("effects", []), f"diálogo {npc}/{nid}")
for q in quests.values():
    for o in q["objectives"]:
        if "target" not in o or "hint" not in o:
            err(f"missão {q['id']}/{o['id']}: sem alvo/dica para o Nimbus")
    for oid, out in q.get("outcomes", {}).items():
        check_effects(out.get("effects", []), f"missão {q['id']}/{oid}")


# ----------------------------------------------------------------- simulação do caldeirão
def brew(ids):
    counts = {}
    for i in ids:
        for p in ingredients[i]["properties"]:
            counts[p] = counts.get(p, 0) + 1
    active = {p for p, c in counts.items() if c >= 2}
    for a, b in schools["incompatible_properties"]:
        if a in active and b in active:
            active -= {a, b}
    cands = [r for r in rec_doc["recipes"] if set(r["requires"]) <= active and not (set(r.get("forbids", [])) & active)]
    cands.sort(key=lambda r: -len(r["requires"]))
    return cands[0]["id"] if cands else None


found = {}
for n in (2, 3):
    for combo in itertools.combinations(sorted(ingredients), n):
        r = brew(combo)
        if r:
            found.setdefault(r, []).append(combo)
for rid in recipes:
    if rid not in found:
        err(f"receita {rid}: nenhuma combinação de 2-3 ingredientes a produz")

if "--pares" in sys.argv:
    for rid, combos in sorted(found.items()):
        pairs = [c for c in combos if len(c) == 2]
        print(f"{rid}: {len(combos)} combinações ({len(pairs)} pares). Ex.: {pairs[:3] or combos[:2]}")

print(f"Dados: {len(spells)} feitiços, {len(ingredients)} ingredientes, {len(recipes)} receitas, "
      f"{len(plants)} plantas, {len(npcs)} NPCs, {len(quests)} missões, {len(pages)} páginas.")
if errors:
    print(f"\n{len(errors)} ERRO(S):")
    for e in errors:
        print("  - " + e)
    sys.exit(1)
print("Tudo consistente.")
