# CarWece v1.5.1 — Correções gráficas sobre a base 1.5.0

Base: v1.5.0 restaurada (com workflows sem verificações de artefato e
sem o poder Propulsor). Esta versão porta **somente as correções de
bugs gráficos** que tinham sido feitas na antiga v1.6.0 — sem trazer
nada do que pesava:

## Correções portadas
- **Brilhos furados**: a curva de contraste rodava em HDR e ficava
  negativa nos brilhos mais fortes, abrindo buracos pretos/magenta no
  reflexo da pintura. Agora a gradação roda em espaço de tela (0..1).
- **Normais tortas**: objetos com escala não uniforme (vigas, fumaça,
  explosões) tinham a iluminação inclinada; as normais agora usam a
  matriz inversa-transposta.
- **Textura "andando"**: o ruído procedural dos materiais usava
  coordenadas do mundo e rastejava sobre pintura, pneus e acessórios
  em movimento; agora usa coordenadas do próprio objeto.
- **Sombra cortada em quadrado**: onde a câmera de sombra acabava, a
  sombra sumia de uma vez; agora ela desvanece na borda.
- **Vidro ignorava sombra**: para-brisas brilhavam igual no sol e na
  sombra; agora respeitam o mesmo fator de sombra dos outros materiais.
- **Transparências fora de ordem**: fumaça e escudos misturavam na
  ordem do pacote; os transparentes agora desenham de trás para
  frente, e o mundo transparente ficou fora do passe de sombra.

## O que ficou de fora de propósito (custo de desempenho)
- Backend Vulkan forçado no manifesto — **não** voltou.
- Filtro de sombra 5×5 no ALTA — **não** voltou (segue o 3×3 da 1.5.0).
- MSAA 2× no MÉDIA — **não** voltou.

Simulação e conteúdo idênticos à base: `onlineContent` continua
`carwece-brasil-3.2-sem-propulsor`. pubspec: **1.5.1+8**.
