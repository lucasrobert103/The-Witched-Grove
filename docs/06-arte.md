# 06 — Direção de Arte e Áudio

## 1. Paleta

| Função | Cores |
|--------|-------|
| Primária | Ouro `#f3c74f` · Verde floresta `#3f8f55` · Púrpura mágico `#7a4fc4` |
| Secundária | Branco lunar `#f6f1ff` · Cinza pedra `#9a96a8` · Azul-marinho `#1b1430` |
| Acentos | Âmbar `#e2a93b` · Esmeralda `#7dffa0` · Rosa opalescente `#ff9fb2` |
| Silêncio Cinzento | Dessaturação para `#8d8f8a` / `#7b7a80` |

## 2. Estilo 3D — realista estilizado

Visual de jogo atual, tudo gerado em código (sem assets externos):

- **Materiais PBR** (Burley + GGX) com **microdetalhe procedural** em triplanar conforme a superfície
  (`Toon.SURFACES`): madeira, pedra, reboco, telhado, folha, metal, terra, palha, tecido. O contorno cartoon foi aposentado.
- **Malhas orgânicas** (`OrganicMesh`): corpos por seções (loft), tubos ao longo de curvas, cabeça esculpida,
  abas de chapéu e **caixas chanfradas** (as quinas pegam luz). Primitivas com o dobro de segmentos.
- **Iluminação**: luz ambiente e reflexos vindos do céu, tonemapping ACES, brilho suave, névoa com
  perspectiva aérea, sombras suaves com 4 cascatas (qualidade alta).
- **Vegetação**: copas irregulares com tufos de folhas (relevo, sombra interna e translucidez), pinheiros
  em camadas com galhos caídos, troncos com raízes, grama com lâminas curvas, vento em rajadas.
- **Terreno**: manchas de cor em grande escala, grão fino, relevo triplanar, rocha exposta nas encostas.
- **Água**: ondulação com normal map, reflexo do céu com fresnel, cor por profundidade e espuma na margem.
- **Arquitetura**: casas em enxaimel com fundação de pedra, mãos-francesas, janelas com moldura, cruz,
  floreira e venezianas, porta de tábuas, telhado com fiadas de telhas, oitões e chaminé.
- **Desempenho**: peças estáticas de cada casa são unidas por material (`MeshKit.batch`); cores por vértice
  convertidas de sRGB para linear nos shaders; qualidade baixa desliga o microdetalhe.
- Céu em shader próprio: gradiente por hora, sol com halo, lua com fase, estrelas e **nuvens volumosas** (fbm).

## 3. Personagens (construídos em `HumanoidModel` a partir de `npcs.json → appearance`)

Proporções reais (~6,5 cabeças, 1,62 m), corpo contínuo, braços com cotovelo e mãos com dedos,
pernas com joelho e tornozelo. **Rosto** esculpido com olhos, sobrancelhas, boca, blush e sardas pintados
em alta definição no shader (`face.gdshader`), com piscar, olhar e fala por instância. **Pele** com
dispersão subsuperficial falsa. **Cabelo** em mechas (fitas afiladas ao longo de curvas) com fios e brilho
anisotrópico; mechas, saias e capas **balançam** com o movimento (sway por instância).
Parâmetros: pele, cabelo (curto, longo, trança, coque, cacheado, maria-chiquinha, careca), barba, figura,
roupa (manto, vestido, casaco, túnica, casaco-vestido), cores, chapéu, altura, porte, idade, olhos e
acessórios (cachecol, cajado, varinha, lanterna, estrelas, sardas, xale, capinha, bengala, avental, bolsa,
cinto, alça, luvas, botas altas, óculos, livro).

**Asterion (estilo anime, `"style": "anime"`):** pele clara `#f2cdb0`, cabelo loiro-mel `#d9b46e`
em **duas marias-chiquinhas longas** que balançam com o passo, olhos âmbar grandes com brilho duplo
(estilo anime, cílios e sobrancelhas suaves), **chapéu de bruxa de aba larga** marrom `#4a3626` com faixa
laranja e berloque pendurado, **casaco-vestido** marrom `#6e5340` com forro vinho, **capinha** sobre os
ombros, cinto, alça cruzada, bolsa, luvas, **botas altas**, lanterna na cintura com luz quente e
**varinha de salgueiro** com ponta luminosa (de onde saem os feitiços). Meia-calça escura e botas de couro marrom.

Animação procedural: respiração, piscar, passos, balanço do manto, braços, mola na ponta do chapéu,
nas marias-chiquinhas, no berloque e na lanterna, aceno, fala (aceno de cabeça), lançamento (braço erguido + flash do cristal), modo fantasma (Véu), e a Metamorfose troca o modelo por um gato (`CatModel`).

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
