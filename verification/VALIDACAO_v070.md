# CarWece 0.7.0 — validação

Autoria: **hirumisu**. Data: **27/10/2026**. Pacote `com.hirumisu.carwece`, versão 0.7.0, código 9.

## Resultado

- **100 testes Flutter passaram.** Além dos controles, multitoque, pausa, carreira, persistência, chegada, rodas, colisões e loop das versões anteriores, há teste de ultrapassagem física partindo de uma fila, barreira de objetos, quebra de portão por míssil, todos os dez atalhos, sorteio de nove itens, cargas, SUPER, EMP, gelo, Tesla, minas, fumaça e HUD em 1280×720 e 800×360.
- Os dez atalhos foram percorridos em duas situações: portão já aberto e entrada com portão fechado seguida por disparo de míssil dentro do caminho. Nos dois casos houve reintegração ao checkpoint correto, sem recuperação do piloto de QA. Pular diretamente para a saída não concedeu os checkpoints omitidos.
- Analisador Flutter sem ocorrências.
- **7 testes JVM Android passaram**, decodificando o StandardMethodCodec gerado pelo Flutter, agora com **54 malhas**. Conferem geometria, transformações, índices, materiais transparentes e mensagens inválidas.
- **71 cenas renderizadas em Mesa EGL/GLES**, com malhas, shaders e pacotes reais. Ambos os programas GLSL compilaram; todos os quadros terminaram sem erro GLES. Incluem carros, circuitos, ambientes, loop, explosões, tráfego de IA, portão fechado/destruído, atalho e poderes novos.
- **60 de 60 adversários completaram uma volta**: cinco em cada um dos 12 circuitos. Houve mudanças de ordem em todos, de 4 a 18 por simulação. Desvio lateral amostrado de 6,54 a 12,52 unidades. Os tempos para terminar todo o pelotão variaram de 63,9 a 128,6 segundos. O teste usou corrida de uma volta e jogador estacionado fora do pelotão.
- Houve **duas recuperações da IA no Quarto em Chamas**, e zero nas outras onze pistas. A recuperação retorna ao último checkpoint validado, ou antes do loop com progressão recuada, e não concede avanço. O teste específico de ultrapassagem terminou sem recuperação.
- O quadro `ai_real_traffic` usa seis segundos de física/controles reais, sem posicionar os adversários artificialmente em faixas. O JSON `ai_snapshot_v07.json` registra as posições; a câmera foi ajustada para mostrar o pelotão.
- O quadro de destruição do portão foi produzido por um míssil efetivamente colidindo com o painel. Cenas de outros poderes usam estados de QA explicitamente montados para inspecionar efeitos; as prévias não são capturas de celular.
- Build universal ARMv7/ARM64/x86_64 concluído. Manifesto compilado: CarWece, pacote e Activity `com.hirumisu.carwece`, versionName 0.7.0, versionCode 9, minSdk 24 e targetSdk 35.
- Canais de persistência/gráficos conferidos nos DEX e snapshots Dart dos três ABIs. Os seis ELF têm cabeçalhos e segmentos dentro do arquivo. ZIP do APK íntegro, assinatura v2 e alinhamento de 4 bytes/16 KiB verificados.
- Os 20 PNGs do ícone compilado correspondem aos recursos fonte nos pixels visíveis/alfa; os dois XMLs adaptativos resolvem as camadas aprovadas. Os hashes dos mestres RX-7/Liquid Glass permanecem iguais.

## APK desta entrega

Arquivo: `CarWece_v0.7.0_hirumisu.apk`. Tamanho: **46786124 bytes**.

SHA-256: `e9e799884704ec3c5d8f343096e6311c93690a94a893e73b526fe32094a9d106`.

Certificado SHA-256: `9e1be273e6871c23013157fad5378ffc4d5da5b222d70f84a995c8cb94ca8d7a`.

## Registros atuais

`tests.txt`, `analyze.txt`, `native.txt`, `android_jvm_v07.xml`, `build.txt`, `export.txt`, `gles.txt`, `rivals.txt`, `course.txt`, `shortcuts_v07.txt`, `ai_snapshot_v07.json`, `manifest.txt`, `manifest_tree.txt`, `resource_values.txt`, `signature.txt`, `alignment.txt`, `icons_v07.json`, `elf_v07.json` e `apk_meta.json` pertencem à v0.7. Relatórios com sufixos anteriores e prefixo `carwece_` são históricos.

## Limites do teste

Este ciclo não instalou nem executou o APK em um celular físico. JVM valida o contrato nativo sem abrir EGL; Mesa verifica shaders/geometria sem reproduzir todo o ciclo Android/SurfaceTexture. Desempenho, áudio, multitoque prolongado, instalação/atualização e interação com o launcher precisam de teste no Android do jogador.

A dinâmica é arcade, com contato, gravidade e inércia. Não há suspensão completa, pneus deformáveis ou amassados permanentes. Somente os painéis dos portões são destrutíveis; os demais objetos continuam sólidos. As 71 cenas não equivalem a uma medição de quadros por segundo no celular.
