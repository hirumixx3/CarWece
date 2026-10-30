# Validação CarWece 0.9.0+12 — 27/10/2026 — hirumisu

## Identidade do APK

- Arquivo: CarWece_v0.9.0_hirumisu.apk; 47704504 bytes.
- SHA-256: `0e2b21b49c8bc882782ca7c436c1f7352692315cfce12a4a6ab9a157d8c70c20`.
- Nome CarWece; package/namespace `com.hirumisu.carwece`; versão 0.9.0; versionCode 12.
- Android minSdk 24 / targetSdk 35; ARMv7, ARM64 e x86_64.
- Certificado SHA-256: `9e1be273e6871c23013157fad5378ffc4d5da5b222d70f84a995c8cb94ca8d7a`.
- Assinatura verificada; ZIP CRC, alinhamento de arquivos e bibliotecas e cabeçalhos dos 6 ELF verificados.
- 20 PNGs de ícone compilados com pixels iguais às fontes e 2 ícones adaptativos com as camadas corretas. Mestres aprovados preservados.

## Verificações executadas

- Analisador Dart/Flutter: sem problemas.
- 127 testes Flutter, incluindo geometria completa, física, queda nos loops, pneus, colisão, resultado de corrida, economia, entradas simultâneas, HUD, persistência, fumaça, poderes, scoping de malhas e largada.
- 7 testes de fluxo de interface repetidos após fortalecer o campeonato: sequência explícita de resultados 4º, 2º e 5º, posições de largada 6º, 4º e 2º, ordem completa dos rivais e reinício em 6º.
- 7 testes JVM no Android, usando o pacote real StandardMethodCodec de 114 modelos, sem falhas.
- 146 cenas no Mesa EGL/GLES: mesmos shaders, malhas e quadros utilizados no Android; ambos os programas GLSL compilados, sem erros GLES. A câmera de revisão do loop do Arcade foi mantida dentro da sala.
- 31 carros completaram a pista de referência com loop.
- 26 circuitos completaram três voltas pelo controlador de teste, com aceleração, direção e freio.
- IA: 130 conclusões no Normal e 130 no Difícil, todos os 26 circuitos em cada modo. Recuperações pelo último checkpoint validado: Normal 15; Difícil 20. Há ultrapassagens e dispersão lateral em todos os circuitos. Esses resultados não medem a dificuldade percebida por cada jogador.
- Oito novos circuitos: 12 loops completos, entrada/saída separadas, boost antes de cada loop, orientação sem torção posterior, suporte em velocidade e queda ao parar invertido. Os 24 atalhos nas 26 pistas continuam passando pelas validações de portais e portões.
- Sorteio dos 13 poderes cobre o conjunto completo e evita repetição imediata; novos objetos possuem física, efeito local e contramedidas.
- Novas compras preservam índices/IDs anteriores. Todos os desbloqueios têm progressão alcançável e o máximo é 78 estrelas.
- Malhas de inventário completo: 104981184 bytes; um carro de garagem: 4574304 bytes; pelotão de revisão: 19473840 bytes. É volume de dados de malha, não uma medição de memória total do Android ou de FPS.

## Limites

Não houve instalação/execução em celular físico, emulador Android, medição de FPS, consumo de bateria ou teste real de atualização sobre o APK antigo. A preservação de progresso foi coberta por testes e pela manutenção de pacote/certificado. As imagens de revisão são do motor GLES no Mesa; não são fotos ou capturas de aparelho. Os carros são interpretações de brinquedo, não reproduções fotográficas ou modelos licenciados.
