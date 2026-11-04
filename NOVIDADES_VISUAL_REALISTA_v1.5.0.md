# CarWece 1.5.0+7 — Transformação visual: acabamento realista

O visual inteiro do jogo foi refeito na camada de renderização — luz,
materiais, cores e proporções — para o mundo em miniatura ler como
fotografia de jogo de corrida moderno, não como brinquedo de plástico.
Direção de arte própria; nenhum asset de terceiros.

## Shader principal (assets/shaders/scene.frag)
- **Grade fotográfica global** aplicada a toda a cena 3D: dessaturação
  suave (0,86), curva em S de contraste, split-tone (sombras frias,
  altas-luzes quentes) e exposição reajustada sobre o ACES que já existia.
- **Luz de preenchimento (bounce)**: preenchimento direcional suave a
  partir do azimute oposto ao sol, tonalizado pelo céu — os lados em
  sombra mantêm forma em vez de achatar.
- **Pintura automotiva de verdade**: material `paint` com roughness 0,12
  e base dielétrica (metal 0,22) — leitura de verniz/clearcoat.
- **Asfalto**: material `track` fosco e gasto (roughness 0,52–0,80 com
  manchas de desgaste), em vez de plástico brilhante.
- **Plásticos** do cenário com roughness maior e variação, menos "brilho
  de brinquedo".

## Paleta das pistas (gpu_mesh.dart)
- Asfalto cinza-grafite `0xff3f444b` no lugar do laranja plástico;
  verso da pista grafite escuro. O laranja continua só como **acento de
  corrida** nos trilhos/guard-rails, mais profundo e queimado.
- Faixas de pista e zebras de borda em branco quente; setas de direção
  em teal dessaturado; chevrons de curva mantidos.

## Proporções dos carros (car_mesh.dart)
- **Passe de postura** aplicado a todos os 106 carros: carroceria 3,5%
  mais larga e teto/capô rebaixados acima da linha de cintura (~9% de
  compressão progressiva) — silhueta de esportivo em escala em vez de
  bloco alto de brinquedo. Normais renormalizadas; a física usa dimensões
  fixas próprias e **não muda** (dirigibilidade idêntica).

## Luz da cena (RushGLRenderer.kt)
- Sol mais baixo e inclinado (sombras mais longas e dramáticas), cor do
  sol mais intensa e quente, céu e cor de fundo em azul-aço fotográfico.

## Versão e online
`1.5.0+7`; `onlineContent` = `carwece-brasil-3.2-realista`.
Observação: o contrato do projeto de "sem neblina" (ar interno limpo)
foi mantido — o realismo vem de luz, material, cor e proporção.
