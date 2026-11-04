# CarWece v1.7.4 — O problema era o ritmo (sem cortar gráficos)

## A causa do travamento
O teto de "60 fps estáveis" que a v1.7.1 colocou nesse hardware
interagia mal com a tela de 90 Hz do A05s: os quadros do Flutter chegam
a cada ~11,1 ms, e um portão de 16 ms só deixa um quadro passar a cada
**dois** ticks — o jogo estava preso a **45 fps** com quadros de
22,2 ms, por melhor que a GPU estivesse. Era isso o "travando".

Correção: o envio de quadros volta a seguir a taxa do painel em todos
os aparelhos. O renderizador nativo sempre desenha **só o quadro mais
recente**, então não há fila: a GPU apresenta no ritmo que ela aguenta,
sem o degrau artificial de 45 fps.

## Gráficos restaurados por completo nesse hardware
Revertidos os cortes que a v1.7.3 tinha feito para compensar:

- Sombra atualiza **todo quadro** de novo (não mais em quadros
  alternados) e a câmera de sombra volta ao alcance integral de 105 m.
- O shader volta a ser **exatamente o mesmo** em todos os aparelhos
  (removido o "modo desempenho" que apertava o LOD de sombra e pulava
  brilho mais cedo no hardware fraco).

Permanecem (não são cortes visuais): resolução dinâmica com **piso**
de 80% no ALTA (protege a nitidez; o orçamento degrada a filtragem da
sombra antes da resolução), MSAA dentro do alvo da cena (4× ALTA,
2× MÉDIA), mapa de sombra 1024 no ALTA e a detecção de hardware.

## Extras
- Montagem do quadro: o brilho de reparo calculava o mesmo referencial
  4× por piloto; agora calcula 1× (pacote idêntico, menos CPU).

## Compatibilidade
- Simulação intacta: online compatível com a v1.6.0.
- pubspec: **1.7.4+13**.
