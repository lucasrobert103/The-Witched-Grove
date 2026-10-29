# 06 — Direção de Arte e Áudio

## 1. Paleta

| Função | Cores |
|--------|-------|
| Primária | Ouro `#f3c74f` · Verde floresta `#3f8f55` · Púrpura mágico `#7a4fc4` |
| Secundária | Branco lunar `#f6f1ff` · Cinza pedra `#9a96a8` · Azul-marinho `#1b1430` |
| Acentos | Âmbar `#e2a93b` · Esmeralda `#7dffa0` · Rosa opalescente `#ff9fb2` |
| Silêncio Cinzento | Dessaturação para `#8d8f8a` / `#7b7a80` |

## 2. Estilo 3D

- **Cel shading nativo** (`DIFFUSE_TOON` + `SPECULAR_TOON`) com **rim light** e **contorno por casco invertido** em personagens e props.
- Proporções fantásticas: cabeças grandes (~1/3 da altura), olhos com íris, pupila e dois brilhos, sardas, bochechas rosadas.
- Silhuetas legíveis em tela pequena: chapéus marcantes (bruxa, capuz, palha, coroa de flores, óculos de alquimista).
- Vegetação exuberante em MultiMesh com shader de vento; copas com borda iluminada; outono salpicado de laranja.
- Céu em shader próprio: gradiente por hora, sol, lua com fase, estrelas cintilantes, nuvens em faixas.
- Água cartoon com espuma animada e modo **congelado** (Cristal de Gelo).

## 3. Personagens (construídos em `HumanoidModel` a partir de `npcs.json → appearance`)

Parâmetros: pele, cabelo (curto, longo, trança, coque, cacheado, careca), barba, roupa (manto, vestido,
casaco, túnica), cores, chapéu, altura, porte, idade, olhos e acessórios (cachecol, cajado, estrelas,
sardas, xale, bengala, avental, bolsa, óculos, livro).

**Asterion:** pele `#a8704e`, cabelo lavanda `#cbb8f2` em trança com laço turquesa, olhos âmbar,
manto `#4b2a8a` com estrelas douradas, chapéu `#3a2068` de ponta torta com estrela, cajado com ametista.

Animação procedural: respiração, piscar, passos, balanço do manto, braços, mola na ponta do chapéu e
na trança, aceno, fala (aceno de cabeça), lançamento (braço erguido + flash do cristal), modo fantasma (Véu).

**Orçamento (Fase 4):** substituir por `.glb` de ~2000 tris/NPC mantendo as mesmas cores e silhuetas.

## 4. Áudio (100% procedural — `tools/gen_audio.py`)

| Faixa | Descrição |
|-------|-----------|
| `tema_dia` | Ré maior, 84 BPM: harpa (Karplus-Strong) em arpejos, flauta com vibrato, pad suave |
| `tema_noite` | Lá menor dórico, 66 BPM: sinos FM, pad escuro, melodia de estrelas |
| `tema_menu` | Valsa em Mi maior: caixinha de música + harpa |
| `amb_floresta` | Vento filtrado + pássaros (varreduras FM) |
| `amb_noite` | Grilos em três vozes + corujas + brisa |
| `amb_chuva` | Chuva com gotas aleatórias |

29 efeitos: UI, passos, colheita, água, moedas, página, descoberta, missão, preparo (sucesso/falha),
um som por família de feitiço (fogo, crescimento, luz, gelo, vento, escudo, véu, purificação, teleporte),
resmungo do Cogumelo, trinado de calma, sino das luméculas, descanso.

Todas as músicas e ambiências são **loops perfeitos** (reverberação circular).
