# CarWece 0.14.4+27 — online em destaque e checkpoints dos atalhos

Base: código completo da 0.14.3. Autoria: hirumisu.
Crédito adicional: Marcos Nascimento (Sage Corp.).

## Interface

JOGAR ONLINE passa a ser um botão grande ciano, junto dos modos principais.
Foram removidos ONLINE • TESTE e ONLINE EM TESTE dos menus e dos créditos.
O cabeçalho e os créditos exibem a versão correta. O caminho de conexão e o
retransmissor da 0.14.3, cuja criação de sala funcionou no aparelho do usuário,
permanecem sem alterações.

## Checkpoints e atalhos

Três casos foram reproduzidos no código anterior: sair de cima da linha de um
checkpoint, entrar no atalho depois de um checkpoint sobreposto já ter sido
contado e saltar dentro do atalho. Os três falhavam na sequência da corrida.

- O checkpoint usa o ponto real de cruzamento do movimento, em vez da posição
  ao fim do passo de física, e aceita sair da linha no sentido correto.
- Saltos são aceitos nos checkpoints do piso. As restrições dos trechos elevados
  e dos loops são preservadas; andar para trás não adianta checkpoints.
- A entrada do atalho aceita a sequência compatível com sua área de entrada,
  mesmo quando o checkpoint principal sobreposto já foi contado ou ficou para
  trás ao entrar pela borda. Entrar diretamente pela saída continua sem crédito.
- Depois da entrada válida, o avanço é verificado ao longo do corredor do
  atalho. Um salto ou uma linha mais aberta não deixam um portal invisível
  permanentemente atrás do carro. A segunda metade ainda exige o portão aberto.
- A junção com a pista principal aceita a zona de união, sem exigir cruzar o
  último plano exato. A sequência continua no checkpoint depois da saída.
- As setas verdes no piso dos atalhos e a mensagem para segui-las foram retiradas.
  Portões destrutíveis, barreiras, minimapa e recompensas do atalho permanecem.

A mesma simulação valida os checkpoints offline e no anfitrião online. Não foi
alterado o formato de mensagens da rede, o salvamento da carreira, os carros,
as músicas, os ícones, as armas ou as regras de abertura dos portões.

Os testes incluem percorrer todos os atalhos e terminar a volta atual sem
precisar rodar outro circuito completo. Veja verification/VALIDACAO_v0144.md
para resultados finais e limites da verificação.

Atualize por cima da versão anterior, sem desinstalar, para manter a carreira.
