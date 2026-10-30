# CarWece 0.8.0 — validação

Autoria: **hirumisu**. Data: **27/10/2026**. Pacote `com.hirumisu.carwece`, código Android 11.

## Conteúdo desta versão

16 carros, 18 circuitos em seis ambientes, 16 atalhos com portão e editor de HUD de 16 elementos. Os doze carros e doze percursos anteriores mantêm seus IDs. Editor com movimento independente, escala de 65% a 180%, rascunho, salvar, cancelar e padrão. Normal/Difícil receberam seleção de carros por desempenho, antecipação de curvas, turbo com energia e armas táticas.

## Resultados

- **115 testes Flutter passaram.** Incluem as regressões anteriores de física, loop, rodas, controles, chegada, poderes, carreira e fumaça, além de editor, persistência, falha de gravação, seleção de rivais, energia e preservação da dinâmica do jogador.
- Depois do ajuste visual do painel do editor, **13 testes de HUD e fluxo passaram**. Cobrem acesso pelas Configurações e Pausa, arraste, tamanho, salvar/recarregar, cancelar, padrão, erro de gravação e controles reposicionados em 1280×720 e 800×360. Os gestos de deslizar entre setas e acelerador/drift continuam funcionando com múltiplos dedos.
- Depois do ajuste final da asa do F40, **5 testes de malha/ponte gráfica passaram** com todos os 16 carros. Conferem triângulos/normais, materiais, transformações no loop e o pacote StandardMethodCodec de 66 malhas.
- Analisador Flutter sem ocorrências.
- **7 testes JVM Android passaram**, com o pacote real de 66 malhas, índices, rodas, transparência e mensagens inválidas. O limite de modelos nativo é 96. A compilação dos testes Kotlin foi refeita para descartar classes antigas do cache.
- **87 cenas GLES renderizadas** com vértices, shaders e transformações do jogo, incluindo os quatro carros novos e seis pistas novas. Ambos os programas GLSL compilaram e todos os quadros terminaram sem erros GLES.
- Os 16 carros concluíram uma volta do circuito com loop na simulação de QA, com rodas/esterçamento finitos.
- Os **cinco rivais concluíram cada uma das 18 pistas no Normal e no Difícil**: 180 chegadas em 36 pelotões, uma volta por corrida. Houve mudanças de ordem e dispersão lateral em todos os percursos. Nenhuma recuperação de IA foi necessária nesse conjunto. O jogador ficou estacionado fora do pelotão.
- Todos os 16 atalhos foram percorridos com controles/física, tanto já abertos quanto entrando fechados e disparando dentro do caminho. A reintegração validou o checkpoint correto. Pular diretamente para a saída não concede os portais omitidos.
- Comparação com a v0.7.1 em duas pistas, dois carros do jogador e duas sementes: oito pelotões por modo. A média das medianas de chegada passou de 76,66 para 62,88 s no Normal, e de 69,00 para 60,03 s no Difícil, cerca de 18%/13% menos. Isso mede esse cenário, com jogador estacionado, sem generalizar para todo o jogo.
- APK universal ARMv7/ARM64/x86_64 compilado. Manifesto: CarWece 0.8.0, código 11, minSdk 24, targetSdk 35, pacote/Activity correspondentes.
- Assinatura v2, ZIP íntegro, alinhamento de 4 bytes/16 KiB e seis ELF verificados. Canais nativos presentes nos DEX e snapshots Dart dos três ABIs.
- 20 PNGs do ícone compilado correspondem aos pixels visíveis/alfa da fonte; dois XMLs adaptativos apontam para as camadas aprovadas. Pacote, certificado e mestres do ícone preservados.

## APK

Arquivo: `CarWece_v0.8.0_hirumisu.apk`. Tamanho: **47474552 bytes**.

SHA-256: `2fce9567dfd394307105e43799c209d832a44d60b2fd725829dda77e4dd1c0ad`.

Certificado SHA-256: `9e1be273e6871c23013157fad5378ffc4d5da5b222d70f84a995c8cb94ca8d7a`.

## Evidências atuais

`tests.txt`, `analyze.txt`, `native.txt`, `android_jvm_v08.xml`, `hud_v08.txt`, `meshes_v08.txt`, `build.txt`, `export.txt`, `gles.txt`, `roster.txt`, `course.txt`, `rivals_normal.txt`, `rivals_hard.txt`, `difficulty_before_v08.json`, `difficulty_after_v08.json`, `ai_snapshot_v08.json`, `manifest.txt`, `manifest_tree.txt`, `resource_values.txt`, `signature.txt`, `alignment.txt`, `icons_v08.json`, `elf_v08.json` e `apk_meta.json`.

Os arquivos com sufixos de versões anteriores são históricos. A prévia `ai_real_traffic` usa posições de seis segundos de física real. Outras cenas posicionam carros/câmeras para inspecionar a geometria e os efeitos; isso não é apresentado como uma corrida capturada de celular.

## Limites

Este ciclo não instalou/executou o APK em celular físico. Widgets Android usam textura simulada; JVM valida o contrato gráfico, e Mesa EGL renderiza fora do Android. Desempenho, áudio, interação prolongada e atualização no aparelho precisam de teste no Android do jogador. As prévias não medem FPS do celular.

A arte é procedural e estilizada; física arcade com contato, gravidade e colisões. Não há simulação completa de suspensão, deformação de pneus ou amassados permanentes. Progresso e compras são preservados; novos circuitos usam IDs próprios e os anteriores mantêm os recordes `layout7`.
