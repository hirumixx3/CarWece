# Atualização 0.5 — hirumisu

## Garagem

O catálogo antigo foi substituído por oito carros identificáveis, com proporções próprias, tipos de cabine, faróis, lanternas, entradas, aerofólios, acabamentos e rodas. Há perfis para RX-7 Fortune, Evo IX, R34, Z33, A80, NA1, 22B e EK9. Os quatro solicitados inicialmente vêm liberados. Compras anteriores e o índice selecionado migram; o save passa a guardar também o identificador do carro.

As rodas saíram das malhas estáticas. Cada carro gera uma carroceria, uma versão de efeito de dano e uma malha de roda reutilizada quatro vezes. O giro integra a velocidade longitudinal do ponto de contato dividida pelo raio; curva, ré, deriva e contato aéreo são considerados. O esterçamento usa cremalheira gradual e a diferença entre roda interna e externa. A carroceria mantém posição e orientação livres, preservando o comportamento aprovado da v0.4.

## Drift e comandos

O freio não inicia mais a derrapagem por estar combinado com a direção. DRIFT é um comando independente, com menor aderência, fumaça curta e maior recuperação de turbo. A região ACELERAR/DRIFT acompanha os ponteiros e permite arrastar entre os dois botões. DRIFT mantém força do motor enquanto pressionado. Cancelamento, pausa e reposicionamento limpam as fontes de comando, sem soltar uma tecla ainda pressionada ao liberar outro toque.

## Conteúdo e HUD

Doze pistas, duas por ambiente, com filtros de Quarto, Garagem, Arcade, Banheiro, Cozinha e Sala. A identidade do ambiente é independente do identificador da pista; pistas alternativas recebem a decoração, colisores, materiais, iluminação noturna e aderência corretos. Banheira, pia, vaso, cozinha e sala têm geometria própria e limites sólidos correspondentes. Móveis que bloqueavam a linha de algumas pistas novas foram afastados do corredor; a mesa da sala permite passagem entre as pernas.

Garagem rolável, pedal principal à direita, drift acima dele, medidor de velocidade contido no HUD, progresso da volta e nome do ambiente. O campeonato informa a sequência de três ambientes e respeita a pista selecionada como primeira etapa.

## Renderização Android

O catálogo gera 33 malhas: 8 carrocerias, 9 objetos/efeitos, 8 carrocerias de dano e 8 rodas. Índices derivam do tamanho do catálogo. O renderizador Android e a ferramenta GLES classificam transparência pelo material, removendo o antigo corte fixo por índice. Assim rodas e carrocerias novas continuam opacas, com profundidade e sombras; apenas escudo e fumaça usam mistura de alfa. O limite validado permanece 64 malhas e 128 instâncias.

Pintura com detalhe fino e camada de brilho, vidros, cerâmica, azulejos com rejunte e concreto complementam as malhas. Nenhum erro Android ativa automaticamente o renderer antigo. Os testes usam o pacote real de dados codificado no Flutter e decodificado em Java/Kotlin.

## Escopo

Versão de teste, com modelos estilizados e física arcade. O relatório de validação distingue testes de lógica, widgets, ponte JVM e renders GLES de execução em celular físico.
