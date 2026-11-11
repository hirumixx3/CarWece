# CarWece no Windows — versão desktop completa

O CarWece agora roda no Windows com tudo que a versão Android tem:

- **Save em arquivo**: o progresso é gravado em
  `Documentos\CarWece\save.json` (mesmo formato e mesmo limite do save
  do Android — dá pra copiar o arquivo entre máquinas).
- **Intro em vídeo**: a abertura `carwece_intro.mp4` toca no Windows via
  media_kit, com os mesmos estados da versão Android (carregando,
  pausada, erro com tentar de novo) e a música só começa depois dela.
- **Música completa**: diretor de trilhas portado 1:1 do Android
  (playlists de menu/corrida/batalha, shuffle com bolsa que não repete,
  modo sequencial, pular faixa, seleção manual, recuperação de erro).
- **Efeitos e motor**: os sons sintetizados do Android foram renderizados
  nas mesmas fórmulas em `assets/sfx/`; o ronco do motor é um loop cuja
  velocidade de reprodução acompanha a velocidade do carro e o turbo.
- **Online completo**: entrar em sala funciona como no Android; hospedar
  também — a identidade TLS da sala (certificado autoassinado RSA-2048
  com pin) agora é gerada em Dart, e os túneis Pinggy/Bore já eram Dart.
- **Render 3D de verdade (Direct3D 11)**: plugin nativo próprio em
  `plugins/carwece_graphics/`, falando o mesmo canal
  `com.hirumisu.carwece/graphics` e os mesmos pacotes de quadros do
  renderizador Android — cenário completo, materiais, sombras PCF e
  transparências ordenadas, com os shaders portados de GLSL pra HLSL.
  Se o D3D11 falhar por qualquer motivo, o jogo cai sozinho pro
  renderizador de compatibilidade (Canvas). Divergências conscientes
  desta primeira versão: sem MSAA e sem a resolução adaptativa do
  Android (no desktop renderiza sempre na resolução alvo).
- **Carros detalhados também no Canvas**: enquanto o 3D nativo não
  sobe (ou se ele falhar), garagem/menu usam o modelo real dos carros
  e, na corrida, o carro do jogador — nada do genérico de caixas.
- **Intro**: corrigida a trava que segurava o jogo no último frame do
  vídeo até a janela mudar de foco.
- Controles de teclado (setas/WASD, Q/E/C/X, Esc) já existiam e
  funcionam.

Nada do Android mudou: todo o código novo fica atrás da chave
`isWindowsDesktop` (`lib/desktop/`), e a suíte segue verde (290 testes).

## Como gerar o executável

1. Suba o código pro GitHub (commit + push, como sempre).
2. No GitHub: **Actions → "CarWece - Windows" → Run workflow**
   (versão 1.6.1, código 12).
3. Ao terminar, baixe o artifact **CarWece-Windows**: dentro vem
   `CarWece-Windows-1.6.1-12.zip` com o `CarWece.exe` e as DLLs.
4. Extraia a pasta inteira e abra o `CarWece.exe` (precisa das DLLs do
   lado — não mova o .exe sozinho). Na primeira abertura o Windows pode
   mostrar o SmartScreen por o executável não ser assinado: **Mais
   informações → Executar assim mesmo**.

Build local neste ambiente não é possível (compilar pra Windows exige um
Windows com Visual Studio) — por isso o build é pelo GitHub Actions.

## Controles no Windows: teclado total e teclas configuráveis

- A corrida **não pausa mais sozinha** no Windows: eventos transitórios de
  janela ("inactive") não congelam mais a corrida nem matam os controles
  (a mesma causa raiz já corrigida na intro).
- Os **botões de toque somem** da corrida/batalha no Windows (direção,
  acelerar, freio, drift, turbo, item, arma, mira, pausa e repor carro) e o
  mouse não dirige mais o carro por retângulos invisíveis: cada comando
  fica numa tecla.
- **Opções → CONTROLES DO TECLADO** (seção só do Windows): cada comando
  pode ser remapeado — tocar em TROCAR e pressionar a tecla nova. Botão
  RESTAURAR TECLAS PADRÃO volta ao layout original. As escolhas são salvas
  junto das outras configurações.
- Padrões: setas = direção/acelerar/freio, Shift esq = drift, Espaço =
  turbo, X = item/atirar, C = supercarga (corrida) e trocar mira
  (batalha), Q = trocar arma, E = arsenal, R = repor carro, Esc = pausar.
- A dica no início da corrida mostra as teclas atuais configuradas.

## Desempenho e entrada: leitura de pixels sem travar o jogo

- Causa do travamento geral (e do teclado/mouse "mortos"): a leitura dos
  pixels do Direct3D mapeava a textura **recém-copiada** a cada quadro —
  essa chamada bloqueia até a GPU terminar o quadro inteiro, na thread
  principal do Windows, que é a mesma que entrega teclado e mouse ao
  jogo. Cada quadro custava a latência inteira da GPU e a entrada ficava
  enfileirada atrás dele.
- Correção: anel de 3 texturas de leitura — copia o quadro novo numa
  ponta e lê a textura de **dois quadros atrás**, que a GPU já terminou
  há muito tempo. Nada de espera por quadro; a imagem atrasa 2 quadros
  (~33 ms) e o fluxo destrava.
- Teclado da corrida ganhou um segundo caminho: além do handler global,
  a tela da corrida agora segura o foco do teclado (KeyboardListener),
  que é o caminho padrão de jogos desktop no Flutter.

## Entrada viva + diagnóstico da placa (11/11/2026)
- **Por que o anel de 3 texturas não resolveu:** ele só adiava o `Map` da
  leitura de pixels. O `Render` inteiro roda síncrono na thread de
  plataforma do Windows — a mesma que entrega teclado e mouse — e o limite
  de 16 ms media desde o INÍCIO do quadro anterior: com o quadro lento, o
  próximo Render começava no instante em que o anterior terminava e a
  thread nunca ficava livre pra bombear a entrada.
- **Correção:** depois que cada quadro TERMINA, o jogo espera 8 ms antes
  de pedir o próximo (só no Windows; no Android nada muda). Teclado e
  cliques passam a ter uma janela garantida a cada quadro, mesmo com o
  quadro lento. Resolução, qualidade e sombras não mudam.
- **Diagnóstico na tela:** com "Mostrar FPS" ligado nas Opções, a linha do
  FPS agora mostra também o driver (`HARDWARE` ou `WARP`), o nome da placa
  e o tempo de cada quadro (`render XXms`). Se aparecer `WARP`, o notebook
  está renderizando por software — aí o próximo passo é outro (driver ou
  nível de recurso), não mais ajuste de leitura de pixels.
