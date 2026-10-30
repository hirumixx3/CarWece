# Validação — CarWece 0.12.2+19

## APK

`CarWece_v0.12.2_hirumisu.apk`: 248118480 bytes.
SHA-256: `d998d3b52757458b63b256e9723d1679ede234f842537297a1cca28920b78ff5`.
Pacote com.hirumisu.carwece, nome CarWece, versionCode 19, Android minSdk 24 / targetSdk 35, ARMv7, ARM64 e x86_64. Certificado SHA-256 `9e1be273e6871c23013157fad5378ffc4d5da5b222d70f84a995c8cb94ca8d7a` preservado. Assinatura v2, CRC, alinhamento de 16 KiB, 20 PNGs compilados e duas camadas adaptativas conferidos. Os seis ELF têm tabelas dentro dos limites dos arquivos; as três libflutter.so correspondem às da versão anterior. Nenhum arquivo temporário foi empacotado.

As vinte músicas foram comparadas por bytes/SHA-256 às fontes e ao catálogo e permanecem sem compressão ZIP. O MP4 original de abertura também foi comparado integralmente e tem SHA-256 `4e5395f7cbe6db3e29f1081c1bdc56a6c40adaf077c8a70fb9f795528fdcf204`. Mantidos todos os canais e as 44 identidades de poderes no AOT. Ver apk_verify_v0122.txt, apk_meta.json, native_integrity_v0122.json, icons_v0122.json e r8_music_v0122.json.

## Testes executados

- **183 testes Flutter aprovados** na suíte completa, incluindo física a 30/60/120 FPS, colisões de carros/pistas/rampas, repouso e esterçamento na largada, ré, queda em loop, controles multitoque, fumaça espacial, armas por coleta, munição finita, mira, pódio, progressão, campeonato, HUD, música e abertura. O controlador de referência completou os 26 circuitos por três voltas. Analisador sem problemas.
- **51 testes JVM aprovados**, zero falhas, erros ou ignorados: contratos gráficos de corrida/batalha, música, abertura e nove regressões de indexação, compactação, regiões, teste de volume e ajuste de orçamento. A compilação Android usa o mesmo código Kotlin de produção. JUnit/Hamcrest oficiais em cache; nenhum substituto do backend entra no APK.
- A nova projeção foi comparada à anterior em todas as 26 pistas e seis arenas, com deslocamentos laterais e alturas variados, coordenadas negativas, fallback distante e expulsão dos caches limitados. Normais/transformações do desenho não participam da física.
- Preparação em isolate retorna os mesmos bytes de cenário/modelos, sem remapear os 114/173 slots. Os testes de interface aguardam a preparação real e mantêm as asserções de controles, HP, armas e fumaça. Uma regressão segura a resposta de criação nativa por dez segundos simulados: a largada permanece em 3,2 segundos até o 3D ficar pronto. Outra verifica a animação do menu imediatamente após minimizar e retornar.

## CPU no computador

O mesmo tools/performance_qa.dart foi compilado em AOT contra a fonte original 0.12.1 e a atual, com o mesmo Dart 3.9.2. Foram duas execuções alternadas de cada versão, 1.800 atualizações por caso, descartando as primeiras 300. São três cargas: corrida no quarto, corrida difícil em arcade_dual e batalha na garagem com os seis participantes vivos durante toda a amostragem. A carga inclui simulação a 120 Hz e geração do pacote de quadro a 60 Hz. Na batalha, HP alto apenas no benchmark evita o término antecipado; isso não altera o jogo entregue.

Os seis pares tiveram **checksums das trajetórias idênticos**. O tempo médio de CPU caiu 75,1–81,3% nas cargas medidas. As medianas da primeira execução foram: quarto 2.398 → 696 µs, arcade_dual 1.295 → 606 µs, batalha 2.615 → 573 µs. As da segunda execução foram 2.367 → 669 µs, 1.190 → 523 µs e 2.609 → 565 µs. Os percentis, médias e checksums estão em performance_comparison_v0122.json e nos quatro performance_*_aot_*.json.

Esses números são de CPU no host, **não FPS de Android**. Medições JIT preliminares têm nomes sem `_aot`; o caso de batalha inicial encerrava cedo, portanto esses arquivos preliminares não sustentam a comparação final.

## Geometria e preservação visual

