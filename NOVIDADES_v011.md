# CarWece 0.11.1 — Batalha / Mundo Aberto

Esta versão acrescenta seis arenas independentes dos 26 circuitos de corrida. Há circulação pelo chão do ambiente, caminhos alternativos entre objetos, rampas de salto, pontes e loops verticais. Os limites são as paredes do cômodo e os objetos sólidos. Não há voltas ou checkpoints obrigatórios nas arenas.

## Arenas

| Arena | Ambiente | Loops |
|---|---|---:|
| FORTALEZA DOS BRINQUEDOS | QUARTO | 1 |
| FERRO-VELHO ELÉTRICO | GARAGEM | 2 |
| MARÉ DE AZULEJOS | BANHEIRO | 1 |
| CAOS NA COZINHA | COZINHA | 2 |
| CERCO DO SOFÁ | SALA | 1 |
| DOMO NEON | ARCADE | 2 |

## Regras e controles

Na batalha de eliminação são seis carros com 100 de vida cada. Os cinco rivais também atacam entre si. Vida, munição, recarga e aquecimento são individuais. Quando a vida acaba o carro explode, deixa destroços e para de participar. A partida termina ao restar um sobrevivente ou quando o jogador é destruído. Se o limite de cinco minutos chegar, sobreviventes ficam à frente, seguidos de eliminações, dano e vida restante. As classificações de corrida não são usadas.

Segure ATIRAR para manter o disparo. Todos os carros começam sem armas. Cada poder só é recebido ao passar por uma caixa no mapa. Todas as armas têm munição limitada e recarga própria, inclusive a metralhadora: 60 tiros por coleta, com aquecimento. Você pode carregar até três poderes coletados. Ao coletar um quarto diferente, uma arma é substituída. Ao esgotar uma arma, a seleção usa somente outra arma já coletada; sem munição restante, mostra SEM PODER e será preciso coletar outra caixa. TROCAR ARMA alterna a seleção; segurar esse botão ou abrir Pausa → ARSENAL permite consultar e escolher. No arsenal, CATÁLOGO mostra também os itens que precisam ser coletados.

Toque em um rival na lista de vida para fixar a mira. Algumas armas seguem alvos ou usam torre; foguetes retos e lasers frontais exigem apontar o carro. Escudos bloqueiam dano e efeitos de impacto. Cobertura intercepta projéteis comuns; os raios perfurantes usam sua habilidade própria de penetração. O bloqueador de radar atrapalha a aquisição e a perseguição de mísseis. A isca desvia projéteis guiados.

Caixas de munição reaparecem após 12 segundos e alternam por um conjunto de 44 poderes coletáveis. Reparos verdes restauram 32 de vida e reaparecem após 20 segundos. O poder Reparo Completo restaura a vida e limpa danos temporários. Fogo, gelo, pane, escudo, lâminas, bônus e armadilhas têm duração limitada. Gás tóxico afeta visão e vida apenas no volume da nuvem; sair dela limpa a exposição visual no próximo passo de física.

A recompensa normal é 40 moedas pela partida, 45 por eliminação e 150 pela vitória como último sobrevivente. Uma derrota com menos de 15 segundos e nenhuma eliminação não dá moedas. Uma vitória rápida com eliminações recebe a recompensa. Resultados de batalha, vitórias e eliminações são salvos separadamente das medalhas e recordes de corrida. Exploração não dá moedas.

Na exploração, os três alvos são passivos e se reconstroem após serem destruídos. Os 44 poderes também precisam ser coletados no mapa e usam munição limitada, sem cronômetro. O jogador pode reparar o próprio carro com o poder de reparo ou voltar após ser destruído.

Controles de teclado: WASD/setas dirigem; Shift ativa drift; Espaço usa turbo; X/F dispara; Q troca arma; C troca alvo; E abre o arsenal; Esc pausa. No Android, use os botões do HUD. Aceleração automática fica desligada nas arenas. O editor de HUD e a seleção das 19 músicas de jogo continuam disponíveis pelo pause.

