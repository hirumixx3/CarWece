# Validação CarWece 0.11.0+15 — Batalha e Mundo Aberto

## APK entregue

- CarWece_v0.11.0_hirumisu.apk: 252776973 bytes.
- SHA-256: `f286cf0f4c9bd656f7098be267df570442e840bb8e42284c5534f2730dec82ac`.
- Pacote com.hirumisu.carwece, nome CarWece, versão 0.11.0, versionCode 15.
- Android minSdk 24, targetSdk 35; ARMv7, ARM64 e x86_64.
- Mesmo certificado SHA-256: `9e1be273e6871c23013157fad5378ffc4d5da5b222d70f84a995c8cb94ca8d7a`.
- Assinatura v2, CRC do ZIP e alinhamento de arquivos/bibliotecas de 16 KiB verificados.
- 20 PNGs compilados e 2 ícones adaptativos comparados às fontes aprovadas.
- Os três canais de integração foram encontrados no DEX e nas três bibliotecas AOT. As 44 identidades de BattlePower estão presentes nos três libapp.so.
- O shader de status sem iluminação foi comparado ao shader incluído no APK. O restante dos materiais de corrida mantém a renderização anterior; as barras de vida usam material 18 e não projetam sombras.

## Conteúdo e separação de modos

31 carros e 26 pistas de corrida mantidos, com seis arenas adicionais em lista independente. Quarto, Garagem, Banheiro, Cozinha, Sala e Arcade têm um ou dois loops cada, nove ao todo. As arenas usam chão livre e objetos sólidos, sem barreiras que conduzam o jogador por checkpoints. As 44 armas/variantes de batalha têm enumeração, nome, referência, munição, dano, recarga e comportamento no catálogo. Os 13 poderes de corrida continuam no modo anterior.

Batalha usa 100 de vida por carro, eliminações, sobrevivência, limite de cinco minutos e estatísticas próprias. Exploração usa três alvos passivos reconstruídos, todos os poderes e nenhum ganho de moedas ou recordes. Carreira, estrelas, recordes, HUD e ordem de largada do campeonato continuam separados e preservados.

Os vinte MP3s foram verificados por bytes e SHA-256 ao catálogo/fonte e estão armazenados sem compressão ZIP para MediaPlayer.openFd. O catálogo JSON empacotado foi comparado à fonte. Legends Never Die continua no menu e as outras 19 faixas compõem as corridas e arenas. Esta versão mantém os arquivos de áudio já validados e não os recodifica.

## Testes Flutter

A suíte completa passou com 154 testes. Inclui as regressões anteriores e 21 verificações novas de batalha. Após finalizar os traçados das arenas, os efeitos de propulsão e a recompensa por vitória rápida, os 21 testes de batalha, interface e contrato foram repetidos e passaram.

- Catálogo com seis arenas e 44 armas; IDs separados das 26 pistas.
- Vida individual, escudo, reparo e limpeza de estados temporários.
- Projéteis com varredura contínua; cobertura bloqueia tiros e lasers comuns; raios especiais usam penetração.
- Mísseis, foguetes, discos, rajadas, canhão, tiro cinético e metralhadora causam dano real.
- Morteiros balísticos, bomba criogênica, barril de óleo, minas, atração magnética e temporizadores.
- Descargas elétricas, flares, pulsos, terremoto, sondas, globo e enxame.
- Fumaça tóxica amostrada espacialmente: sair limpa a exposição no próximo passo.
- Dano dobrado, rodas cortantes, bônus, escudo, recarga e consumo de munição.
- Carros eliminados param de combater; eliminações só contam uma vez; resultado independe de voltas.
- Exploração não distribui recompensas; alvos são passivos e se reconstroem; pause congela a simulação.
- Sem acelerador o jogador fica parado; direção manual e rotação/esterçamento dos pneus continuam ativos; nada de checkpoint obrigatório nas arenas.
- Navegação contorna objetos; inversões lentas nos nove loops causam queda física.
- Em 1280×720 e 800×360: menu, seis arenas, exploração, acelerador+direção+tiro simultâneos, cancelamento de toque, vida, busca e seleção de arma no pause, bloqueio do teclado no arsenal, edição/salvamento do HUD e retorno à partida.
- Histórico e recompensa de batalha persistem sem alterar medalhas, recordes e estatísticas de corrida. Salvamento duplicado do mesmo resultado é ignorado.

## Android e GLES

32 testes JVM passaram: 19 da trilha sonora, 7 do contrato gráfico anterior e 6 do contrato de batalha. Os testes decodificam os payloads reais exportados pelo Flutter: 114 slots nas corridas e 129 nas batalhas. O limite nativo continua em 160 modelos e 128 instâncias. Foram verificados vida, torres, projéteis, materiais, transparência do gás, valores finitos, rejeição de índices inválidos e ausência de sombra nas barras de vida.

JUnit 4.13.2 e Hamcrest 1.3 foram usados offline a partir dos JARs incluídos no Gradle 8.12, sem alterar as dependências de produção. As identidades estão em junit_offline_v011.json.

65 vistas do mesmo motor GLES foram exportadas e renderizadas no Mesa EGL: seis visões gerais, seis câmeras de condução, nove vistas de loops e uma vista para cada um dos 44 poderes. Os dois programas de shader compilaram e não houve erro GLES. As vistas de poder e revisão usam posições preparadas e o código/mesmas malhas da implementação.

## Simulações de condução e combate

As nove passagens rápidas de loop foram verificadas com acelerador e direção do controlador de referência, usando a mesma física. Todas chegaram à saída sem queda indevida, em 6.29 a 7.23 segundos. Separadamente, parar invertido sem apoio causa queda, coberta pelos testes Flutter.

As seis arenas foram simuladas nos níveis fácil, normal e difícil: 18 partidas encerraram corretamente, com posições finitas e dentro do ambiente. Foram registrados 4549 disparos e 47 eliminações. Duração: 21.2 a 227.1 segundos. A condução de referência não representa a habilidade de um jogador humano.

A IA escolhe inimigos, suprimentos, reparos e caminhos. Recuo e rotas de escape são físicos. As simulações registram tentativas de escape; alguns carros ainda podem passar períodos presos entre objetos ou veículos. Não há afirmação de navegação perfeita ou balanceamento final.

## Limites da validação

Não houve instalação ou execução em celular físico/emulador Android, audição pela saída Android, medição de FPS, memória total em aparelho, bateria ou teste de toque em hardware. Os testes verificam código, dados, interface com canais controlados e renderização GLES no host. O projeto é uma versão de teste para validação no aparelho do usuário.

Carregamento do mundo e modelos continua com cache limitado e modelos dos carros participantes; os quinze novos modelos de efeitos são enviados apenas na batalha. Existem limites de projéteis, zonas e instâncias. Esses controles não substituem medição de desempenho no dispositivo.

As capturas de menu/HUD são de widgets com textura/áudio simulados. As imagens 3D são do motor GLES no Mesa, com cenas preparadas. A pesquisa dos jogos de referência está em PESQUISA_BATALHA.md; não foram reproduzidos vídeos ou executados emuladores deles. Instalar por cima preserva o mesmo pacote/certificado; o fluxo real de atualização no aparelho ainda precisa ser verificado.
