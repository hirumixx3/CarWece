# Validação CarWece 0.10.0+13 — trilha sonora — hirumisu

## APK entregue

- Arquivo: CarWece_v0.10.0_hirumisu.apk; 140340207 bytes.
- SHA-256: `55c1dddf98b65cc6c2ce33407fcfda0cca1d1dc8f3de793b7f7f0a3c9e30cb25`.
- Pacote: com.hirumisu.carwece; nome CarWece; versão 0.10.0; versionCode 13.
- Android minSdk 24, targetSdk 35, ARMv7 / ARM64 / x86_64.
- Certificado SHA-256 mantido: `9e1be273e6871c23013157fad5378ffc4d5da5b222d70f84a995c8cb94ca8d7a`.
- Assinatura v2, CRC do ZIP, alinhamento de arquivos e bibliotecas de 16 KiB verificados.
- 20 PNGs de ícone compilados comparados às fontes e 2 ícones adaptativos verificados; ícone aprovado mantido.
- Os três canais Flutter/Android — native, graphics, music — foram encontrados no DEX e nos três libapp.so.

## Músicas incluídas

| Faixa | Artista dos arquivos enviados | Uso |
|---|---|---|
| Sing Me to Sleep | Alan Walker | Corridas |
| Attention | Charlie Puth | Corridas |
| K. | Cigarettes After Sex | Corridas |
| Words (Original Version 1983) | F.R. David | Corridas |
| Everybody's Changing | Keane | Corridas |
| Legends Never Die | League of Legends | Menu, em repetição |
| See You Again (feat. Charlie Puth) | Wiz Khalifa | Corridas |
| Lalala | Y2K | Corridas |
| Rockabye (feat. Sean Paul & Anne-Marie) | Clean Bandit | Corridas |
| Somewhere Only We Know | Keane | Corridas |

Os dez MP3 têm bytes e SHA-256 iguais aos arquivos enviados pelo usuário. Foram incluídos inteiros, sem recodificação. Total: 92219596 bytes. Todos os dez fluxos foram decodificados por inteiro no FFmpeg sem erros. Os assets do APK foram extraídos para comparação exata e estão sem compressão ZIP, como exigido por AssetManager.openFd/MediaPlayer.

## Verificações de código e interface

- 133 testes Flutter completos passaram. Incluem as regressões de carros, pistas, HUD, controles, progressão, campeonato, física, fumaça e renderização, além do catálogo, controle de áudio e painel de músicas.
- Os 6 testes de música e o teste do canal gráfico foram repetidos após finalizar a captura da interface e tornar atômica a exportação do pacote de validação gráfica. Todos os 7 passaram.
- Analisador Flutter: sem problemas.
- 26 testes JVM passaram: 7 do canal gráfico real e 19 da fila de música e de seu ciclo de vida com um backend de áudio controlado. Não são testes de reprodução em hardware Android.
- O menu mantém Legends Never Die em loop e não reinicia com as atualizações periódicas de volume/cena. Corridas usam somente as outras nove faixas, com avanço automático.
- Sorteio por conjunto completo, sem repetição imediata na virada e sem perder a ordem ao visitar menus entre corridas. Modo sequencial, escolha manual, pulo, pausa/reprodução, volume zero, foco, preparação tardia, troca rápida, background, posição de retomada, liberação e falhas limitadas cobertos pelos testes nativos.
- Painel testado em 1280×720 e 800×360: escolher faixas, pular, rolar até a última, alternar aleatório, volume, reproduzir/pausar e fechar; física e controles permanecem pausados até CONTINUAR.
- A preferência ALEATÓRIO é salva sem alterar HUD ou progresso. O volume de música continua separado dos efeitos. O sintetizador antigo não contém mais a melodia, baixo ou bateria e cuida apenas dos efeitos e do motor.
- Um único MediaPlayer faz a leitura dos assets, com prepareAsync e verificações de callbacks obsoletos. O decodificador é liberado em onStop; o título e a posição são guardados na mesma sessão. Foco de áudio e desconexão de fones são tratados.
- Verificado no DEX o uso de MediaPlayer, prepareAsync, o caminho do catálogo e as classes reais mapeadas pelo R8. Os nomes ofuscados estão em r8_music_v010.json e o mapa completo desta compilação está em r8_mapping_v010.txt.
- As capturas da interface usam widgets reais e mocks dos canais de áudio/textura. Não demonstram áudio tocando ou gráficos executados num celular físico.

## Limites

Não houve execução em aparelho físico ou emulador Android, audição pela saída de áudio do Android, medição de FPS/bateria ou teste real de instalação sobre o APK anterior. A integridade dos arquivos de música, a política de reprodução, os comandos, a integração de interface e a identidade do APK foram verificados pelos meios acima. O estudo e as 146 cenas GLES da versão anterior continuam documentados em VALIDACAO_v090.md; shaders, malhas, pistas e física não foram alterados nesta atualização.

Referência primária consultada para o ciclo de vida do player: https://developer.android.com/media/platform/mediaplayer/state-resources e https://developer.android.com/reference/android/media/MediaPlayer .
