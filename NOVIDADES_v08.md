# CarWece 0.8.0 — expansão e editor de HUD

Autoria: **hirumisu**. Pacote `com.hirumisu.carwece`, código Android 11.

## Coleção

| Modelo novo | Moedas | Estrelas | Características próprias |
| --- | ---: | ---: | --- |
| Mazda MX-5 NA | 750 | 0 | Compacto, hardtop preto, faróis escamoteáveis e rodas de sete raios. |
| Ford Mustang GT | 3.900 | 10 | Fastback azul, faixas claras, grade larga e seis lanternas verticais. |
| Nissan GT-R R35 | 7.200 | 18 | Carroceria larga, quatro lanternas redondas, quatro escapes e tração integral. |
| Ferrari F40 | 13.500 | 32 | Cunha vermelha, tomadas laterais, tampa com aletas e grande asa integrada. |

São 16 carros. Os valores são de jogo, equilibrados para miniaturas; as malhas são estilizações procedurais próprias. IDs e ordem dos doze carros anteriores permanecem iguais para preservar compras e seleção.

## Novos circuitos

| Ambiente | Circuito | Estrelas |
| --- | --- | ---: |
| Quarto | Cânion dos Livros | 2 |
| Garagem | Pátio das Ferramentas | 7 |
| Banheiro | Aqueduto de Espuma | 12 |
| Cozinha | Volta da Ilha | 17 |
| Sala | Zigue-Zague das Almofadas | 23 |
| Arcade | Vórtice dos Fliperamas | 31 |

Os seis traçados foram definidos separadamente e têm combinações próprias de piso, retornos e trechos elevados. Há três circuitos por ambiente, 18 no total, e 16 atalhos com portões. Barreiras de objetos e cenário compartilham os limites usados na física. A carreira chega a 54 estrelas, sem remover medalhas anteriores.

A navegação de IA nos atalhos passa a considerar a curvatura do próprio ramal e a continuação após a saída. O portal final usa a largura do corredor principal na reintegração, mantendo entrada, portais intermediários e portão aberto obrigatórios. Isso evita perder a validação ao retornar por uma faixa lateral legítima.

## Rivais

A seleção anterior considerava apenas o desbloqueio da pista, deixando o jogador com um carro forte contra rivais de categoria inferior. Normal e Difícil agora escolhem uma faixa de desempenho próxima ao carro do jogador. O controle considera curvas à frente para planejar frenagem. Turbo usa a mesma dinâmica do jogador, com energia finita e chama visível; não adiciona avanço de percurso.

Normal e Difícil têm ajustes próprios de ritmo, reação, energia e armas. Ataques preferem ferramentas compatíveis com a posição de alvos à frente ou perseguidores atrás. O Fácil continua sem turbo ou ataques da IA. O jogador não recebe redução de atributos em dificuldades maiores.

Na comparação com a v0.7.1, a média das medianas de chegada caiu de 76,66 para 62,88 segundos no Normal e de 69,00 para 60,03 no Difícil. Foram oito pelotões por modo: duas pistas, dois carros do jogador e duas sementes, com uma volta e jogador estacionado. Essas reduções de aproximadamente 18%/13% são desse conjunto de testes, não uma promessa para todas as corridas.

## HUD

Editor acessível nas Configurações e na Pausa. Cada um dos 16 elementos pode ser arrastado e redimensionado separadamente. O tamanho varia de 65% a 180%; coordenadas normalizadas se adaptam à tela. Há rascunho, cancelar, restaurar padrão e salvamento persistente, com retorno ao editor se a gravação falhar.

Setas, acelerador e drift preservam o gesto de deslizar entre botões, inclusive quando reposicionados. O roteamento mantém fontes separadas por dedo e teclado; pausa, cancelamento de toque e reposição liberam os comandos antigos. O editor pausa a simulação e desativa ações de corrida durante o arraste.

## Compatibilidade e teste

Mesmo nome, pacote, certificado e ícone. Instalação por cima da anterior preserva progresso. Os circuitos antigos e a família de recordes `layout7` continuam válidos; novos circuitos usam IDs próprios. A correção da fumaça permanece coberta pelos testes.

O limite nativo de modelos subiu de 64 para 96 para receber as 66 malhas atuais. A classificação de transparência continua sendo por material, não por índice. A checagem Kotlin do pacote real foi atualizada junto com os índices do catálogo.

115 testes Flutter passaram, incluindo persistência/edição do HUD e controles reposicionados. As malhas, shaders e transformações foram renderizadas em 87 cenas GLES. Testes de widgets Android usam textura simulada; este ciclo não executou o APK em celular físico. Ver [validação completa](verification/VALIDACAO.md).
