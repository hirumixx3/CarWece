# CarWece 1.4.0+6 — 4 poderes novos + detalhamento visual geral

## Poderes novos no modo corrida (criações originais)
Itens 14–17 do `ItemType` (acréscimo no fim do enum: saves, índices de
rede e a bolsa de itens dos pickups não mudam de significado). Entram na
roleta de pickups, nos bots rivais (uso contextual) e no SUPER (nitro
cheio), com nome, ícone e cargas próprios:

- **SALVA TRIPLA** — leque de 3 foguetes (SUPER: 5, o central guiado).
  2 cargas.
- **DRENO DE ENERGIA** — rouba o momento do rival à frente: ele entra em
  pane elétrica e você ganha +35 de nitro (SUPER: alcance e efeito
  maiores, +55). Escudo bloqueia; fantasma é inalcançável.
- **PROPULSOR** — salto com impulso para pular confusão e obstáculos
  baixos, +20 de nitro ao usar. 2 cargas (SUPER: salto mais alto).
- **FANTASMA** — intangível por 4,5 s (SUPER: 6,5 s): atravessa rivais e
  nada conecta — foguetes, minas, óleo, espinhos, EMP, tesla e onda de
  impacto passam direto. Novo campo `Driver.ghostTime`, respeitado em
  colisões carro-carro, projéteis, detonação, `_damage` e objetos.

## Detalhamento visual
- **Carros (todos os 106):** camada universal de detalhes dimensionada
  pelo design de cada carro — espelhos retrovisores, saias laterais,
  splitter frontal, difusor traseiro, escapamentos cromados duplos e
  maçanetas — sem tocar nos builders autorais existentes.
- **Explosões:** malha nova em camadas (núcleo brilhante, bola de fogo
  irregular e 6 fragmentos ao redor), 5 massas de fogo por explosão,
  clarão de detritos no início, coluna de fumaça que fica no ar e, na
  simulação, faíscas + detritos + fumaça persistente a cada detonação.
- **Obstáculos temáticos:** cogumelos e broto no tronco, vértebras de
  cauda no fóssil, pedras e arbusto seco na duna, bolas companheiras na
  neve, corais-leque no coral e galhos quebrados na madeira à deriva
  (os protótipos são reescalados para o volume físico, então os colisores
  não mudam).
- **Pistas:** chevrons vermelhos de alerta no lado externo das curvas
  realmente fechadas, sobre o asfalto.

## Versão e online
`1.4.0+6`; `onlineContent` = `carwece-brasil-3.1-powers-visual`.
Suíte completa executada localmente com Flutter 3.35.7, incluindo o novo
`test/race_powers_v14_test.dart` (6 testes dos poderes).
