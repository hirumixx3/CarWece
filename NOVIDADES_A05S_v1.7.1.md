# CarWece v1.7.1 — Perfil de desempenho para o Galaxy A05s

O A05s (Snapdragon 680, GPU Adreno 610, tela 90 Hz, 4/6 GB de RAM) é
hardware de entrada: a v1.7.0 tratava ele como um aparelho qualquer, e
ele não sustenta o pipeline completo — principalmente perseguir os
90 Hz da tela, que gerava ritmo de quadros irregular (a sensação de
"travando" mesmo quando a média de fps não é tão baixa).

## O que muda neste aparelho (e na mesma classe de hardware)
O jogo agora **detecta o hardware** (modelo SM-A057*, SoC SM6225 /
Snapdragon 680 e classe Helio de entrada) e aplica tetos próprios:

- **Ritmo travado em 60 fps estáveis** em vez de perseguir os 90 Hz:
  quadro constante vence quadro rápido que oscila.
- **Resolução dinâmica em todos os modos**, inclusive no ALTA, com teto
  de 85% e buffer máximo de 1152 px de largura: se o custo subir, a
  resolução interna desce um degrau antes de o quadro cair.
- **Mapa de sombras pela metade**: 1024 no ALTA (era 2048), 768 no
  MÉDIA, 640 no AUTO — e a **atualização da sombra roda em quadros
  alternados** (o mapa anterior é reutilizado por 16 ms; imperceptível
  em movimento, metade do custo do passe de sombra).
- **Filtro de sombra do ALTA começa em 3×3** nesse hardware (o LOD por
  distância da v1.7.0 continua valendo).
- **MSAA 2× no ALTA** (era 4×) e desligado nos demais modos.

Aparelhos mais fortes não são afetados: seguem com 2048/4×/resolução
cheia e a taxa da tela liberada.

## Compatibilidade
- Sem mudança de simulação: online continua compatível com a v1.6.0.
- pubspec: **1.7.1+10**.
