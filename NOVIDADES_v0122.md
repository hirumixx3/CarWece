# CarWece 0.12.2+19 — otimização

Instale `CarWece_v0.12.2_hirumisu.apk` sobre a versão anterior, sem desinstalar. Nome, pacote `com.hirumisu.carwece`, certificado, ícone e dados do jogador preservados.

## Durante o jogo

- **AUTO** passa a ser a qualidade inicial, inclusive na primeira atualização de configurações antigas. Ajusta a resolução interna conforme o custo e a cadência sustentados dos quadros. A imagem pode ficar menos definida quando o aparelho estiver sobrecarregado; HUD e botões continuam na resolução da interface. BAIXA, MÉDIA e ALTA continuam disponíveis e uma nova escolha explícita é salva.
- O modo automático começa em 85% de uma base de 1280 pixels de largura, pode reduzir até 55% ou subir até 100%. Isso corresponde a 1088, 704 e 1280 pixels de largura. Não fica recriando texturas a cada alteração: um alvo pré-alocado recebe a cena e é ampliado para a textura de saída.
- Sombras menores, filtro com menos amostras em AUTO/BAIXA/MÉDIA e antisserrilhamento de quatro amostras reservado à ALTA. ALTA mantém os modelos completos, resolução de até 1600 pixels, sombras de 2048 e filtro de nove amostras.
- Fumaça, escudo, gelo e fogo deixam de calcular iluminação/sombras que eram descartadas antes de formar sua cor final. O comportamento espacial da fumaça permanece igual.
- HUD e animações do menu atualizam a 30 Hz. Entradas multitoque e passos físicos continuam independentes disso. A simulação permanece em **120 Hz**, com aceleração e direção manuais.
- Mapas reutilizam as partes estáticas; carros, portões e itens continuam sendo atualizados. O contador opcional distingue FPS 3D, informado pelo renderizador, de FPS da interface enquanto a primeira amostra não chega.

## Memória, renderização e carregamento

- Cenários divididos em regiões, com teste conservador contra os volumes da câmera e da luz. Geometria fora desses volumes deixa de ser enviada para desenho; as colisões continuam ativas.
- Vértices duplicados são indexados. Posições e UVs continuam em float de 32 bits; normais usam inteiros normalizados de 16 bits, cor RGB usa 8 bits por canal e o material usa um byte. Nenhum triângulo foi removido dos carros ou pistas. O limite do erro por componente das normais é 1/32767 antes da normalização no shader.
- VAOs e posições de uniforms são reutilizados. Os grandes arrays temporários do Android são liberados depois do envio à GPU; a preparação ocorre em uma função separada do laço de renderização.
- As malhas procedurais de corrida, batalha e garagem são construídas em um isolate temporário, mantendo a interface disponível durante a preparação. A contagem de largada só começa depois de o primeiro quadro 3D estar pronto. O antigo cenário alternativo só é construído quando necessário.
- Quadros gráficos são enviados no máximo perto de 60 Hz. O Android mantém o estado mais recente e espera por novas informações, sem laço de consulta de seis milissegundos. Ao minimizar, a renderização pausa.
- Projeções de contato reutilizam candidatos espaciais e posições imutáveis idênticas em caches limitados; vetores intermediários e cálculos repetidos foram reduzidos. Coordenadas não são arredondadas. A trajetória foi comparada à implementação anterior.
- O sintetizador deixa de escrever PCM silencioso continuamente quando apenas a música do menu está tocando ou os efeitos estão mudos. As vinte músicas e o vídeo original permanecem completos.

## Verificação e limites

Passaram **183 testes Flutter**, **51 testes JVM** e o analisador. Foram renderizadas **178 cenas GLES**: todos os 31 carros na garagem, largadas dos 26 circuitos e cenas das seis arenas com loops, rampas e os 44 equipamentos. Outras vinte cenas verificam o framebuffer e a ampliação no limite de 55% e no nível inicial de 85% do AUTO. Vinte cenas foram comparadas ao renderizador/shader anterior na mesma resolução.

Em duas execuções AOT no computador, o tempo médio de CPU de três cargas de simulação e geração de quadros caiu **75% a 81%**, com checksums das trajetórias idênticos. No catálogo medido de 206 malhas, os buffers de geometria passaram de 598.852.368 a 343.925.196 bytes (**42,57% menores**). Esses são totais de buffers do catálogo, que não fica todo carregado numa corrida. Nas 178 cenas de revisão, os triângulos enviados, somando cena e sombras, diminuíram **53,27%**. O número efetivamente exibido depende da câmera.

Esses valores **não são FPS, consumo total de RAM nem medições em Android físico**. Não houve teste de instalação, toque, áudio, vídeo, aquecimento ou bateria em celular/emulador nesta sessão. O ajuste automático e a redução de trabalho não garantem ausência de travamentos em qualquer aparelho. Consulte `verification/VALIDACAO.md` para resultados e comandos.

Mantidos os 31 carros, 26 circuitos, seis arenas, armas apenas por coleta e com munição finita, editor de HUD, progressão, largada do campeonato, física dos loops, vídeo de abertura integral e músicas.
