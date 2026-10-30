# Correções 0.3.0 — 26/10/2026

- **Colisões:** colisores de carro com dimensões em unidades da pista, separação de penetração a cada passo e troca de impulso; contatos entre todos os carros, inclusive retardatários na emenda da volta. Saltos com diferença de altura deixam passar por cima. A IA passa a dirigir lateralmente, sem atribuir uma nova faixa diretamente a cada quadro.
- **Física arcade:** acelerador aplica força, soltar o pedal preserva inércia com arrasto, freio desacelera, inclinações aplicam gravidade e a direção tem velocidade lateral/aderência. Batidas produzem faíscas e reação da câmera. Carros atingidos giram, pulam ligeiramente, piscam e emitem fumaça temporária.
- **Loop:** curva lateral com entrada e saída afastadas aproximadamente 42 unidades, raio próximo de 34 e orientação contínua. Splines B suavizam as curvas sem o excesso de curvatura do traçado anterior. A largura dos três circuitos cresce de 13 para 28 unidades. Linha da largada e pórtico foram alinhados.
- **Acelerador:** botão ACELERAR sempre visível; manual por padrão. A preferência antiga migra para manual uma vez, preservando moedas, carros e demais dados. Turbo exige aceleração.
- **Resultados:** chegada com interpolação dentro do passo de 1/120 s, incluindo chegadas quase simultâneas. Resultado imutável compartilhado por pódio, tabela, recompensa e copa. O carro exibido na chegada pertence ao vencedor correto. Cruzar uma linha de volta para trás não duplica voltas.
- **Poderes:** míssil maior com aletas, chama e rastro; colisão considera faixa/altura e o trecho percorrido. Mísseis da IA também têm objeto em voo. Impactos têm explosão/faíscas/fumaça; óleo causa giro; escudo mostra o bloqueio e reduz sua duração. A recarga de turbo mostra a carga no HUD.

Continuam sendo circuitos e carros originais de miniaturas. O visual e a física não reproduzem integralmente Hot Wheels: Beat That!. O dano é um efeito temporário de corrida; não há deformação permanente da carroceria.
