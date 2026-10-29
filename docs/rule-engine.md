# Rule Engine — Documento Central de Regras

> **Regra de ouro:** nenhuma mudança de regra sem consentimento explícito do produtor.
> Toda alteração aprovada é registrada aqui, com data e impacto.

Legenda de status: **[FATO]** verificado no código/dados · **[DECIDIDO]** aprovado pelo produtor ·
**[PROPOSTA]** implementado como recomendação, aguardando aprovação · **[HIPÓTESE]** precisa de validação em dispositivo/jogador.

---

## 1. Decisões aprovadas pelo produtor

| # | Decisão | Origem |
|---|---------|--------|
| D1 | Stack: **Godot 4.7.2 + GDScript** | Prompt mestre |
| D2 | Plataforma: **Android 8.0+** (API 26) | Prompt mestre |
| D3 | Estilo **3D cartoon/stylized** | Prompt mestre |
| D4 | Protagonista: **Asterion** | Pedido do produtor |
| D5 | Liberdade criativa total para personagens, cenários e sons | Pedido do produtor |

## 2. Propostas implementadas (aguardando aprovação)

O prompt pedia que a Fase 1 respondesse perguntas antes de programar. Como o produtor deu
liberdade criativa, as respostas abaixo foram **assumidas como recomendação** e já estão no
protótipo. Qualquer uma pode ser revertida — os impactos estão listados.

| # | Pergunta do prompt | Proposta adotada | Por quê | Impacto se mudar |
|---|--------------------|------------------|---------|------------------|
| P1 | Combate? | **Inexistente na V1.** Criaturas são "resolvidas" por conhecimento (chá, véu, luz). Há só perigo ambiental (esporos) com desmaio sem perda de itens. | Princípio 3.3 ("nenhuma rota força combate") e foco em descoberta. | Adicionar combate exige sistema de dano, IA hostil e balanceamento de saúde (Sistema J). |
| P2 | Regiões na V1 | **5** (Vale dos Sussurros jogável no protótipo; Floresta Encantada, Picos da Lua, Lagoa Espelhada, Ruínas Antigas planejadas). 3 futuras. | Recomendação do prompt (4-5). | `data/world/regions.json`. |
| P3 | NPCs principais | **12** (8 já presentes no Vale). | Recomendação (12-15). | `data/npcs/npcs.json`. |
| P4 | Renderizador | **Mobile** (Vulkan) em vez de Forward+. Fallback automático para OpenGL ES 3 (Compatibility) em aparelhos sem Vulkan. | Forward+ não é recomendado para Android; Mobile tem melhor desempenho em Snapdragon 680/Helio G35. | `project.godot` → `rendering_method`. |
| P5 | Persistência | **JSON versionado em `user://`** com checksum MD5 e backup automático, em vez de SQLite. | SQLite exige GDExtension de terceiros; JSON é nativo, legível e suficiente para a V1. | `src/autoload/save_manager.gd` (migração prevista em `migrate()`). |
| P6 | Ciclo dia/noite | **30 min reais = 1 dia** de jogo. | O prompt tem conflito (Sistema E: 1 h = 1 dia; Sistema F: 30 min = 1 dia). Adotado o do Sistema F. | `WorldClock.REAL_SECONDS_PER_DAY`. Afeta todo o ritmo de botânica. |
| P7 | Fases lunares | Ciclo de **8 dias** (1 fase por dia). | Lua cheia a cada 8 dias dá eventos frequentes sem banalizar. | `WorldClock.MOON_CYCLE`. |
| P8 | Moeda | **Essência Primária (EP)**. | Termo do prompt. | — |
| P9 | Título | **The Witched Grove — Asterion e o Silêncio Cinzento**. | Nome do repositório + mistério central. | Marketing/loja. |
| P10 | Idioma | PT-BR completo; EN/ES na Fase 6. | Prompt. | Textos estão em JSON → prontos para tradução. |

## 3. Fórmulas oficiais

