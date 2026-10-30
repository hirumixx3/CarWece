# CarWece 0.6.0 — mudanças

A v0.6 troca os circuitos adicionais baseados em deslocamentos do mesmo percurso por definições independentes em `lib/game/circuits.dart`. Garagem e Arcade também receberam traçados novos; o Quarto em Chamas mantém seu loop separado e ganha a largura/plástica/material/cenário desta versão. As larguras passam de 42 para 46; o piso permanece aberto com portais de 96. O Arcade tem cruzamento com ponte: a menor separação vertical encontrada entre fitas próximas e não vizinhas foi de 33,9 unidades.

Contato de loop usa força normal por massa: `v² · curvatura · normal − gravidade · normal`. Se a estrada precisaria puxar os pneus, o contato é liberado. A queda conserva o momento, aplica gravidade vertical e inércia do corpo; tração/direção não mudam a trajetória no ar. O carro pode aterrissar e voltar ao chão ou a uma pista voltada para cima, sem reposicionamento automático para a entrada do loop. A dinâmica segue arcade, com gravidade de 27 unidades/s² e proporções de miniaturas.

Mísseis verificam o segmento percorrido contra volumes dos carros, AABBs de móveis/paredes e a superfície real da fita. A colisão mais próxima decide o impacto. Foguetes sem alvo perdem altura. A detonação produz fogo volumétrico aproximado por malhas, onda de choque, faíscas, fumaça, som, tremor próximo e reação de dano/rotação. Escudos continuam mostrando o impacto. A explosão não destrói móveis.

Quatro carros novos, cada um com proporções e detalhes próprios: Silvia S15 Spec-R, M3 E46, 911 GT3 RS e Huracán Tecnica. Os doze receberam ajuste da proporção dos pneus e linhas de carroceria. O 911 tem cabine com curvatura composta; modelos novos têm faróis, entradas, rodas e aerofólios distintos. São representações estilizadas próprias, sem modelos licenciados de CAD ou extraídos de outros jogos.

A coleção tem categorias Rua, Esportivo, Ícones e Exótico. Preços são valores de jogo definidos para dar peso à coleção e aos atributos; beleza é subjetiva. Estrelas de pódio habilitam pistas e categorias; moedas compram carros. A progressão tem três pistas iniciais e pode alcançar todas sem bloqueio circular. Contrarrelógio não concede estrelas. Compras e concessões anteriores não são removidas.

O ambiente ganha mobiliário e acessórios específicos em dados compartilhados entre render e colisão. A colocação de novos objetos sólidos evita o corredor da corrida. A neblina foi retirada do shader nativo e da visualização de desenvolvimento; a distância de corte passa a 2.600. Iluminação especular GGX e reflexão ambiente complementam materiais procedurais, mantendo a arte 3D estilizada e o limite de desempenho móvel.

Pacote, assinatura, nome e camadas originais de ícone são os mesmos da v0.5.1. O código de versão Android sobe a 8 para instalação como atualização. Tempos por percurso usam `layout6`, conservando registros antigos fora da tabela atual.
