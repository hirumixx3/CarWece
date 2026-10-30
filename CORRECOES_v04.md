# Pocket Rush 0.4 — direção e percurso

Autor: hirumisu. Android 0.4.0 / código 5.

## Causas corrigidas

- O movimento anterior calculava a posição por distância na spline e deslocamento lateral. A orientação acompanhava automaticamente as curvas. A v0.4 integra posição, vetor de velocidade e orientação no mundo; a projeção na pista fornece contato e progresso, não a direção do jogador.
- O transporte da orientação do loop e uma correção de torção eram distribuídos pelo circuito inteiro. A v0.4 limita a orientação invertida ao loop; estradas externas usam a vertical do ambiente como referência. Foram testadas todas as bordas e a saída do loop.
- Os controles ficavam entre elementos condicionais do HUD sem identidade estável. A região de direção e os pedais agora têm chaves persistentes, estado multitoque e geração de limpeza na pausa. Teclado e toque têm fontes separadas. As setas formam uma única região que acompanha o dedo durante o deslize.

## Percursos

- Três traçados ampliados para cerca de 4,6–4,9 mil unidades, em ambientes com chão de 1.800 × 1.800 unidades.
- Plástico com largura 42 e setores de piso livre com checkpoints de largura 96. O piso permanece dirigível fora do corredor.
- Loop com raio 62 e deslocamento lateral 70; ausência de torção após a saída e altura mínima de bordas validada.
- Curvas que exigem volante/freio, obstáculos de slalom, móveis sólidos, rampas, turbo e sinalização.
- 32 checkpoints sequenciais; passar a chegada sem validar o percurso não concede voltas. Um botão recupera a última passagem válida.

## Preservado e atualizado

Renderização GPU GLES, sombras, materiais e carros detalhados mantidos. Os 17 modelos continuam aceitos pelo contrato Android corrigido na v0.3.1. Mísseis/óleo/impactos usam posições no mundo. Resultado, pódio e copa usam a ordem congelada de chegada. Recordes do novo layout usam outra chave; os valores antigos não são apagados.

O controle de trajetória dos adversários é separado do jogador. Os testes usam esse controlador explicitamente para percorrer os três circuitos e validar as voltas; o código de pilotagem do jogador recebe apenas os controles de entrada.

As limitações de modelo/escopo e a ausência de validação em um telefone físico estão no guia e no relatório de testes. Esta versão é um passo de teste com mecânicas próprias; não é uma promessa de equivalência integral com o jogo de referência.
