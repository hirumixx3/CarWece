# Novidades 0.9.0 — hirumisu

## Quinze carros novos

Estatísticas e preços são balanceamento do jogo, não especificações ou preços reais. Cada modelo tem proporções de carroceria, cabine, rodas e detalhes próprios; as rodas continuam separadas para girar e esterçar.

| Modelo | Desbloqueio | Moedas | Categoria |
|---|---:|---:|---|
| TOYOTA AE86 TRUENO | 2 ★ | 1100 | RUA |
| MAZDA RX-8 | 6 ★ | 2600 | ESPORTIVO |
| HONDA S2000 | 9 ★ | 3400 | ESPORTIVO |
| NISSAN 370Z | 7 ★ | 3100 | ESPORTIVO |
| TOYOTA GR SUPRA A90 | 16 ★ | 5900 | ÍCONES |
| TOYOTA GR YARIS | 13 ★ | 4300 | ESPORTIVO |
| MITSUBISHI ECLIPSE GSX | 8 ★ | 2800 | ÍCONES |
| BMW M3 E30 | 10 ★ | 3200 | ÍCONES |
| AUDI R8 V10 | 27 ★ | 9500 | EXÓTICO |
| MERCEDES-AMG GT R | 30 ★ | 10700 | EXÓTICO |
| CORVETTE C7 Z06 | 29 ★ | 10400 | EXÓTICO |
| DODGE VIPER GTS | 34 ★ | 12500 | EXÓTICO |
| FORD GT 2005 | 40 ★ | 15800 | EXÓTICO |
| MCLAREN 720S | 52 ★ | 21500 | ELITE |
| PAGANI ZONDA F | 66 ★ | 28000 | ELITE |

## Oito pistas com loops

| Circuito | Ambiente | Loops | Desbloqueio |
|---|---|---:|---:|
| ESPIRAL DOS BRINQUEDOS | QUARTO | 1 | 1 ★ |
| DOBRO DE ADRENALINA | QUARTO | 2 | 8 ★ |
| PISTÃO INVERTIDO | GARAGEM | 1 | 12 ★ |
| DUPLA COMBUSTÃO | GARAGEM | 2 | 26 ★ |
| VÓRTICE DO AZULEJO | BANHEIRO | 1 | 18 ★ |
| RECEITA EM DOSE DUPLA | COZINHA | 2 | 36 ★ |
| ÓRBITA DO SOFÁ | SALA | 1 | 43 ★ |
| NEON 360 ×2 | ARCADE | 2 | 55 ★ |

Os 12 loops novos têm separação lateral de 84 unidades entre entrada e saída, com pista de 46 unidades, totalizando 38 de folga. As oito pistas usam rotas distintas e mantêm trechos no chão e atalhos com portão. A pista original do quarto conserva seu loop e seu traçado; os 18 circuitos anteriores preservam IDs e recordes.

O quadro de orientação é transportado em cada loop isoladamente. Não há rotação residual após a saída nem ligação artificial entre os dois loops. Gravidade e força normal determinam o contato dos pneus; parar invertido causa queda. Boosts de aproximação existem antes de cada loop.

## Quatro poderes novos

| Poder | Uso | Defesa / limite |
|---|---|---|
| GRANADA | Duas cargas, arco balístico, quique e explosão com área; SUPER dá três e amplia a área. | Escudo absorve o dano; não abre portões, que continuam exigindo míssil. |
| IMPACTO | Onda visível que empurra adversários próximos no plano da pista. | Respeita escudo, distância e separação vertical. |
| ESPINHOS | Faixa física atrás do carro; reduz aderência e velocidade por 4 s, ou 6 s no SUPER. | Escudo, salto ou desvio evitam o dano. Expira e não fica acumulada na pista. |
| REPARO | Remove dano visual, giro, atordoamento, gelo, pane elétrica e pneus furados. | O SUPER também concede 4 s de escudo. Não restaura posição nem avança checkpoints. |

O sorteio percorre todos os 13 poderes sem repetição imediata entre recargas. Rivais escolhem os novos poderes conforme o tráfego e o dano. A fumaça conserva seu efeito espacial: ao sair da nuvem, a tela volta imediatamente.

## Regra de largada solicitada

- Corrida avulsa: jogador em 6º, sempre.
- Primeira etapa de campeonato ou novo campeonato: jogador em 6º.
- Próximas etapas: a ordem de largada é a ordem real registrada no resultado da etapa anterior. Se terminou 4º, larga 4º; se terminou 1º, larga 1º. A pontuação acumulada do campeonato não muda essa regra.
- Contrarrelógio: apenas o jogador.

Todos os carros largam antes da linha. A primeira passagem pela linha inicia a volta sem conceder uma volta adicional. Reposicionar o carro continua usando o último checkpoint validado, sem redefinir o grid.

## Estabilidade

A recuperação da IA agora exige avanço real: oscilar para frente e para trás contra um objeto não reinicia o prazo de recuperação. O retorno usa somente checkpoint já validado. O carregamento de modelos mantém índices estáveis e transmite apenas os modelos do pelotão ou da garagem, com cache limitado a 24 malhas de carros. Isso reduz os dados gráficos carregados, sem afirmar uma taxa de FPS em aparelho.
