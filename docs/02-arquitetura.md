# 02 — Arquitetura Técnica

## 1. Princípios

1. **Dados como fonte da verdade.** Números de design vivem em `data/*.json`; o código só aplica regras.
2. **Lógica pura separada da apresentação.** Sistemas (`src/scripts/{progression,magic,alchemy,botany,game,…}`)
   são `RefCounted` sem dependência de cena → testáveis em modo headless.
3. **Um orquestrador.** O autoload `Game` possui as instâncias dos sistemas e aplica regras que cruzam sistemas
   (recompensas, descobertas, consequências, tempo). Mundo e UI falam com o jogo **só** por `Game` e `EventBus`.
4. **Mundo gerado em código.** Terreno, vegetação, personagens e props são montados a partir de primitivas
   (sem assets externos), com malhas orgânicas (`OrganicMesh`) e materiais PBR/shaders próprios (`Toon`, `CharMat`). Modelos `.glb` podem substituí-los sem mudar a lógica.

## 2. Autoloads (`src/autoload/`)

| Autoload | Responsabilidade |
|----------|------------------|
| `EventBus` | Sinais globais (notificações, inventário, feitiços, missões, tempo, painéis). |
| `DataRegistry` | Carrega e indexa todos os JSON; consultas de nomes, cores, faixas. |
| `Settings` | Volume, texto, alto contraste, vibração, qualidade gráfica, câmera (`user://settings.cfg`). |
| `Game` | Estado do jogo e regras entre sistemas; relógio; buffs; save/load de estado. |
| `SaveManager` | JSON versionado + checksum + backup; salva ao pausar o app (Android). |
| `AudioManager` | Música com crossfade, ambiência, chuva, pool de efeitos. |

## 3. Sistemas (lógica pura)

| Classe | Arquivo | Sistema |
|--------|---------|---------|
| `CharacterStats` | `progression/character_stats.gd` | A — atributos, escolas, talentos, especializações |
| `SpellSystem` | `magic/spell_system.gd` | B — compreensão, recarga, custo, eficácia, motivos de falha |
| `Grimoire` | `magic/grimoire.gd` | C — páginas, catálogo, bestiário, intuições, pesquisas, diário |
| `AlchemyLab` | `alchemy/alchemy_lab.gd` | D — avaliação de misturas (estática, sem efeitos colaterais) |
| `Garden` | `botany/garden.gd` | E — canteiros e crescimento por hora |
| `WorldClock` | `game/world_clock.gd` | F — dia, estação, lua, clima determinístico |
| `QuestLog` | `game/quest_log.gd` | I — objetivos por condição, desfechos |
| `Conditions` | `game/conditions.gd` | Avaliador compartilhado (diálogos, missões, mundo) |
| `DialogueRunner` | `npc/dialogue_runner.gd` | G — árvores de diálogo com condições e efeitos |
| `House` | `game/house.gd` | H — cômodos, níveis, desbloqueios |
| `Inventory` | `inventory/inventory.gd` | K — pilhas com qualidade média, peso, moeda |

### Linguagem de dados (condições e efeitos)

Condições (E lógico): `flag`, `not_flag`, `quest_active`, `quest_done`, `quest_not_started`,
`objective_current`, `objective_done`, `has_item`, `item_quality`, `knows_spell`, `school`, `rep`,
`time`, `moon`, `page_read`, `ep`, `bestiary_notes`, `any` (OU), `not`.

Efeitos: `set_flag`, `clear_flag`, `start_quest`, `complete_quest`, `give_item`, `take_item`,
`give_ep`, `take_ep`, `rep`, `read_page`, `school_xp`, `open_shop`, `bestiary`, `research`,
`upgrade_room`, `notify`.

Designers criam missões, diálogos e consequências **sem programar**.

## 4. Mundo e apresentação

```
GameWorld (game_world.gd)
├── WorldEnvironment (céu em shader, névoa, glow) + DirectionalLight (sol/lua)
├── ValleyBuilder → terreno (ValleyTerrain), água (WaterBody), muralhas, MultiMesh de vegetação,
│                   cabana e estações, pontos de interesse, NPCActor, CreatureActor, Obstacle,
│                   HarvestNode, GardenPlot, Readable, StarMark
├── Player (CharacterBody3D + HumanoidModel + SpringArm3D)
├── Nimbus (NimbusModel)
└── HUD (CanvasLayer) → painéis modais
```

- **Interactable** é a base de tudo que se toca. O jogador foca o mais próximo à frente; feitiços
  chamam `on_spell(tags, result)` em todos os interativos no raio → cada objeto decide como reagir
  (fogo queima sarça, crescimento desperta vinha, luz revela marca…).
- **Tags de feitiço** (`grow`, `fire`, `ice`, `light`, `purify`, `wind`, `identify`…) desacoplam
  feitiço e mundo: um item (Essência Verdejante) também emite `grow`.

## 5. Entrada mobile

- `emulate_mouse_from_touch = true` → menus usam `Button` normal.
- HUD trata **toques reais** manualmente (multitoque): joystick flutuante à esquerda, câmera arrastando
  à direita, pinça para zoom, botões redondos desenhados (`RoundButton`) — andar e lançar ao mesmo tempo.
- Botão Voltar do Android fecha painéis; app em segundo plano salva automaticamente.
- Teclado/mouse no desktop: WASD, E (interagir), Q (lançar), 1–4 (espaços), Tab (livro), H (Nimbus).

## 6. Desempenho (alvo: 30–60 FPS em Snapdragon 680)

- Renderizador **Mobile**; sombras direcionais em 2 cascatas até 20–55 m conforme qualidade.
- Vegetação em **MultiMesh** (troncos, copas, cones, grama, flores, arbustos) → poucas draw calls.
- Partículas **CPUParticles3D** (compatíveis com GLES3).
- `scaling_3d_scale` 0,7 / 0,85 / 1,0 por nível de qualidade; densidade de grama 1400/3200/5600.
- Materiais e malhas cacheados (`Toon`, `CharMat`, `MeshKit`, `OrganicMesh`); peças estáticas de casas unidas por material (`MeshKit.batch`).
- Próximos passos (Fase 5): LOD por `visibility_range`, occlusion culling, bake de personagens em malha única.

## 7. Testes

| Suíte | Como rodar | O que cobre |
|-------|-----------|-------------|
| Unidade + integração | `godot --headless res://tests/test_runner.tscn` | 74 testes / ~1000 verificações: fórmulas, alquimia, botânica, magia, tempo, grimório, save, integridade de dados, **todas as rotas do Ato I** |
| Fumaça do mundo 3D | `godot --headless res://tests/smoke_world.tscn` | 44 verificações jogando no mundo real: joystick, atril, painéis, laboratório, diálogo, cogumelo, ponte, sarças, noite/Faísca, marca estelar, gelo, purificação, desmaio, save/load |
| Dados | `python3 tools/data_validator.py --pares` | Referências cruzadas e simulação do caldeirão |

CI: `.github/workflows/tests.yml` roda as três suítes a cada push.

## 8. Estrutura de pastas

Segue a estrutura do prompt mestre: `src/{autoload,scenes,scripts,resources}`, `assets/audio`,
`data/{spells,ingredients,plants,npcs,quests,world,recipes,items,lore}`, `tests/{unit,integration}`,
`tools/`, `docs/`.
