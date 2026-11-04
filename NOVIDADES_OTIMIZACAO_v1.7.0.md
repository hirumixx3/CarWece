# CarWece v1.7.0 — Otimização de desempenho

## Diagnóstico (medido, não chutado)
- A simulação a 120 Hz custa ~0,1 ms por passo na VM de teste — cerca de
  1/10 do orçamento de 8,3 ms. **O gargalo é a GPU**, principalmente no
  modo ALTA: resolução cheia + MSAA 4× + sombra 2048 com PCF 5×5 em
  todos os pixels, o tempo todo.
- Telas de 90/120 Hz estavam **travadas em ~60 fps** por um limitador
  fixo de 16 ms no envio de quadros.

## Correções
- **FPS liberado conforme a tela**: o intervalo entre quadros agora segue
  a taxa do display (60/90/120 Hz), em vez do teto fixo de 16 ms.
- **LOD de sombra por distância**: além de ~60 m o filtro cai de 5×5 para
  3×3 e além de ~110 m para um toque só — nessa distância o kernel é
  menor que um pixel, então a imagem não muda, mas a maior parte da tela
  (o cenário distante) para de pagar 25 leituras de textura por pixel.
  As sombras também desvanecem entre 150–260 m, onde o mapa de sombras
  nem alcança.
- **Orçamento adaptativo em todos os modos** (antes só no AUTO): se o
  aparelho não sustentar o ritmo, a qualidade da sombra desce degraus
  (5×5 → 3×3 → 4 toques → 1 toque) antes de qualquer quadro cair, e
  volta quando houver folga. No ALTA, a sombra 2048 e o MSAA 4× ficam.
- **GGX só onde aparece**: superfícies com aspereza ≥ 0,85 (pneus,
  tecido, asfalto, paredes) pulam a matemática de distribuição/geometria
  especular, que nelas é invisível.
- **Hash sem seno**: o ruído procedural usava um hash com `sin()` por
  avaliação (lento e com faixas em GPUs móveis); trocado por um hash
  sem seno equivalente.
- **ALTA renderiza a 1440 px** de largura (antes 1600): ~19% menos
  pixels com MSAA 4×, diferença invisível na tela do celular.
- **Pacote de quadro sem lixo**: o pacote Dart→GPU era montado numa
  lista temporária de ~2.200 números e copiado a cada quadro; agora é
  preenchido direto no buffer final, reduzindo a pressão no coletor de
  lixo durante a corrida (menos microtravamentos periódicos).

## Compatibilidade
- Nenhuma mudança na simulação: o online continua compatível com a
  v1.6.0 (`onlineContent` inalterado) e os 285 testes seguem verdes,
  mais 3 novos da etapa de desempenho.
- pubspec: **1.7.0+9**.
