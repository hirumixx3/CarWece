# CarWece 0.7.1 — fumaça

Autoria: **hirumisu**. Pacote `com.hirumisu.carwece`, código Android 10.

## Causa reproduzida

Na v0.7.0, a camada da fumaça estava dentro da coluna usada pelos indicadores de volta/tempo. `Positioned.fill` exige um `Stack`, mas recebia dados de layout de uma `Column`. Quando a fumaça de um adversário atingia o jogador, a árvore de widgets gerava `Incorrect use of ParentDataWidget` e a tela ficava com o retângulo incorreto. Os testes anteriores exercitavam fumaça em adversários, sem montar o HUD com o jogador afetado.

A regressão foi reproduzida antes da correção em testes de widgets com plataforma Android simulada, nas resoluções 1280×720 e 800×360.

## Correção

- Uma única camada de fumaça ocupa a área do jogo, como filha do `Stack` principal e atrás do HUD. Ela ignora toques e usa transparência limitada.
- A exposição é recalculada em cada atualização física. Ao sair do volume da nuvem, volta a zero na próxima atualização, sem temporizador residual de cegueira.
- Renderização e detecção usam o mesmo centro e raio da esfera de fumaça, inclusive seu movimento para cima. Há uma transição suave na borda e ao dissipar.
- Nuvens expiradas ou removidas não afetam o jogador. Múltiplas nuvens não somam opacidade até deixar a tela opaca. A fumaça do próprio carro não causa essa camada de visão.
- REPOR CARRO limpa a exposição anterior. Acelerador e direção continuam funcionando enquanto o efeito aparece ou desaparece.

## Validação

Seis testes específicos cobrem saída/reentrada, expiração com o carro parado, remoção de nuvens, recuperação, fumaça própria, sobreposição, altura, correspondência do volume com a malha e o HUD Android simulado em duas resoluções. Os testes de interface incluem três ciclos de entrada/saída com acelerador e direção mantidos, além de margens de tela.

Os registros anteriores à correção são preservados como reprodução esperada da falha. O resultado completo dos testes atuais e a identidade do APK estão em [verification/VALIDACAO.md](verification/VALIDACAO.md).

## Instalação

Instale `CarWece_v0.7.1_hirumisu.apk` por cima da versão anterior, **sem desinstalar**. O pacote, certificado de desenvolvimento, ícone e formato do progresso são os mesmos. A correção não altera os circuitos ou sua família de recordes `layout7`.

Não houve teste do APK em celular físico neste ciclo. A validação Android de widgets usa uma superfície de textura simulada; os testes JVM verificam o contrato nativo.