## Armas padrão de combate

| CarWece | Referência | Munição por coleta | Dano base | Efeito no CarWece |
|---|---|---:|---:|---|
| METRALHADORA | Mosquito Machine Gun | 60 | 3.2 | Tiros frontais; 60 disparos por coleta, aquece ao manter o disparo. |
| MÍSSIL GUIADO | Interceptor Missiles | 6 | 19 | Persegue o alvo selecionado; obstáculos interceptam o míssil. |
| FOGUETE | Bull’s Eye Rockets | 8 | 25 | Disparo reto, rápido e explosivo; exige apontar o carro. |
| MORTEIRO | Sky Hammer Mortar | 5 | 25 | Projétil em arco com correção limitada e explosão em área. |
| CANHÃO | Bruiser Cannon | 10 | 16 | Torre gira até o alvo; projétil pesado causa recuo. |
| MINA DE CONTATO | Roadkill Mines | 6 | 27 | Fica atrás do carro e arma antes de explodir por contato. |

## Gadgets e bônus de Velocity X

| CarWece | Referência | Munição por coleta | Dano base | Efeito no CarWece |
|---|---|---:|---:|---|
| RODAS CORTANTES | Ripper Wheels | 2 | 9 | Lâminas nas rodas ferem carros próximos durante sete segundos. |
| REPARO COMPLETO | Armor Repair | 1 | 0 | Restaura a vida e limpa fogo, gelo, fumaça e pane. |
| TAMBOR DE ÓLEO | Oil Drum | 4 | 10 | Arremessa um barril; o impacto espalha óleo que faz derrapar. |
| CANHÃO LASER | Laser Cannon | 5 | 27 | Raio azul frontal preciso; cobertura sólida bloqueia o tiro. |
| EXPLOSÃO SÔNICA | Sonic Boom | 3 | 15 | Pulso circular desestabiliza e empurra inimigos próximos. |
| RAJADA ATÔMICA | Atom Blaster | 16 | 5 | Rajada dupla de partículas amarelas. |
| BOMBA CRIOGÊNICA | Freon Bomb | 4 | 16 | Bomba com quique que congela no raio da explosão. |
| ESCUDO DE ENERGIA | Energy Shield | 2 | 0 | Bloqueia dano por cinco segundos; mantém o carro visível. |
| PROPULSORES | Jet Boosters | 3 | 12 | Aceleração forçada por três segundos e dano ao abalroar. |
| SUPER DESCARGA | Super Zapper | 4 | 13 | Arco elétrico trava o motor e descarrega pulsos de dano. |
| MINA MAGNÉTICA | Magnet Mine | 4 | 27 | Mina lançada segue, gruda no alvo e explode após a contagem. |
| DISCOS GUIADOS | Doom Disks | 3 | 10 | Três discos curvos convergem sobre o alvo. |
| ANIQUILADOR QUÂNTICO | Quantum Annihilator | 1 | 65 | Raio frontal raro de grande dano e recarga lenta. |

## Especiais de Vigilante 8

| CarWece | Referência | Munição por coleta | Dano base | Efeito no CarWece |
|---|---|---:|---:|---|
| GRADE DE FLARES | Gridlock | 3 | 19 | Malha expansiva de flares, dano e pane dentro da grade. |
| RELÂMPAGO BRANCO | White Lightning | 3 | 22 | Descarga guiada com salto entre carros próximos. |
| TORRE GIRATÓRIA | Tantrum Gun | 10 | 7 | Gatling automática em rajada; pode expulsar munição do inimigo. |
| TERREMOTO DE GRAVES | Bass Quake | 3 | 22 | Ondas pelo chão levantam carros sem atingir veículos muito altos. |
| INVASÃO ORBITAL | Invasion Attack | 2 | 8 | Três sondas orbitam o alvo e lançam pulsos visíveis. |
| PNEU EXPLOSIVO | Steel Belter | 4 | 33 | Pneu rola, procura um alvo e explode em área. |
| SALVA DISPERSA | Scatter Missiles | 3 | 8 | Seis pequenos mísseis se abrem e convergem. |
| RAIO PERFURANTE | Super Fantastic Death Ray 3-Ax | 4 | 28 | Feixe atravessa cobertura e pode atingir vários carros. |
| GLOBO DO CAOS | Disco Inferno | 2 | 8 | Globo sobre o carro solta flares em todas as direções. |
| ENXAME GAMA | Gamma Swarm | 3 | 7 | Enxame perseguidor ergue o alvo e provoca dano em pulsos. |
| NUVEM TÓXICA | Smog Check | 3 | 7 | Gás atrás do carro; dano e visão reduzida apenas dentro da nuvem. |
| SOPRO DE FOGO | Breath of Fire | 6 | 14 | Bolas de fogo deixam o alvo em chamas por tempo limitado. |
| LASER ALIENÍGENA | Blue Laser | 3 | 42 | Laser penetrante de alto dano, com pontaria frontal estreita. |

