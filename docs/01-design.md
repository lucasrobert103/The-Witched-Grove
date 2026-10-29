# 01 — Game Design Document (GDD)

**Título:** The Witched Grove — *Asterion e o Silêncio Cinzento*
**Gênero:** RPG 3D de bruxaria, exploração e descoberta (sem combate na V1)
**Plataforma:** Android 8.0+ (paisagem) · Godot 4.7.2 + GDScript
**Público:** 12+ · jogadores de *cozy games*, RPGs de exploração e jogos de crafting
**Sessão típica:** 10–30 min (um dia de jogo = 30 min reais)

---

## 1. Pitch

> Sua mestra sumiu na noite do eclipse. O bosque está perdendo a cor. Você tem um grimório
> pela metade, um caldeirão herdado e um gato-mariposa convencido. Estude, experimente,
> cultive e escolha — porque magia, aqui, é **conhecimento**, não espada.

## 2. Pilares

1. **Conhecimento é progressão.** O jogador sente que ficou melhor *porque aprendeu algo*: ler, reler,
   experimentar e observar revelam feitiços, propriedades, receitas e segredos.
2. **Sistemas que conversam.** Planta → propriedade → poção → obstáculo → página → feitiço → nova área.
3. **Magia resolve o mundo.** Fogo paciente queima sarças, vinhas viram pontes, gelo vira caminho,
   luz estelar revela marcas dos Primeiros, chá acalma criaturas.
4. **Escolhas coerentes.** Atalhos têm preço (o Pó Cinzento de Kael), e os NPCs lembram.
5. **Clareza sem simplificar.** Toda falha explica o porquê; toda multiplicação aparece na interface.

## 3. Loop principal

```
          ┌───────── explorar o Vale (dia/noite, clima) ─────────┐
          │                                                       ▼
   ler páginas ──► aprender feitiços ──► usar feitiços no mundo ──► abrir caminhos / segredos
          ▲                                     │                            │
          │                                     ▼                            ▼
   descobrir receitas ◄── experimentar no caldeirão ◄── colher e cultivar ◄── ingredientes novos
          │
          └──► missões e decisões ──► reputação ──► conhecimento exclusivo
```

**Micro-loop (1–3 min):** colher → ver propriedades → misturar → anotar resultado.
**Loop do dia (30 min):** plantar/regar de manhã, explorar à tarde, luméculas e estrelas à noite, dormir e salvar.
**Macro-loop (horas):** completar o Ato, especializar-se, melhorar a casa, abrir regiões.

## 4. Protagonista — Asterion

Aprendiz de Ondina Vael. Curiosa, teimosa, incapaz de passar por uma planta sem perguntar o nome.
Pele morena, cabelo lavanda-prateado em trança longa, olhos âmbar enormes, sardas, manto púrpura
com estrelas douradas, chapéu de bruxa com ponta torta e estrela, cachecol turquesa e cajado com
cristal de ametista que brilha ao lançar feitiços.

**Familiar:** Nimbus, gato-mariposa de pelo-nuvem e asas lavanda. É o sistema de dicas do jogo
(botão "Nimbus"): aponta o próximo passo, a direção e, à noite, lembra de acender o Lume.

## 5. Especializações (sem "melhor rota")

| Rota | Escolas | Fantasia |
|------|---------|----------|
| Criadora de Poções | Alquimia + Botânica | Caldeirão e jardim impecáveis |
| Guardiã do Saber | Runas + Proteção | Escudos longos, leitura mais profunda |
| Investigadora Astral | Astral + Ilusão | Segredos vistos de longe, Lume duplo |
| Teórica Transmutadora | Transmutação + Alquimia | Toda falha vira intuição |
| Tecelã dos Elementos | Elemental + Proteção | Feitiços elementais mais baratos |

Nenhuma rota exige combate. Toda missão do Ato I tem pelo menos duas soluções por escolas diferentes.

## 6. Escopo da V1 (proposta — ver rule-engine P1–P10)

| Item | V1 | Protótipo atual |
|------|----|-----------------|
| Regiões | 5 | 1 completa (Vale dos Sussurros) + 4 sinalizadas |
| NPCs principais | 12 | 8 no Vale (+4 definidos) |
| Feitiços | 24 (3 por escola) → 50+ na Fase 4 | 24 definidos, 16 funcionais |
| Ingredientes | 24 → 30+ | 24 |
| Receitas | 12 → 20+ | 12 |
| Missões | 20 | 8 (Ato I) |
| Combate | não | não |
| Horas de jogo | 6+ | ~1,5–2 h (Ato I) |

## 7. Telas (Sistema L)

Menu principal · HUD (vida, mana, EP, relógio lunar, clima, minimapa, rastreador, joystick, ações) ·
Livro (Grimório, Inventário, Missões, Escolas, Mapa, Casa, Diário, Opções) · Laboratório · Jardim ·
Loja · Diálogo · Leitura · Dormitório · Intro narrativa.

## 8. Monetização (para discussão futura — não implementada)

Recomendação: **premium** (compra única) ou **demo grátis + desbloqueio do jogo completo**.
Evitar energia/tempo de espera pago — contradiz o pilar "conhecimento é progressão".
Cosméticos (chapéus, cores de manto, temas do grimório) seriam compatíveis com os pilares.

## 9. Documentos relacionados

[02 Arquitetura](02-arquitetura.md) · [03 Sistemas](03-sistemas.md) · [04 Mundo](04-mundo.md) ·
[05 Narrativa](05-narrativa.md) · [06 Arte](06-arte.md) · [07 Balanceamento](07-balanceamento.md) ·
[Rule Engine](rule-engine.md)