### Personagem (Sistema A)
- **R-A1** Atributos 0–10, começam em 5: Intelecto, Sentido Arcano, Destreza, Resistência, Perspicácia.
- **R-A2** Saúde máx. = `100 + Resistência × 10` · Mana máx. = `50 + Intelecto × 5 (+ bônus do dormitório)`.
- **R-A3** Regeneração passiva: mana `0,5/s`, saúde `0,25/s` (sem combate, sempre ativa).
- **R-A4** Multiplicador de aprendizado de uma escola = `0,75 + (média dos atributos afins / 10) × 0,5` (5 → ×1,0; 10 → ×1,25).
- **R-A5** Escolas 0–100. A cada **60 pontos** somados em todas as escolas: **+1 ponto de talento** (+1 em um atributo).
- **R-A6** Especialização: **40+ em duas escolas relacionadas** (5 especializações em `schools.json`).
- **R-A7** Saúde 0 → desmaio: acorda em casa às 07:00 com 50% de saúde e mana. **Nenhum item é perdido.**

### Magia (Sistema B)
- **R-B1** Ler a página de um feitiço: **+10% de compreensão por leitura**, até 5 leituras (+2%/+4% com Biblioteca nível 2/3; +5% com Guardiã do Saber).
- **R-B2** Castável com **≥10%** de compreensão **e** nível de escola ≥ `level_required`.
- **R-B3** Cada lançamento: **+5%** de compreensão (até 100%) e **+2** na escola (× multiplicador).
- **R-B4** Eficácia = `0,5 + compreensão/200` (10% → 0,55; 100% → 1,0). Afeta duração e intensidade.
- **R-B5** Maestria (100%): custo de mana −20%.
- **R-B6** Lua cheia: Magia Astral +20%; lua nova: Ilusão +20% (+10% com Amuleto da Lua). Sala Ritual: +10% por nível.
- **R-B7** Feitiços com `unlock_method = experimentation` se revelam ao descobrir **8 receitas**.

### Grimório (Sistema C)
- **R-C1** Tudo que não foi descoberto aparece como **???**.
- **R-C2** Propriedades de ingredientes são reveladas na **1ª obtenção (2)** e depois conforme `reveal_schedule = [2,3,3,4,4,5]`, por experimentação, por Identificação de Propriedades ou por polinização.
- **R-C3** Completude = páginas + receitas + propriedades (peso 0,25) + anotações do bestiário (peso 0,5).

### Alquimia (Sistema D)
- **R-D1** Uma propriedade **desperta** quando aparece em **≥2 ingredientes** da mistura.
- **R-D2** Pares incompatíveis despertos **se anulam**: Calor×Frio, Luz×Sombra, Estabilidade×Volatilidade, Claridade×Turvo. (Estabilização ignora o primeiro par.)
- **R-D3** Receita escolhida = a **mais específica** cujas exigências estão despertas, sem propriedade proibida desperta e com nível de Alquimia suficiente.
- **R-D4** Qualidade = `média(qualidade dos ingredientes) × fator de técnica × (0,7 + Alquimia/200) + bônus`, limitada a **[0,3; 1,5]**.
- **R-D5** Fator de técnica: sequência exata 1,0 · mesmos passos em outra ordem 0,85 · algum passo certo 0,7 · nenhum 0,55.
- **R-D6** Faixas: Rústica < 0,6 ≤ Comum < 0,9 ≤ Refinada < 1,15 ≤ Primorosa.
- **R-D7** Falha gera **Mistura Turva** + **intuição explicativa** registrada no grimório. Cada ingrediente entra 1 vez; mínimo 2; máximo = espaços do laboratório (3/4/4).

### Botânica (Sistema E)
- **R-E1** Crescimento/hora = `1 / (dias × 24) × estação × luz × água × adubo × lua × maestria`.
- **R-E2** Estação ideal ×1,25 · vizinha ×1,0 · oposta ×0,5. Luz exata ×1,0 · adjacente ×0,8 · oposta ×0,6.
- **R-E3** Água evapora 0,5/dia; abaixo de 0,2 o crescimento cai para ×0,25. Chuva/neve regam tudo. Círculo de Proteção impede evaporação por 3 dias.
- **R-E4** Adubo Vital ×1,5 até a colheita · plantas lunares +25% na lua cheia · maestria `1 + Botânica/400`.
- **R-E5** Rendimento = `base + ⌊Botânica/35⌋ + ferramentas + especialização`. Toda colheita devolve 1 semente (propagação).
- **R-E6** Qualidade da colheita = `(0,75 + 0,25 × cuidado) × (0,9 + Botânica/250) × (0,94 + Destreza × 0,012)` (+0,1 se polinizada), limitada a [0,5; 1,5].
- **R-E7** Plantas silvestres rebrotam no dia seguinte — ou na hora, com Crescimento Rápido.

