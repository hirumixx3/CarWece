# CarWece 0.7.1 — correção da fumaça

Autoria: **hirumisu**. Data: **27/10/2026**. Pacote `com.hirumisu.carwece`, versão 0.7.1, código 10.

## Falha reproduzida e correção

O teste com o jogador dentro da fumaça reproduziu `Incorrect use of ParentDataWidget` na v0.7.0, em 1280×720 e 800×360. A camada `Positioned.fill` estava dentro da coluna de um indicador do HUD. Na v0.7.1 ela pertence ao `Stack` principal, atrás dos indicadores e controles.

A exposição deixou de ser um temporizador de cegueira e passou a ser calculada a cada passo físico, usando o mesmo centro e raio da nuvem desenhada. Saiu da nuvem: exposição zero na próxima atualização. Nuvens expiradas ou removidas são descartadas antes da consulta. A opacidade é limitada e as sobreposições usam o maior valor, sem acumular até uma tela opaca.

## Testes atuais

- **106 testes Flutter passaram**, incluindo os 100 anteriores e seis novos testes da fumaça.
- Saída e reentrada com a mesma nuvem ainda viva; limpeza no primeiro passo fora do volume e ao repor o carro.
- Carro parado dentro da nuvem, expiração e remoção de nuvens sem efeito residual.
- Fumaça própria ignorada, múltiplas nuvens sem acumular opacidade e carro em outra altura sem ser afetado.
- Volume de detecção corresponde ao centro/raio enviados ao motor gráfico, com transição suave nas bordas e ao dissipar.
- HUD com plataforma Android simulada em **1280×720 e 800×360**, incluindo margens de tela, três ciclos de entrada/saída segurando acelerador e direção, expiração da nuvem e liberação dos controles. Sem exceções; camada ocupa a área inteira e não recebe toques.
- Analisador Flutter sem ocorrências.
- **7 testes JVM Android passaram**, usando o pacote StandardMethodCodec real gerado pelo Flutter com 54 malhas. Falhas/erros: zero.
- APK universal ARMv7, ARM64 e x86_64 compilado. Manifesto: CarWece, `com.hirumisu.carwece`, versão 0.7.1, código 10, minSdk 24 e targetSdk 35.
- Assinatura v2 verificada com o mesmo certificado anterior; alinhamento de 4 bytes/16 KiB aprovado. ZIP íntegro, seis bibliotecas ELF válidas e canais nativos conferidos nos três ABIs.
- 20 PNGs de ícone compilados conferidos contra os pixels visíveis/alfa das fontes. Dois ícones adaptativos resolvem as camadas corretas; mestres RX-7/Liquid Glass preservados.

Os testes de interface usam uma textura Android simulada. Não houve instalação/execução em celular físico neste ciclo; desempenho e a experiência no aparelho ainda dependem desse teste.

## APK

Arquivo: `CarWece_v0.7.1_hirumisu.apk`. Tamanho: **46851660 bytes**.

SHA-256: `d292c2cd02f5fdaa2edd85c0ca6f585330459517d73dd2b0c5bf4fc868b10fd6`.

Certificado SHA-256: `9e1be273e6871c23013157fad5378ffc4d5da5b222d70f84a995c8cb94ca8d7a`.

## Evidências

Atuais: `tests.txt`, `analyze.txt`, `native.txt`, `android_jvm_v071.xml`, `smoke_v071.txt`, `build.txt`, `manifest.txt`, `manifest_tree.txt`, `resource_values.txt`, `signature.txt`, `alignment.txt`, `icons_v071.json`, `elf_v071.json` e `apk_meta.json`.

`smoke_v070_expected_failure.txt` registra a falha esperada, antes da correção. O relatório completo da versão anterior está em [VALIDACAO_v070.md](VALIDACAO_v070.md). As 71 cenas GLES e a simulação dos 60 adversários são evidências históricas da v0.7.0. Malhas e shaders não mudaram nesta correção; os testes atuais verificam as transformações das nuvens e a interface.

Pacote, assinatura, ícone e formato do progresso foram preservados. A correção não muda o circuito nem a família de recordes `layout7`.
