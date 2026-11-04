# CarWece v1.7.5 — A espiral de 10 fps (simulação, não gráfico)

Com o número na mão (9–10 fps), o diagnóstico mudou: isso não é custo
de GPU, é uma **espiral na simulação**.

## O mecanismo
A simulação roda a 120 passos fixos por segundo e o loop da corrida
mandava o motor "recuperar o atraso" sem limite prático: um quadro de
100 ms exigia **12 passos**; num CPU de entrada cada passo custa
milissegundos reais, então o quadro seguinte ficava **ainda mais
lento** e pedia mais passos — o jogo estacionava em ~10 fps se
alimentando do próprio atraso. Medido aqui: um quadro normal pede
~1,2 ms de simulação; o quadro em espiral pede **6,3 ms** — e no
aparelho, com CPU várias vezes mais lenta que esta VM e possível
throttling térmico, a conta fecha nos 9–10 fps relatados.

## A correção
O loop da corrida agora limita a recuperação a **4 passos por quadro**
(1/30 s):

- A 30 fps ou acima, **nada muda** — física, tempos e comportamento
  idênticos (e o online, que dirige o motor direto a 120 Hz, nem passa
  por esse loop).
- Abaixo disso, em vez de acumular dívida, o jogo abre mão de frações
  de tempo de simulação: a thread principal sempre respira, o quadro
  volta a encurtar e o fps se recupera em vez de desabar.

Nenhum gráfico foi tocado nesta versão: resolução, MSAA, sombras e
shader seguem exatamente como na v1.7.4.

## Validação
- Analyze limpo; testes do online (lockstep) e da suíte completa
  verdes — a semântica do motor não mudou, só o loop da tela.
- pubspec: **1.7.5+14**.