### Tempo e clima (Sistema F)
- **R-F1** 30 min reais = 1 dia · 5 dias por estação · 20 dias por ano · lua de 8 dias.
- **R-F2** Clima **determinístico por dia** (sem aleatoriedade desnecessária). Probabilidades por estação em `WorldClock.WEATHER_TABLE`. Dia 1 sempre limpo.
- **R-F3** Noite: 19:30–05:30. Luméculas, Lyra e marcas estelares só existem à noite; Kael só ao entardecer (17h–23h).

### Reputação (Sistema G)
- **R-G1** −100 a +100 por facção. Faixas: Inimiga, Desconfiada (−50), Neutra (−10), Amigável (20), Aliada (50), Irmã de Alma (85).
- **R-G2** NPCs lembram decisões via flags (ex.: `musgo_corrompido` muda o diálogo do Guardião para sempre).

### Economia (Sistema K)
- **R-K1** Preço de compra: valor × 1,0 (sementes/ferramentas) ou × 1,5 (demais). Venda: valor × (0,6 + 0,4 × qualidade); sementes/ferramentas 50%. **Nunca há arbitragem** (venda < compra).
- **R-K2** Pedido do dia (Bento): 50 EP + 2 de reputação com a Aldeia Vime.
- **R-K3** Progresso **nunca** é bloqueado por moeda: toda missão do Ato I tem rota sem compra.

## 4. Termos oficiais

| Termo | Significado |
|-------|-------------|
| Éter | Camada dimensional de onde vem a magia. |
| Silêncio Cinzento | Drenagem de Éter que tira a cor e a voz das coisas vivas. |
| Os Primeiros | Civilização antiga que dominava a magia; deixaram ruínas e marcas estelares. |
| Essência Primária (EP) | Moeda. |
| Despertar (alquimia) | Propriedade ativa numa mistura (presente em ≥2 ingredientes). |
| Compreensão | Percentual de conhecimento de um feitiço. |
| Lumécula | Espírito de luz que dança sobre águas paradas. |
| Familiar | Nimbus, o gato-mariposa — sistema de dicas. |

## 5. Sistemas e estado

| Sistema | Estado no protótipo |
|---------|---------------------|
| A Personagem | ✅ completo (atributos, escolas, talentos, especializações) |
| B Magia | ✅ 24 feitiços definidos; 16 com efeito na V1, todos aprendíveis no Vale (15 por páginas, 1 por experimentação) |
| C Grimório | ✅ páginas, catálogo, receitas, bestiário, intuições, símbolos, pesquisas, diário |
| D Alquimia | ✅ propriedades, anulação, técnica, qualidade, experimentação |
| E Botânica | ✅ 9 canteiros, estação/luz/água/adubo/lua, polinização, propagação |
| F Mundo/Tempo | ✅ Vale completo; 🔜 4 regiões V1 |
| G NPCs/Facções | ✅ 8 NPCs no Vale com rotina e memória; 6 facções |
| H Casa | ✅ 6 cômodos com níveis e efeitos mecânicos |
| I Missões | ✅ 8 missões, 3 com múltiplos desfechos morais |
| J Combate | ⛔ fora da V1 (P1) |
| K Inventário/Economia | ✅ peso, qualidade, loja, pedido do dia |
| L Interface | ✅ HUD mobile multitoque, livro, painéis, acessibilidade |

## 6. Problemas conhecidos

1. **Modelos procedurais**: personagens têm ~25–40 malhas cada (mais draw calls que um glTF único de ~2000 tris). Aceitável no protótipo; substituir por modelos `.glb` na Fase 4.
2. **Rotina de NPCs** usa caminhada em linha reta (sem navmesh). Fase 3: `NavigationRegion3D`.
3. **Capturas de tela automatizadas** usam o renderizador Compatibility (llvmpipe); cores no aparelho (Mobile/Vulkan) ficam um pouco mais saturadas.
4. **Gelo**: ao derreter com a protagonista sobre a água, ela volta à última margem segura (intencional, mas pode surpreender).
5. Ao fechar o jogo em modo headless há aviso de playbacks de áudio não liberados (inofensivo).

## 7. Registro de alterações

| Data | Alteração | Aprovado por |
|------|-----------|--------------|
| 2026-10-29 | Criação do documento e do protótipo do Ato I com as propostas P1–P10. | Pendente |
