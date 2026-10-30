# CarWece 0.12.0+17 — colisões, armamento e acabamento

## Pistas e rampas

A proximidade da pista deixou de encaixar o carro automaticamente no plástico. As laterais bloqueiam a aproximação pelo lado de fora e mantêm quem está dentro do corredor. É possível dirigir sob uma ponte elevada e pousar na pista por cima; a face inferior também tem contato físico.

As rampas agora usam a superfície inclinada na física. As rodas sobem pela entrada baixa, o carro sai pela borda com a velocidade da inclinação e cai sob gravidade. As faces laterais e traseira são sólidas. O desenho não levanta mais um carro que simplesmente entrou no volume da rampa por fora. Pousar sobre a rampa é permitido. Parar invertido no loop continua causando queda.

O controlador dos rivais considera a largura do próximo trecho e procura uma linha ao lado de rampas antes de curvas. Direção e acelerador do jogador continuam manuais; ele decide quando fazer um salto.

## 44 equipamentos visuais na batalha

Cada poder tem um modelo próprio para montar no carro: metralhadora com fita de munição, lançadores com foguetes e aletas, morteiros, canhão, gatling, bobinas elétricas, emissores laser, caixas de reparo, geradores de escudo, turbinas, tambores de óleo, caixas de minas, discos, alto-falantes, projetores e antenas. As outras duas armas carregadas aparecem recolhidas nas laterais traseiras. Os modelos usam metal, plástico, emissores coloridos, bocas e ferragens.

Armas direcionais acompanham o alvo continuamente, com rotação e inclinação suaves, entre os disparos. O tiro sai do emissor na direção da arma. A mira considera o movimento dos alvos e a elevação de lançamento para armas em arco. Toque no nome de um rival para fixar o alvo; no teclado, C alterna o alvo. Equipamentos de defesa, armadilhas, ondas de área e propulsores mantêm sua montagem fixa, adequada ao efeito.

Os visuais não entregam armas automaticamente. Batalha e Explorar começam sem poderes, para o jogador e os rivais. Todos os 44 são obtidos nas caixas do mapa e toda munição é finita. A metralhadora entrega 60 tiros por coleta; repetir a coleta soma até 99. Ao esgotar todas as armas, aparece SEM PODER. O catálogo do pause só consulta os itens ainda não coletados.

## Cenários

As pistas receberam juntas, conexões, parafusos e variação do plástico. As rampas têm face traseira fechada, reforços, bordas e fixadores. Caixas ganharam tampa, alças e nervuras; caixas de papelão têm fita, dobras e etiqueta. Portas, ferragens, luminárias, tomadas, cortinas, rodapés e quadros acrescentam escala às salas.

Os materiais têm variação de rugosidade, metal escovado, grão de madeira, trama de tecido, rejunte, cerâmica e agregados no concreto. Detalhes finos são filtrados à distância para reduzir cintilação. A iluminação ambiente distingue superfícies voltadas para cima e para os lados. A neblina permanece em zero.

## Instalação e preservação

Instale `CarWece_v0.12.0_hirumisu.apk` sobre a versão anterior, sem desinstalar. Pacote `com.hirumisu.carwece`, nome CarWece, mesmo certificado e ícone aprovado. 31 carros, 26 circuitos, 6 arenas, nove loops nas arenas, 13 poderes de corrida e as 20 músicas continuam disponíveis. Moedas, carros comprados, campeonatos, recordes e layout do HUD continuam no mesmo salvamento.

Consulte `verification/VALIDACAO.md` para os testes desta versão. As prévias foram renderizadas com os modelos e shaders do jogo em Mesa/GLES; não são capturas de celular. Ainda não houve validação em aparelho Android físico.
