# CarWece v1.7.3 — Resolução de verdade e fluidez no A05s

Dois problemas relatados na v1.7.2, atacados juntos:

## "Sem resolução" no ALTA
A resolução dinâmica podia cair para 55% da escala (uns 700 px de
largura) e **ficar lá**: para subir de volta, o orçamento exigia média
abaixo de 17,8 ms por 480 amostras seguidas — num aparelho rodando a
45–50 fps isso nunca acontecia, e o jogo ficava borrado a corrida
inteira. Correções:

- **Piso de resolução por modo** no hardware fraco: ALTA nunca abaixo
  de **80%**, MÉDIA 75%, AUTO 70%. A ordem de sacrifício inverteu:
  quem degrada primeiro agora é a **sombra**, não a resolução.
- **Recuperação mais rápida**: com folga comprovada, a escala volta a
  subir após ~180 amostras (era 480) e com limiar mais realista.
- **ALTA de volta a 1440 px** de buffer nesse hardware (era 1280).

## "Ainda travando"
Cortes onde o olho não percebe, para pagar a resolução maior:

- **Sombra atualiza em quadros alternados** nesse hardware (o passe de
  sombra inteiro custa metade; a sombra "atrasa" 16 ms).
- **Câmera de sombra mais fechada** (85 m, era 105 m): menos cenário no
  passe de sombra e, de quebra, sombras mais nítidas, porque o mesmo
  mapa cobre uma área menor.
- **Modo desempenho no shader** (`uPerfMode`, só no hardware fraco):
  o LOD de sombra aperta mais cedo (45/85 m) e o especular GGX é pulado
  em superfícies um pouco menos ásperas; pintura e brilhos próximos
  ficam intactos.

## O que não mudou
- 60 fps estáveis como alvo nesse hardware, MSAA 4× no ALTA / 2× no
  MÉDIA dentro do alvo da cena, detecção de hardware da v1.7.1.
- Aparelhos fortes: nada muda.
- Simulação intacta: online compatível com a v1.6.0.
- pubspec: **1.7.3+12**.
