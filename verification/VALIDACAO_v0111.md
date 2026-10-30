# Validação CarWece 0.11.1+16 — poderes por coleta

## APK

CarWece_v0.11.1_hirumisu.apk: 244155530 bytes.
SHA-256: `a6c0bd650e71e90434828e294005155ff9787e8b78e5edad1bc6cafb17873322`.
Pacote com.hirumisu.carwece, nome CarWece, versão 0.11.1, versionCode 16. Android minSdk 24, targetSdk 35; ARMv7, ARM64 e x86_64. Mesmo certificado SHA-256 `9e1be273e6871c23013157fad5378ffc4d5da5b222d70f84a995c8cb94ca8d7a`.

Assinatura v2, CRC do ZIP e alinhamento de 16 KiB verificados. Os 20 PNGs compilados e os dois ícones adaptativos correspondem às fontes aprovadas. Os 20 MP3s são idênticos por bytes e SHA-256 ao catálogo e às fontes, e continuam sem compressão ZIP. O manifesto lista somente as vinte faixas e o catálogo; o APK foi verificado para não incluir arquivos auxiliares de áudio. Os canais nativos, a classe principal, os símbolos de música e as 44 identidades de BattlePower foram verificados nas três bibliotecas AOT. O shader de status foi comparado à fonte.

## Correção funcional

Batalha e Explorar iniciam jogador e adversários com inventário vazio e seleção nula. Só passar pelo item na arena entrega o poder. Os 44 itens entram na rotação das caixas, incluindo a metralhadora, que entrega 60 tiros por coleta. Todos os valores de munição do catálogo são positivos e finitos.

Disparar consome uma unidade; ao terminar, escolhe somente outra arma já coletada e carregada. Sem outra munição, fica SEM PODER. Trocar arma, abrir o catálogo, reiniciar partida ou reposicionar o carro não cria metralhadora de reserva. O catálogo do pause permite consultar os itens não coletados, mas não selecioná-los ou recebê-los. A exploração segue as mesmas regras de coleta e munição. Até três poderes podem ser carregados; repetir a coleta soma munição até 99. Reparos de chão mantêm cura direta ao coletar.

Rivais desarmados procuram caixas mesmo distantes; a seleção de ataque trata inventário vazio sem falhar. Torres só são desenhadas nos carros que carregam munição. Os modelos, shaders e física das pistas não foram alterados por esta correção.

## Testes executados nesta versão

- Flutter analyze: sem problemas.
- Suíte completa: 159 testes passaram, incluindo 26 de batalha/interface/contrato.
- Os 44 poderes foram coletados por colisão com item do mapa e cada quantidade foi esgotada até impedir novo disparo. Esse teste elimina a espera de recarga e esfria a arma entre tiros para isolar o consumo de munição; os limites de recarga/aquecimento continuam na produção e nos demais testes.
- Batalha e exploração começam vazias; disparar, trocar ou selecionar arma não possuída não concede poderes. Não há fallback infinito. As 44 opções aparecem no ciclo de coletas; o limite de três armas e munição até 99 foi verificado. Um bot recebe munição somente quando toca o item.
- Em 1280×720 e 800×360: HUD vazio, disparo vazio bloqueado, coleta real de metralhadora, aceleração+direção+tiro simultâneos, cancelamento de toque, arsenal com Quantum não coletado bloqueado, seleção de arma carregada, teclado bloqueado no pause, edição e salvamento do HUD.
- Após restringir o manifesto aos 20 MP3s e ao catálogo, os seis testes de música foram repetidos e passaram.
- 32 testes JVM passaram: 19 de música, 7 do contrato gráfico de corrida e 6 de batalha. Decodificam os payloads reais de 114/129 slots gerados pelo Flutter. JUnit/Hamcrest oficiais da distribuição Gradle foram usados offline; nenhum código ou dependência de produção foi substituído.
- Quatro vistas GLES foram renderizadas no Mesa EGL: carro desarmado, metralhadora, míssil e discos. Os dois programas de shader compilaram, sem erros GLES. As 65 cenas foram exportadas com o catálogo atualizado; somente essas quatro foram renderizadas nesta correção.
- Dezoito partidas simuladas, seis arenas × fácil/normal/difícil, terminaram com posições finitas dentro do ambiente: 2423 disparos e 58 eliminações, de 7.275 a 231.158 segundos. A condução do jogador nessa simulação usa o controlador de referência e não representa habilidade humana nem balanceamento final.

## Preservação e limites

31 carros, 26 circuitos, seis arenas com nove loops, os 13 poderes de corrida, músicas, direção manual, editor de HUD e salvamentos mantidos. Corridas e campeonato continuam com suas regras de grid e progressão. Estatísticas de batalha são separadas dos recordes de corrida.

Não houve instalação ou execução em celular físico/emulador Android, audição Android, medição de FPS, memória total no aparelho, bateria ou toque em hardware. As capturas de HUD/menu vêm de testes de widgets com textura e áudio simulados; as imagens 3D usam o mesmo motor GLES em Mesa e posições preparadas. Alguns bots ainda podem passar períodos presos entre veículos ou objetos. Atualizar sobre a versão anterior usa o mesmo pacote e certificado, mas o fluxo real de atualização deve ser validado no aparelho.

A validação anterior está em VALIDACAO_v011.md. Os números e imagens daquela versão são históricos; este documento descreve o que foi repetido na 0.11.1.
