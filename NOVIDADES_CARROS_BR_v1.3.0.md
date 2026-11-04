# CarWece 1.3.0+5 — +25 carros brasileiros (81 → 106)

## Novos carros (bodies 81–105, coleção NACIONAIS)
Volkswagen Kombi, Volkswagen Variant, Volkswagen Karmann-Ghia,
Chevrolet Caravan, Chevrolet Diplomata, Chevrolet Astra GSI,
Chevrolet Vectra GSI, Chevrolet Corsa GSI, Fiat Tipo 16V, Fiat Brava HGT,
Ford Ka XR, Gurgel BR-800, Gurgel Supermini, Santa Matilde SM 4.1,
Willys Interlagos, Simca Chambord, DKW Fissore, Aero Willys 2600,
FNM 2000 TIMB, Brasinca 4200 GT Uirapuru, Miura Saga, Adamo CRX,
Hofstetter Turbo, Emis Art (buggy) e Troller T4.

## Como foi feito
- `lib/game/brazil_content.dart`: +25 `CarDesign` em `brazilCarDesigns`,
  +25 `CarSpec` em `brazilCars` (ids `br_*`, append-only após os 81 atuais,
  saves e índices antigos intactos) e categorias no `_brazilCategories`.
- `lib/game/car_details_brazil.dart`: detalhes de malha próprios para os
  novos modelos (janelas altas da Kombi, estepe e santos-antônios do
  Troller, arco do buggy Emis, faróis redondos dos clássicos, cunha do
  Hofstetter, racks das peruas, spoilers dos esportivos de fibra).
- Progressão continua a curva atual: 10.800–24.800 moedas e 48–96 estrelas;
  nenhum nacional novo entra na classe S (máximo classe A — Hofstetter).
- `onlineContent` novo: `carwece-brasil-3.0-106-cars` (o catálogo mudou;
  salas não misturam versões).

## Testes atualizados (contagens do catálogo)
`brazil_expansion_test`, `expansion_v05_test`, `world_expansion_test` e
`garage_filters_test` (totais 81→106, nacionais 25→50; o teste da garagem
ganhou um `ensureVisible` porque a lista ordenada por nome cresceu).
Suíte completa executada localmente com Flutter 3.35.7.
