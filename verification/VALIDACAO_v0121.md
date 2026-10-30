# Validação CarWece 0.12.1+18

## APK

CarWece_v0.12.1_hirumisu.apk: 248085440 bytes.
SHA-256: `08b0e3f15eb3801eaaea106159dc83a72d62c6be2d407823cbea8c822e3d104a`.
Pacote com.hirumisu.carwece, nome CarWece, versionCode 18. Android minSdk 24, targetSdk 35; ARMv7, ARM64 e x86_64. Certificado SHA-256 `9e1be273e6871c23013157fad5378ffc4d5da5b222d70f84a995c8cb94ca8d7a` mantido.

Assinatura v2, CRC do ZIP, alinhamento de 16 KiB, 20 PNGs de ícone e duas camadas adaptativas verificados. As vinte músicas correspondem por bytes e SHA-256 ao catálogo e às fontes e estão sem compressão ZIP. O vídeo original está inteiro no APK, com SHA-256 `4e5395f7cbe6db3e29f1081c1bdc56a6c40adaf077c8a70fb9f795528fdcf204`, também sem compressão ZIP para uso por descritor de arquivo no MediaPlayer. Não há arquivos temporários no APK. As tabelas dos seis ELF estão dentro dos limites dos arquivos; as três bibliotecas libflutter.so correspondem aos binários confiáveis já verificados. Os shaders são idênticos aos da 0.12.0. Os canais de música e abertura, o caminho do MP4 no DEX, o canal de abertura nas três bibliotecas AOT, as 44 identidades de poderes e os símbolos de música foram conferidos.

## Testes desta versão

- **178 testes Flutter passaram**, incluindo a suíte completa de física, controles, armas, progressão, grid de campeonato, HUD, áudio e contratos gráficos. Analisador sem problemas.
- **42 testes JVM passaram**, zero falhas/erros/ignorados: 7 de contrato gráfico de corrida, 6 de batalha, 19 de música e 10 de abertura. JUnit/Hamcrest oficiais foram usados offline; nenhum backend falso substitui código de produção no APK.
- **208 casos de carro parado**: 52 largadas (26 pistas × corrida avulsa/contrarrelógio) e 156 pontos de plástico em curvas e inclinações suaves. Maior deslocamento em repouso: 0.001883191 unidades internas; menor velocidade após a fase de aceleração: 15.789906. Ver stationary_v0121.json. Esses números são da simulação, não medições em metros ou no aparelho.
- Três regressões específicas verificam estabilidade na largada, parada em faixas deslocadas nas curvas, esterçamento parado junto às duas laterais, retomada pelo acelerador e saída dirigindo para dentro da pista. A ré permanece funcional; os alvos passivos da exploração não mantêm mais freio pressionado até engatar ré.
- O controlador de referência terminou **26 circuitos por três voltas**. Os **nove loops das arenas** foram atravessados com velocidade suficiente sem queda; o teste de carro parado invertido continua causando queda real.
- Cinco testes Flutter da abertura verificam que passar vinte segundos não abre o menu sem o sinal nativo de fim, pausa/retomada sem reabrir o arquivo, erro com tentativa novamente, enquadramento 16:9 inteiro em tela 800×360 e conclusão imutável diante de mensagens atrasadas. Os testes de menus existentes desativam a abertura explicitamente apenas em seus próprios fixtures; a inicialização de produção usa a abertura por padrão.
- Dez testes JVM do controlador de abertura verificam espera por preparo/foreground/foco, abertura idempotente, pausa e retorno com o mesmo decodificador, conclusão exclusivamente pelo callback, fim sem repetição, erro sem falso sucesso, nova tentativa com rejeição de callbacks antigos, liberação, metadados inválidos e exceções de preparo. O backend de produção usa MediaPlayer, áudio do MP4 e SurfaceTexture, com loop desativado.

## Vídeo original

`23245.mp4` foi copiado sem cortes nem recodificação para assets/video/carwece_intro.mp4: 3683690 bytes, 10.026667 segundos. Vídeo H.264 1280×720, 24 fps, 240 quadros; áudio AAC estéreo 48 kHz, 470 blocos. O arquivo completo foi decodificado por FFmpeg sem erros e o arquivo empacotado foi comparado byte a byte à fonte. A transição para o menu depende de MediaPlayer.onCompletion, sem temporizador de corte. A música do menu aguarda o fim da abertura. No segundo plano e ao perder foco de áudio, o mesmo player pausa e retoma sem seek ou recarga. Um erro mostra TENTAR NOVAMENTE e não é tratado como reprodução concluída.

## Escopo, preservação e limites

A correção de contato preserva o resíduo tangencial da posição nas curvas, corrige somente altura/penetração real e segura os pneus parados em inclinações suaves. Não muda a direção do jogador automaticamente e não prende carros invertidos aos loops. Colisões externas de pista/rampa, armas por coleta, toda munição finita, 31 carros, 26 circuitos, seis arenas, os 44 equipamentos de batalha, 13 poderes de corrida, 20 músicas, gráficos, editor de HUD, salvamentos, certificado e ícone mantidos.

Não houve instalação ou execução em celular físico/emulador Android, audição ou reprodução visual pelo MediaPlayer real do aparelho, medição de FPS, bateria ou memória no dispositivo. A decodificação FFmpeg valida o arquivo; os testes de callbacks e widgets validam o fluxo, sem substituir um teste de reprodução no celular. A atualização sobre o APK anterior usa pacote/certificado iguais, mas o fluxo real de instalação ainda precisa de validação no aparelho. Alguns bots ainda podem passar períodos presos entre carros/objetos.

O relatório anterior está em VALIDACAO_v012.md. Imagens e simulações identificadas com versões anteriores são históricas; esta versão não refez a bateria visual de 121 cenas da 0.12.0.
