# 03 — Sistemas em Detalhe

Cada sistema: **objetivo · regras · entradas/saídas · dependências · progressão · testes**.
Fórmulas completas em [rule-engine.md](rule-engine.md).

---

## A — Personagem
- **Objetivo:** identidade mecânica de Asterion sem classes fixas.
- **Regras:** 5 atributos (0–10), 8 escolas (0–100), talentos a cada 60 pontos de escola, 5 especializações.
- **Entradas:** XP de escola (leitura, lançamento, preparo, colheita, observação, missões).
- **Saídas:** saúde/mana máximas, multiplicador de aprendizado, bônus de especialização, desbloqueio de cômodos.
- **Dependências:** Casa (Sala Ritual exige 2 escolas ≥ 20; Jardim exige Botânica ≥ 1).
- **Testes:** `tests/unit/test_character.gd`.

## B — Magia (8 escolas)
| Escola | Feitiços (nível) | Uso no mundo |
|--------|------------------|--------------|
| Botânica Arcana | Crescimento Rápido (0), Identificação de Propriedades (0), Sincronização com a Natureza (20) | acelera canteiros, regenera plantas silvestres, desperta a ponte de vinhas, revela propriedades, rega tudo |
| Alquimia | Dissolução Precisa (0), Estabilização (20), Transmutação de Essência (40) | +qualidade no próximo preparo, ignora 1 incompatibilidade, pedras → cristal |
| Magia Astral | Lume Estelar (0), Visão Noturna (10), *Projeção Astral (40)* | luz que acalma luméculas e revela marcas estelares; revela segredos |
| Runas | Círculo de Proteção (0), Marca de Retorno (10), *Barreira Persistente (40)* | canteiros não secam por 3 dias; teleporte para casa |
| Proteção | Escudo Pessoal (0), Limpeza Mágica (15), *Refúgio (40)* | anula esporos; purifica o Silêncio Cinzento |
| Transmutação | *Transmutação de Material (0)*, *Forma Alterada (20)*, *Replicação (40)* | planejados para Caverna Subterrânea |
| Ilusão | Véu (0), *Susto (20)*, *Ilusão de Ambiente (40)* | passar pelo Cogumelo sem ser notada |
| Elemental | Chama Controlada (0), Cristal de Gelo (10), Brisa Suave (0) | queima sarças, congela água, poliniza e dissipa bruma |

*Em itálico: definidos em dados, efeito previsto para regiões futuras (`implemented: false`).*

- **Aprendizado:** descoberta (ler) → compreensão 0–100% → maestria (uso) → combinação (8 receitas revelam feitiços de experimentação).
- **Clareza:** `SpellSystem.can_cast()` sempre devolve o motivo ("exige Magia Astral nível 10", "mana insuficiente: custa 16, você tem 9"…).
- **Testes:** `tests/unit/test_spells.gd`.

## C — Grimório
- Páginas (16) com leitura repetível até 5×, símbolos, pesquisas (O Desaparecimento de Ondina, O Silêncio Cinzento).
- Catálogo de plantas com propriedades **???** até serem descobertas; bestiário com anotações progressivas;
  intuições de experimentos; diário cronológico de descobertas e decisões.
- Barra de **conhecimento registrado** (completude).
- **Testes:** `tests/unit/test_grimoire.gd`.

## D — Alquimia e Fabricação
- 24 ingredientes × 5–7 propriedades (15 propriedades possíveis), 12 receitas, 5 técnicas (Moer, Aquecer, Mexer, Esfriar, Destilar).
- **Modo receita conhecida:** o grimório mostra exigências e técnica; botão "Usar esta técnica".
- **Modo experimentação:** o jogador mistura; o resultado ensina as propriedades despertas e, se falhar, explica por quê.
- Previsão na interface usa apenas o que já foi descoberto.
- Progressão: Alquimia 0–20 receitas básicas; Tintura Purificadora exige 5; Tinta Rúnica 10; maestria eleva a qualidade.
- **Testes:** `tests/unit/test_alchemy.gd` + `tools/data_validator.py --pares` (todas as receitas fabricáveis).

## E — Botânica e Ecologia
- 10 plantas cultiváveis, 9 canteiros (4/6/9 com melhorias), luz por posição (sol, meia-luz, sombra).
- Ações: plantar, regar, adubar (Adubo Vital), polinizar (Brisa Suave), Crescimento Rápido, Círculo de Proteção, colher, propagar (semente devolvida).
- Interface explica cada multiplicador (estação, luz, água, adubo, lua, maestria) e estima horas restantes.
- **Testes:** `tests/unit/test_garden.gd`.

## F — Exploração e Mundo
Ver [04-mundo.md](04-mundo.md). Portões de progressão espacial: Cogumelo (chá ou Véu), Sarças (fogo),
Riacho (ponte de vinhas ou gelo), Lagoa (gelo), marcas estelares (noite + luz), Portal (Ato II).

## G — NPCs e Facções
- 12 NPCs com aparência, personalidade, facção, rotina por horário, comércio e conhecimento.
- Diálogos com condições (missão, reputação, itens, bestiário, leitura) e efeitos.
- Indicador **!** quando o NPC tem algo novo a dizer.
- 6 facções; reputação muda com escolhas e libera opções.

## H — Propriedade
| Cômodo | Níveis | Efeito mecânico |
|--------|--------|-----------------|
| Biblioteca | 1–3 | +2%/+4% de compreensão por leitura |
| Laboratório | 1–3 | 3/4/4 espaços; +0,05 de qualidade por nível |
| Jardim | 0–3 | 0/4/6/9 canteiros |
| Sala Ritual | 0–2 | +10%/+20% de potência de feitiços |
| Dormitório | 1–2 | +20 de mana máxima ao acordar |
| Armazém | 1–3 | capacidade 40/80/160 de peso |

## I — Missões e Narrativa
8 missões no Ato I (3 principais, 4 secundárias, 1 investigação). Ver [05-narrativa.md](05-narrativa.md).
Missões são **dados**: objetivos por condição, desfechos por condição, alvo no minimapa e dica do Nimbus.
**Testes:** `tests/integration/test_act1_flow.gd` cobre todas as rotas (alquímica, contra-magia, atalho de Kael).

## J — Combate
Fora da V1 (proposta P1). Perigos ambientais existem (esporos do Cogumelo) e são resolvidos com conhecimento (Escudo, Unguento, Véu).

## K — Inventário e Economia
Pilhas com qualidade média, peso generoso, 5 categorias (ingrediente, poção, semente, ferramenta, artefato),
ferramentas com passivas (tesoura +1 colheita, regador rega tudo, amuleto lunar, lupa do bestiário).
Loja do Bento com compra, venda e pedido do dia.

## L — Interface e UX
- Botões ≥ 48 dp (56–64 px no tema), texto em 3 escalas, alto contraste, vibração opcional.
- HUD com multitoque real; Livro com 8 abas; todas as falhas explicadas em texto.
- Notificações coloridas por tipo (descoberta, missão, item, aviso, dica).
