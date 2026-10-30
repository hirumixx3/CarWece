# CarWece 0.12.3+20

## Colisões da pista

O carro agora consulta as superfícies de todos os trechos próximos, inclusive pistas sobrepostas nos loops. A travessia entre dois passos da simulação é verificada: uma queda rápida não depende de o carro terminar o passo a menos de dois pontos da superfície.

Teto e laterais da carroceria também colidem. Um carro invertido ou atingindo a face vertical de um loop rebate e continua no ar, sem grudar os pneus na parede. Ao passar por baixo de uma pista descendente, o piso não cancela a correção do teto: o carro para quando não há altura suficiente para passar, em vez de atravessar e subir na pista. Continua sendo possível passar sob pontes com espaço livre e aterrissar pela face superior.

A consulta usa uma malha de triângulos com índice espacial e caches limitados. O contato já existente dos pneus com seu próprio trecho curvo é preservado. Simulação, direção manual, controles, HUD e modo gráfico AUTO continuam disponíveis.

## Moedas

| Colocação final | Corrida ou batalha |
|---|---:|
| 1º | 1.000 |
| 2º | 500 |
| 3º | 250 |
| 4º em diante | 0 |

Os valores são fixos: acertos, eliminações e dificuldade não acrescentam multiplicadores. Cada etapa de campeonato paga pela posição daquela corrida. Contrarrelógio completo, sendo uma corrida individual em 1º, paga 1.000. Exploração e partidas não finalizadas não pagam. A batalha mantém a proteção contra registrar a mesma partida duas vezes.

## Dificuldade da batalha

A tela de escolha de arena tem FÁCIL, NORMAL e DIFÍCIL. Essa preferência é salva separadamente da dificuldade das corridas. O padrão continua NORMAL, agora com menos pressão.

Todos os níveis receberam rivais um pouco mais lentos, intervalo maior entre ataques, precisão menor e redução no dano base das armas disparadas pelos bots. Contatos, efeitos periódicos e armas especiais continuam perigosos. O jogador mantém 100 de vida e o mesmo dano das próprias armas. Ninguém começa armado; coleta e munição finita permanecem obrigatórias.

## Músicas menores

As vinte faixas completas foram convertidas de MP3 para **AAC-LC em M4A, mono, 24 kHz e 32 kbps**. O total passou de **193.016.589 para 19.504.785 bytes**, redução de **89,89%**. Essa compressão forte reduz a qualidade e remove o estéreo; não corta as músicas. O vídeo de abertura permanece intacto.

Legends Never Die continua em repetição no menu; as outras dezenove continuam nas corridas e batalhas, com seleção pelo pause. Os IDs das músicas foram mantidos. O APK contém somente as versões compactas; as fontes originais continuam na versão anterior do projeto. O ZIP atual usa as versões compactas necessárias para reproduzir o APK. tools/compress_music.py permite recriar os arquivos a partir dos MP3 originais.

## Testes e instalação

Passaram 192 testes Flutter e o analisador. A suíte inclui quatro regressões físicas novas, os 26 circuitos por três voltas, repouso, direção, armas, economia, escolha de dificuldade em telas grandes/pequenas, HUD, música e abertura. Os vinte M4A foram decodificados por inteiro com FFmpeg; durações ficaram a menos de 0,3 segundo das fontes. O relatório final em verification/VALIDACAO.md inclui os testes Android e a validação do APK.

Instale o APK sobre a versão anterior, **sem desinstalar**. Pacote com.hirumisu.carwece, nome, ícone e certificado permanecem os mesmos. Não houve teste em celular físico/emulador Android nesta sessão.
