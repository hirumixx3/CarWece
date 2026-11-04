# Correção — testes Kotlin de contrato gráfico (CI)

Os 6 testes que falhavam no `testDebugUnitTest` (GraphicsContractTest e
BattleGraphicsContractTest) não eram erros do jogo: eram **números fixos
da época dos 81 carros** dentro dos testes Android. Desde a v1.3.0 o
elenco tem 106 carros, e os índices de malha derivam do elenco
(`GpuMeshId` no Dart já fazia isso; os testes Kotlin, não):

- total de objetos 264 → 339 (corrida) e 324 → 399 (batalha);
- rodas 171–251 → 221–326; escudo 84 → 109; fumaça 88 → 113;
  gelo 257 → 332; base das malhas de batalha 264 → 339.

Correção aplicada nos testes: os índices agora são **derivados do
tamanho do elenco presente no próprio payload** (objetos = 3 × carros +
21), com as fórmulas espelhando o `GpuMeshId`/`BattleMesh` do Dart —
se o elenco crescer de novo, os testes acompanham sozinhos.

Validação: gerei os payloads reais (`create.bin`/`battle.bin`) com o
código atual e conferi, uma a uma, todas as asserções dos testes
corrigidos (contagens, transparência por material, sombras das barras de
vida, índices no quadro) — todas passam. Os 280 testes Dart e o
`flutter analyze` já estavam verdes no CI.
