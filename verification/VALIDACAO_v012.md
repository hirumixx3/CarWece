# Validação CarWece 0.12.0+17

## APK e integridade

CarWece_v0.12.0_hirumisu.apk: 244385138 bytes.
SHA-256: `374ceaa3443b864b4236bd02cabdcc027305f8d7c6f7300cd3f888b88b5fdd0c`.
Pacote com.hirumisu.carwece, nome CarWece, versionCode 17. MinSdk 24, targetSdk 35; ARMv7, ARM64 e x86_64. Certificado SHA-256 `9e1be273e6871c23013157fad5378ffc4d5da5b222d70f84a995c8cb94ca8d7a` mantido.

Assinatura v2, CRC do ZIP, alinhamento de 16 KiB, três ABIs, os 20 PNGs de ícone e as duas camadas adaptativas foram verificados. As vinte músicas estão sem compressão ZIP e correspondem por bytes/SHA-256 ao catálogo e às fontes. Os canais nativos, símbolos de música, 44 identidades de BattlePower e shader de status foram conferidos no APK. Não há entradas temporárias no pacote; os seis ELF têm tabelas de seções e programas dentro dos limites dos arquivos. As três bibliotecas libflutter.so são idênticas às dos JARs confiáveis do Flutter, após a mesma remoção de símbolos do NDK. Ver engine_integrity_v012.json, native_integrity_v012.json e apk_meta.json.

## Testes desta versão

- Suíte completa Flutter: **170 testes passaram**. Analisador: **sem problemas**.
- JVM: **32 testes passaram**, zero falhas/erros/ignorados: 7 do contrato gráfico de corrida, 6 de batalha e 19 de música. Os contratos decodificam os payloads reais de 114/173 slots emitidos pelo Flutter. JUnit e Hamcrest oficiais da distribuição Gradle foram usados offline para os testes.
- Sete regressões específicas de superfície verificam batidas externas pelos dois lados, retenção interna, passagem sob ponte, pouso superior, contato inferior, faces laterais/traseira de rampa e subida/lançamento/pouso contínuos sem salto de posição.
- Quatro testes de equipamentos verificam 44 malhas distintas, finitas e dentro do orçamento; ausência de equipamentos antes da coleta; três montagens para o inventário carregado; rastreio de alvo móvel entre tiros; coerência entre boca/direção/projétil; rotação até alvo atrás do carro sem esterçar o chassi.
- Os testes existentes continuam verificando obtenção dos 44 poderes exclusivamente por colisão com caixas, esgotamento de cada munição, ausência de arma infinita de reserva, bloqueio de catálogo não coletado, salvamento, HUD em 1280×720 e 800×360, multitouch e pausa.
- O teste de condução percorreu **os 26 circuitos por três voltas**, usando o controlador físico de referência. Os **nove loops das arenas** foram atravessados sem queda com velocidade suficiente; o teste de carro parado invertido continua soltando o carro.
- **18 partidas simuladas**: seis arenas × fácil/normal/difícil; todas terminaram, com posições finitas dentro da sala. Foram **1212 disparos e 55 eliminações**, entre **6,942 e 196,400 segundos**. O jogador dessa simulação usa o controlador de referência: não representa habilidade humana nem comprova balanceamento final.
- **121 cenas GLES distintas**: seis vistas gerais, seis de condução, nove loops, seis rampas, seis detalhes de salas, 44 montagens e 44 poderes em uso. Os shaders compilaram em Mesa/EGL sem erro GLES. Uma imagem de montagem incompleta foi regenerada; os 121 PNGs foram decodificados integralmente. São cenas preparadas do mesmo motor e não capturas de Android.

## Escopo e limites

O contato automático pela proximidade da pista foi restringido; rails e faces de rampa têm resposta sólida, e a rampa usa sua inclinação física. A mira é atualizada a cada passo e equipamentos direcionais compartilham a direção com o tiro. Há um modelo próprio para cada poder coletável e suportes para os itens guardados. Materiais e acabamento de pista, rampas, caixas e salas foram atualizados com neblina zero.

31 carros, 26 circuitos, seis arenas, 13 poderes de corrida, 44 poderes de batalha, 20 músicas, direção manual, editor de HUD, pacote, certificado, ícone e progresso mantidos. Batalha e Explorar começam sem armas, incluindo os rivais; toda munição é finita. A metralhadora é coletável e fornece 60 tiros. Os resultados de batalha permanecem separados das estrelas e dos recordes de corrida.

Não houve instalação ou execução em aparelho físico/emulador Android, audição Android, medição de FPS, bateria ou memória total no dispositivo. O fluxo de atualização e os controles no hardware ainda precisam de teste no celular. Alguns bots podem passar períodos presos entre objetos ou carros. Os dados de versões anteriores, quando identificados com v011/v0111, são históricos; a evidência atual usa v012.
