# CarWece 1.2.1+4 — Correção dos atalhos

## O bug
Às vezes o jogador entrava no atalho, atravessava e mesmo assim **não concluía**:
ficava uma volta atrasado. A causa: a conclusão dependia de cruzar o *plano exato*
da saída com a tentativa armada no plano do portão. Se o carro entrasse no ramal
por outro ponto (salto, empurrão, linha larga no merge) ou saísse sem cruzar
exatamente aquele plano, a tentativa era cancelada em silêncio e o próximo
checkpoint ficava num ponto já passado — resultado: volta perdida.

## A correção (`lib/game/engine.dart`, `_shortcutProgress`)
1. **Armar por presença no corredor**: estar dentro do corredor do atalho,
   andando para frente, arma a tentativa em qualquer ponto de entrada
   (antes do portão = navegação; na altura/depois do portão = validado).
   As zonas de merge das duas pontas são excluídas, porque lá o ramal e a
   pista principal se sobrepõem.
2. **Validação por projeção**: chegar à altura do portão dentro do corredor
   (mesmo sem cruzar o plano, ex.: passagem aérea/lateral) vale como prova
   de travessia, igual ao cruzamento do plano.
3. **Conclusão no merge**: voltar para a pista principal na altura da saída
   ou logo depois dela (dentro de um setor, sobre a pista) conclui o atalho,
   mesmo sem cruzar o plano exato da saída.
4. **Saída antecipada segura**: sair do corredor antes da saída só abandona
   a tentativa — os checkpoints da pista principal continuam à frente,
   então nenhuma volta é perdida.

Proteções mantidas: entrar de ré não arma nada; voltar de ré pelo portão
revoga a tentativa; cruzar a saída sem ter atravessado o ramal não credita
checkpoints; estar a poucos metros antes da saída não conclui antes da hora.

## Online
`onlineContent` atualizado para `carwece-brasil-loops-2.2-shortcut-anywhere`
(a semântica de conclusão mudou; salas não devem misturar versões).

## Testes
Novo arquivo `test/shortcut_entry_exit_regression_test.dart` (5 testes):
entrar no meio do atalho arma e conclui; entrar de ré não arma; voltar para
a pista depois da saída conclui; voltar antes da saída abandona sem perder
volta. Suíte completa executada localmente com Flutter 3.35.7.
