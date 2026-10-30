# CarWece 0.12.1+18 — carro parado e abertura em vídeo

## Carro parado nas pistas

O contato com o plástico corrigia a posição reconstruindo-a pela linha central da pista. Nas curvas, isso removia uma pequena parte do deslocamento longitudinal mesmo quando a velocidade era zero. Ao repetir o cálculo, o carro escorregava, mudava de posição e podia ficar pressionado contra a lateral.

Agora o contato corrige somente a altura e a penetração real na barreira. Os pneus seguram o carro parado em inclinações suaves, sem impedir a aceleração ou a ré. Esterçar parado anima o eixo dianteiro e não gira nem arrasta o chassi. A ré continua sendo engatada ao segurar FREIO. Os alvos passivos da exploração ficam em ponto morto, sem manter um comando de freio que engatava ré após alguns instantes.

As colisões por fora da pista e das rampas continuam sólidas. O carro ainda cai quando perde apoio em um loop; a correção não prende um veículo invertido à pista.

## Abertura HIRUMISU STUDIOS

O vídeo enviado, `23245.mp4`, foi incluído integralmente em `assets/video/carwece_intro.mp4`, sem cortes ou recodificação: aproximadamente 10,027 segundos, 1280×720, 24 quadros por segundo, vídeo H.264 e áudio AAC estéreo. O arquivo funciona offline e mantém o SHA-256 original.

A abertura aparece ao iniciar o aplicativo. A transição para o menu ocorre somente quando o reprodutor informa que chegou ao fim, sem temporizador para encurtar o vídeo. A proporção 16:9 é preservada; celulares mais largos mostram faixas pretas laterais em vez de cortar o logotipo. Não há botão para pular a reprodução normal.

Ao ir para segundo plano ou perder o foco de áudio, o vídeo pausa. Ao retornar, continua no mesmo ponto. A trilha do menu e os efeitos do jogo aguardam o término da abertura. Se o dispositivo informar erro de reprodução, aparece TENTAR NOVAMENTE; um erro não é tratado como vídeo concluído.

## Atualização

Instale `CarWece_v0.12.1_hirumisu.apk` sobre a versão anterior, sem desinstalar. Pacote `com.hirumisu.carwece`, nome CarWece, ícone e certificado mantidos. Progresso, moedas, compras, recordes, músicas, layout do HUD e as regras de largada do campeonato continuam no mesmo salvamento.

Os poderes continuam sendo obtidos somente nas caixas do mapa. Toda munição é limitada, inclusive a metralhadora. O catálogo do pause não concede armas.

Veja `verification/VALIDACAO.md` para os resultados desta versão e seus limites. Ainda não houve teste em aparelho Android físico.