## Variações de combo de Vigilante 8

| CarWece | Referência | Munição por coleta | Dano base | Efeito no CarWece |
|---|---|---:|---:|---|
| ISCA HOLOGRÁFICA | Halo Decoy | 3 | 0 | Anel-isca desvia projéteis guiados para longe do carro. |
| PÓS-COMBUSTÃO | Afterburner | 4 | 0 | Usa a carga para uma arrancada curta, inclusive antes de rampas. |
| FOGUETE REBELDE | Road Runner | 4 | 7 | Foguete adesivo empurra e faz o alvo rodar. |
| DEBANDADA | Stampede | 3 | 10 | Cinco foguetes disparados em leque concentrado. |
| VIRA-CARRO | Turtle Turnover | 3 | 12 | Morteiro lança o carro para cima e o faz tombar. |
| MEGACRATERA | Crater Maker | 2 | 43 | Morteiro pesado com grande raio e marca de impacto temporária. |
| SOCO CINÉTICO | Cow Puncher | 4 | 10 | Bala de impacto lança o carro atingido para trás. |
| CHUMBO ESPALHADO | Buckshot | 4 | 7 | Seis balas em leque; forte a curta distância. |
| ABRAÇO MAGNÉTICO | Bear Hug | 3 | 8 | Armadilha atrai e imobiliza; não confere invulnerabilidade. |
| CAMPO MINADO | Cactus Patch | 3 | 13 | Espalha seis minas de contato atrás do carro. |

## Bônus de combate

| CarWece | Referência | Munição por coleta | Dano base | Efeito no CarWece |
|---|---|---:|---:|---|
| BLOQUEADOR DE RADAR | Radar Jammer | 2 | 0 | Oculta do radar e interrompe a mira guiada por sete segundos. |
| DANO DOBRADO | Weapon Upgrade | 2 | 0 | Dobra temporariamente o dano das seis armas padrão. |

O dano base é ajustado pela área atingida, pelo escudo, pelos bônus e pelo tipo de ataque. Rajadas disparam mais de um projétil. Tiros, barris, pneus, discos, sondas, globos, minas e armadilhas têm objetos visuais próprios; explosões, faíscas, fumaça, gelo e raios indicam o efeito.

## Referências usadas

A base da adaptação é Hot Wheels: Velocity X para consoles/PC e Vigilante 8 original para PlayStation/Nintendo 64. Os 44 itens abrangem 13 gadgets incluindo o Quantum Annihilator, seis armas padrão, treze especiais incluindo o Blue Laser, dez variantes de combo e dois bônus adicionais. Esta é uma implementação do CarWece com arenas, efeitos, valores e elenco próprios. A pesquisa e os links consultados estão em verification/PESQUISA_BATALHA.md.

Os 31 carros, 26 circuitos, 13 poderes de corrida, 20 músicas, ícone, assinatura e progresso anteriores foram preservados. Instale a versão 0.11.1+16 por cima da anterior, sem desinstalar. Ainda é uma versão de teste; não houve execução em aparelho Android físico.
