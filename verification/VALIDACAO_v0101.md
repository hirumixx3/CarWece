# Validação CarWece 0.10.1+14 — mais músicas — hirumisu

## APK

- CarWece_v0.10.1_hirumisu.apk: 241140278 bytes.
- SHA-256: `64d44f74f6f95dc3e50b4d656c2c99aebdad9e5a4818e353e201bfa6450a2f6b`.
- Pacote com.hirumisu.carwece; nome CarWece; versão 0.10.1, versionCode 14.
- Android minSdk 24, targetSdk 35; ARMv7, ARM64 e x86_64.
- Certificado mantido: `9e1be273e6871c23013157fad5378ffc4d5da5b222d70f84a995c8cb94ca8d7a`.
- Assinatura v2, CRC ZIP e alinhamento de arquivos/bibliotecas de 16 KiB verificados.
- 20 PNGs compilados e 2 ícones adaptativos comparados às fontes aprovadas.
- Canais native, graphics e music presentes no DEX e nas três bibliotecas Dart.

## Trilha sonora

São 20 MP3s, totalizando 193016589 bytes. As dez faixas deste envio somam 100796993 bytes. Todas foram incluídas inteiras, sem conversão nem cortes; os arquivos antigos mantiveram seus SHA-256 e os dez novos foram comparados aos anexos originais.

Legends Never Die continua em loop nos menus. A playlist de corridas contém as outras 19 músicas, com avanço automático, ordem aleatória sem repetição imediata e escolha pelo pause. O ciclo de sorteio é mantido nas visitas ao menu entre corridas. O modo sequencial, o volume e os botões de reproduzir/pausar e pular foram preservados. A corrida só retoma com CONTINUAR.

Os vinte fluxos foram decodificados integralmente no FFmpeg sem erro. No APK final, cada MP3 foi comparado byte a byte à fonte e por SHA-256 ao catálogo. Os dez novos também foram comparados aos anexos. Todos estão em ZIP_STORED, permitindo AssetManager.openFd/MediaPlayer. O catálogo JSON empacotado foi comparado integralmente ao catálogo do projeto: 20 registros e 19 raceIds, com a faixa do menu excluída das corridas.

Catálogo completo: assets/music/catalog.json. Lista de títulos: NOVIDADES_v0101.md. Evidências: audio_decode_v0101.json, audio_decode_new_v0101.json e audio_assets_v0101.json.

## Código e interface

- 133 testes Flutter passaram; analisador sem problemas.
- O teste do catálogo foi atualizado para 20 músicas e 19 faixas de corrida, verificando títulos, artistas, durações, assets e correspondência entre Dart/Android.
- O painel de música foi testado em 1280×720 e 800×360: seleção, pulo, ordem aleatória, volume, reprodução/pausa e rolagem até Young Turks, a última das 19 músicas. O painel mantém a física e os controles pausados e volta ao pause ao fechar.
- 26 testes JVM passaram: 7 do contrato gráfico e 19 do controlador de música. Os cenários de sorteio, avanço, seleção, erros e visitas ao menu agora usam uma playlist de 19 faixas, cobrindo três ciclos completos sem repetição imediata.
- Casos nativos de foco de áudio, volume zero, callbacks antigos, background, pausa e retomada de posição também passaram com backend controlado.
- O download inicial de JUnit não estava disponível na rede deste ambiente. Os testes foram executados offline com os JARs JUnit 4.13.2 e Hamcrest 1.3 que acompanham o Gradle 8.12, por um repositório temporário restrito ao projeto. Não houve alteração das dependências do aplicativo; hashes em junit_offline_v0101.json.
- Física, malhas, circuitos, controles, persistência, backend Android de música e chave de assinatura foram comparados byte a byte ao código da 0.10.0 e permaneceram iguais. O fallback da contagem de faixas no painel foi tornado dinâmico.
- O uso de MediaPlayer, prepareAsync, caminho de assets e classes nativas mapeadas pelo R8 foi verificado no DEX; r8_music_v0101.json e r8_mapping_v0101.txt contêm as evidências atuais.
- Compilação release concluída em 90,5 segundos. Logs e relatórios XML estão nesta pasta.

## Limites

Não houve execução em celular físico ou emulador, audição pela saída Android, medição de FPS/bateria ou teste real de instalação sobre a versão anterior. Os testes nativos usam um backend de áudio controlado; a decodificação completa dos MP3s foi feita no host. As capturas do painel são de widgets reais com áudio e textura simulados em teste. A assinatura e o pacote mantidos permitem atualizar sem desinstalar, mas o fluxo real de instalação no aparelho ainda precisa ser testado.

As evidências gráficas e de física anteriores continuam arquivadas em VALIDACAO_v090.md e VALIDACAO_v0100.md. Esta atualização adiciona áudio e atualiza o catálogo e a versão do aplicativo.
