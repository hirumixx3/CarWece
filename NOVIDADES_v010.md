# CarWece 0.10.0 — trilha sonora — hirumisu

Os dez MP3 enviados pelo usuário foram incluídos inteiros, sem recodificação nem cortes. Total de 92.219.596 bytes de áudio. Não é necessário baixar nada durante o jogo nem conceder acesso ao armazenamento.

## Menu

**Legends Never Die — League of Legends** toca em repetição no menu principal, garagem, seleção de pista, configurações e resultados. Ao voltar de uma corrida, o jogo retorna a essa música. O volume salvo nas configurações é respeitado desde a inicialização.

## Corridas

As outras nove faixas formam a trilha das corridas, incluindo campeonato e contrarrelógio:

| Faixa | Artista nos arquivos enviados | Duração |
|---|---|---:|
| Sing Me to Sleep | Alan Walker | 3:09 |
| Attention | Charlie Puth | 3:31 |
| K. | Cigarettes After Sex | 5:20 |
| Words (Original Version 1983) | F.R. David | 3:29 |
| Everybody's Changing | Keane | 3:36 |
| See You Again (feat. Charlie Puth) | Wiz Khalifa | 3:49 |
| Lalala | Y2K | 2:40 |
| Rockabye (feat. Sean Paul & Anne-Marie) | Clean Bandit | 4:11 |
| Somewhere Only We Know | Keane | 3:55 |

Por padrão, a ordem é aleatória, sem repetição imediata e passando pelo conjunto de nove antes de começar outro ciclo. O ciclo também é mantido ao visitar menus entre corridas. Ao terminar uma faixa, outra inicia automaticamente.

## Pause → MÚSICAS

- Escolha uma faixa na lista para tocar imediatamente.
- PULAR FAIXA avança para a próxima música.
- ALEATÓRIO alterna entre sorteio e a ordem da lista; a preferência é salva.
- O botão de reproduzir/pausar controla apenas a música.
- O controle de volume altera a mesma configuração de música usada no menu.
- A lista pode ser rolada em telas menores. A faixa atual, artista e duração aparecem no painel.
- Fechar o painel volta ao pause. Só CONTINUAR retoma a corrida; teclado e botões não movimentam o carro enquanto o painel está aberto.

A música continua durante a pausa da corrida para permitir ouvir a seleção. Ao minimizar o aplicativo, a reprodução é suspensa e o decodificador é liberado em onStop; ao voltar à mesma sessão, a faixa é retomada na posição guardada. Foco de áudio, chamadas/notificações e desconexão de fones são tratados sem manter a trilha tocando fora do aplicativo. Se uma faixa falhar, o sistema tenta outra; falhas de todas as faixas não criam um ciclo infinito.

## Áudio e regressões

A trilha sintetizada anterior foi removida. O sintetizador agora cuida apenas do motor e dos efeitos dos poderes, impactos, turbo e interface, com volume separado. Os arquivos são lidos por um único MediaPlayer a partir do APK, sem carregar os dez MP3 na memória ao mesmo tempo.

Os 31 carros, 26 pistas, 13 poderes, HUD e progressão da v0.9 foram mantidos. Avulsa e primeira etapa do campeonato largam em 6º. As demais etapas usam a ordem registrada no resultado anterior, incluindo a posição do jogador.

Pacote com.hirumisu.carwece, versão 0.10.0+13, certificado e ícone aprovados mantidos. Instale sobre a versão anterior, sem desinstalar.
