# CarWece 0.7.0 — mudanças

## Pelotão e ultrapassagem

O controlador antigo apontava os adversários para o mesmo centro dos checkpoints. Agora cada piloto mantém uma preferência lateral e reavalia sete linhas candidatas com penalidades para tráfego, objetos e curvas. Ele suaviza mudanças de linha, procura espaço para ultrapassar, reduz antes de curvas e freia quando outro carro bloqueia a mesma faixa. A largura útil diminui nos retornos para evitar trajetórias impossíveis pelo lado interno.

Pilotos presos tentam dar ré. Após oito segundos sem progresso, a recuperação da IA usa um checkpoint já validado e uma posição livre; nunca avança pelo percurso. Se o checkpoint está invertido no loop, o piloto retorna a um ponto seguro antes dele e precisa completá-lo novamente. Na simulação de cinco rivais em cada um dos doze circuitos, todos terminaram uma volta, com duas recuperações no Quarto em Chamas e nenhuma nos demais. Um teste separado parte com três carros alinhados e exige ultrapassagem física, sem recuperação.

O jogador usa seus próprios comandos. O piso de impulso antes do loop serve a todos os carros. Cair do loop continua sendo consequência física da falta de apoio; REPOR CARRO é uma ação do jogador.

## Percurso, cenário e atalhos

Os trechos no chão passam a ter bordas sólidas, feitas de objetos do ambiente. Há de 260 a 760 objetos de borda por circuito. Eles são consultados por uma grade espacial na física e renderizados com suas orientações reais. A pista plástica conserva largura 46; corredores de chão variam de 46 a 96 conforme a curvatura. As bordas no chão fecham as saídas laterais; saltos, rampas e loops continuam sujeitos à gravidade.

Os ambientes ganharam conjuntos adicionais de pneus, recipientes, cestos, calçados, brinquedos, ferramentas, banquinhos e acessórios apropriados a cada cômodo. A colocação respeita o corredor da corrida e os atalhos. A arte continua procedural e estilizada, sem neblina ambiente.

Dez percursos têm uma ramificação mais curta; Entre a Cama e a Mesa e o primeiro circuito de cozinha ficam sem atalho nesta versão. Cada ramificação possui quatro portais, incluindo entrada e reintegração ao percurso. A progressão só avança após a sequência correta, mantendo a validação de voltas e chegada.

Portões-alvo bloqueiam essas passagens. Mísseis atingem o painel por colisão contínua e abrem a passagem com explosão e madeira fragmentada. Bater com o carro ou atirar gelo não abre o portão. O painel fica destruído para todo o pelotão durante a corrida e é restaurado na próxima. Uma caixa de mísseis antes de cada entrada permite tentar o atalho; os adversários também podem escolher uma passagem já aberta. Minimap e setas mostram as ramificações.

## Armas e HUD

Os nove itens usam uma sequência embaralhada, sem repetir imediatamente o item dos cubos comuns. A distribuição considera a posição de corrida para favorecer ferramentas de recuperação quando o jogador fica atrás. A caixa específica de um atalho fornece mísseis mesmo que o último item também tenha sido um míssil.

| Item | Efeito |
| --- | --- |
| Foguete | Três disparos, impacto e explosão; abre portões. SUPER adiciona perseguição de alvo. |
| Escudo | Proteção visível por seis segundos; SUPER dura dez segundos e pode devolver um míssil ao inventário ao bloquear um acerto. |
| Óleo | Mancha atrás do carro provoca perda temporária de aderência. |
| Carga turbo | Recupera energia; SUPER concede três cargas. |
| Mina | Objeto armado atrás do carro explode por proximidade; SUPER concede três cargas. |
| EMP | Pulso neutraliza projéteis/minas e bloqueia armas próximas por tempo limitado. |
| Tesla | Raio visível atinge um adversário à frente, com pane temporária; escudo protege. |
| Gelo | Três projéteis com fragmentos e casca de gelo, que desaparece ao terminar o efeito. |
| Fumaça | Cortina local atrás do veículo; quem a atravessa perde visibilidade temporariamente. |

SUPER exige item equipado e 100% da barra; consome a energia para melhorar esse item. O botão dedicado fica acima do ITEM, que mostra a quantidade restante. Drift, saltos e vácuo ajudam a recuperar energia. Os efeitos temporários não liberam nem interceptam os comandos mantidos pelo jogador.

## Compatibilidade e limites

Versão Android 0.7.0, código 9, pacote `com.hirumisu.carwece`. Assinatura de desenvolvimento, ícone e identidade mantidos. Progresso, carros e moedas continuam salvos; tempos atuais usam `layout7` porque o percurso mudou, preservando os registros antigos fora da tabela atual.

São 54 malhas móveis, com os novos portões e efeitos, dentro do limite nativo de 64. O cache guarda até dois mundos para limitar memória ao alternar pistas. Materiais transparentes continuam classificados pelo material, inclusive gelo.

Há validação automatizada de física, controles, atalhos, poderes e contrato gráfico, além de renderização GLES. Desempenho, instalação/atualização, áudio e interação contínua precisam de teste no Android do jogador. Não houve execução em celular físico neste ciclo. Danos não deformam permanentemente a carroceria; somente os painéis de portão são destrutíveis.