tools/RenderProbe.kt foi compilado junto às implementações reais RenderGeometry.kt e GraphicsContract.kt, executando indexação, compactação, divisão e testes de volume nas 206 malhas exportadas. O catálogo contém 33 cenários/showroom e 173 modelos/efeitos. Os buffers passaram de **598,852,368 para 343,925,196 bytes**, redução de 42,57%. O catálogo completo não fica carregado numa corrida; esse total não mede a RAM total de um celular.

Todos os triângulos e posições foram preservados. Índices reconstroem os atributos originais antes da compactação. Posição e UV usam float de 32 bits; normais usam 16 bits normalizados, RGB oito bits e material um byte, em vértices de 32 bytes. A regressão limita o erro da normal a 1/32767 por componente antes da normalização do shader e verifica separação de materiais/normais em posições coincidentes. Bounds são calculados com as posições originais e margem conservadora. Transformações espelhadas, rotações e escala não uniforme foram verificadas.

Foram renderizadas e decodificadas **178 imagens GLES** no Mesa llvmpipe: todos os 31 carros na garagem, 26 largadas e 121 cenas das seis arenas, seus nove loops, rampas, salas, 44 equipamentos montados e seus efeitos. Os dois programas de shader compilaram, sem erro GL ou imagem vazia. O formato compacto, VAOs e índices foram usados no desenho real. Nos 178 quadros, a soma de triângulos submetidos na cena e nas sombras caiu de 49.114.852 para 22.951.489, redução de 53,27%, por rejeição conservadora de regiões/instâncias fora dos volumes da câmera/luz. Esses totais não medem tempo da GPU.

Outras **vinte cenas** validaram framebuffer pré-alocado, viewports de 704×396 e 1088×612, sombras de 768 e blit para 1280×720, correspondentes ao limite de 55% e ao nível inicial de 85% do AUTO. Foram testados tanto quatro como um ponto de amostragem de sombra nas etapas apropriadas; ALTA usa nove. O algoritmo de redução/recuperação sustentada e seus limites passaram nos testes JVM.

**Vinte cenas** foram comparadas ao shader 0.12.1 com a mesma geometria e parâmetros de revisão 1280×720/sombra 1536/sem MSAA. Maior diferença média de canal: 0,120734 em escala 0–255. Na pior cena, 0,137804% dos pixels tiveram algum canal com diferença acima de oito. Ver visual_comparison_v0122.json. A resolução adaptável pode suavizar a imagem; a preservação visual citada aqui refere-se à comparação em alta qualidade nos parâmetros iguais.

Os buffers binários e todas as imagens de trabalho foram omitidos do ZIP. A fonte, exportadores e resultados numéricos estão incluídos. Para reproduzir: execute `dart run tools/export_battle.dart gpu_qa_v0122`, depois `dart run tools/export_performance.dart gpu_qa_v0122` e `python3 tools/prepare_render_probe.py gpu_qa_v0122`. Compile tools/RenderProbe.kt com RenderGeometry.kt/GraphicsContract.kt usando o compilador Kotlin, execute passando os diretórios de entrada/saída, copie frames.json e os quatro shaders para a saída e use tools/render_gles_qa.py. A opção `--auto=.55` exercita o alvo adaptável. São necessários JDK/Kotlin e Mesa/Python com NumPy/Pillow para essas ferramentas de revisão.

## Limites e continuidade

Não houve instalação nem execução em Android físico/emulador, medição de FPS, RAM total, bateria ou temperatura, audição ou reprodução pelo MediaPlayer real do aparelho. O FPS opcional no jogo agora pode exibir a cadência informada pelo renderizador, mas nenhum valor de FPS de aparelho foi coletado nesta sessão. O código do sintetizador sem escrita silenciosa foi compilado; sua audição continua pendente.

As otimizações e o AUTO não garantem ausência de travamentos em qualquer dispositivo. O desempenho depende do aparelho, aquecimento, memória disponível e configurações. A mesma assinatura permite atualização sobre a versão anterior, mas o fluxo real de instalação ainda precisa ser testado no aparelho. Os 31 carros, 26 circuitos, seis arenas, armas visuais por coleta/munição finita, HUD, progressão, música, abertura completa e regras de corrida permanecem presentes.

O relatório anterior está em VALIDACAO_v0121.md; arquivos com nomes de versões anteriores são históricos, não medições desta versão.
