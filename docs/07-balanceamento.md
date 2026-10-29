# 07 — Balanceamento, Progressão e Economia

Todas as fórmulas estão em [rule-engine.md](rule-engine.md). Aqui: metas, curvas e justificativas.

## 1. Ritmo

| Marco | Tempo real estimado |
|-------|---------------------|
| Primeiro feitiço | 1–2 min (atril na varanda) |
| Primeira poção | 5–8 min |
| Primeira colheita do jardim | ~1 dia de jogo (30 min) ou menos com Crescimento Rápido / dormir |
| Guardião purificado | 40–70 min |
| Fim do Ato I | 1,5–2 h |

Dormir à noite avança até 07:00 e processa o jardim → o jogador controla o ritmo.

## 2. Curva de escolas

Ganho típico por ação (×multiplicador de atributos):
leitura +2 · lançamento +2 · colheita silvestre +1 · plantio +1 · colheita do jardim +2 ·
preparo +4 a +12 (×1,5 se receita nova) · falha +1 · observação +1 · missões +3 a +10 · obstáculos +4.

Meta do Ato I: Botânica ~20, Alquimia ~15, outras 5–12 → 1 talento e a Sala Ritual perto de despertar.
Especialização (40+40) é objetivo do Ato II.

## 3. Feitiços — custos

| Faixa de nível | Mana | Recarga |
|----------------|------|---------|
| 0 (básicos) | 8–20 | 2–10 s |
| 10–20 | 16–30 | 6–20 s |
| 40 | 35–50 | 30–300 s |

Mana inicial 75 e regeneração 0,5/s → ~5 feitiços básicos seguidos; esvaziar a mana nunca trava o
progresso (regenera em ~2,5 min ou dormindo).

## 4. Alquimia

- Ingredientes comuns compartilham propriedades frequentes (Vitalidade, Calma, Claridade) → receitas básicas fáceis de **descobrir por acaso**.
- Receitas avançadas exigem 3 propriedades (Tintura, Tinta Rúnica, Essência Verdejante) → planejamento e ingredientes raros.
- Proibições e anulações criam "quebra-cabeças de química" explicados pela intuição.
- `python3 tools/data_validator.py --pares` lista quantas combinações produzem cada receita (ex.: Tônico 221, Tintura 113, Essência Verdejante 62).

## 5. Economia (EP)

| Entrada | Valor |
|---------|-------|
| Vender plantas | 3–55 EP |
| Vender poções | 24–160 EP (× qualidade) |
| Missões | 60–220 EP |
| Pedido do dia | 50 EP |

| Saída | Valor |
|-------|-------|
| Sementes | 15–100 EP |
| Ferramentas | 150–260 EP |
| Melhorias da casa | 500–1800 EP |
| Ingredientes na loja | valor × 1,5 |

- Começo: 120 EP. Ato I rende ~800–1100 EP → 1 melhoria + 1 ferramenta (escolhas reais).
- **Nunca há arbitragem:** venda < compra para qualquer item.
- **Progresso nunca bloqueado por moeda:** cada missão tem solução com ingredientes silvestres.

## 6. Qualidade

- Ingredientes silvestres: 0,85 + Destreza × 0,03 (Destreza 5 → 1,0).
- Jardim bem regado e Botânica alta → até ~1,3.
- Poção Refinada (≥0,9) exige técnica certa **ou** bons ingredientes + Alquimia; Primorosa (≥1,15) exige ambos + Dissolução Precisa ou melhorias.

## 7. Hipóteses a validar com jogadores [HIPÓTESE]

1. 30 min por dia é confortável no mobile? (alternativa: 20 min)
2. 5 leituras por página é repetitivo? (alternativa: 3 leituras de +15%)
3. Peso inicial 40 é suficiente sem frustrar?
4. O empurrão do Cogumelo (6 de dano) é perceptível sem punir?
