# CarWece 0.13.0+21 — primeira versão online para testes

Adicionados login com nome de usuário/senha, contas persistentes no servidor, salas públicas e privadas por código para 2–6 pessoas e seleção dos 26 circuitos e 6 arenas. Cada aparelho controla seu próprio carro; não há IA substituindo pessoas nesta versão. Corridas e batalhas reutilizam a física de 120 Hz e a geometria atual do jogo no servidor.

O cliente envia comandos de direção, acelerador, freio, turbo, drift e ações de arma. Posição, checkpoints, coletas, munição, dano e classificações são calculados pelo servidor. Os estados transmitidos incluem pneus, direção das rodas, mísseis, explosões, fumaça, portões, vida, armas montadas e munição.

A largada espera todos carregarem. Há reconexão de até vinte segundos, frenagem ao perder comandos, transferência de anfitrião e preparação de nova partida na mesma sala. Abrir o pause não interrompe a partida dos demais. Recompensas são individuais e salvas uma vez: 1.000/500/250 moedas no pódio; desistentes não recebem.

Cada servidor mantém sua própria carreira online, iniciada com RX-7. A carreira offline permanece no aparelho. As pistas online estão disponíveis para testes; os carros adicionais usam os preços e requisitos de estrelas do catálogo atual. Contas não são compartilhadas automaticamente entre servidores diferentes. Não existe recuperação de senha nesta alfa.

Créditos adicionados: **Marcos Nascimento (Sage Corp.)**, mantendo **hirumisu**.

Preservados: pacote com.hirumisu.carwece, certificado, ícones aprovados, introdução completa, 31 carros, menus, carreiras offline, configurações/HUD e as 20 músicas M4A completas compactadas. A hospedagem pública não faz parte do APK; o pacote do servidor e o guia acompanham a entrega.

Esta é uma alfa. O servidor e os clientes passaram por testes reais de sockets no computador; falta testar celulares, rede móvel, latência pela internet e a instalação na hospedagem. O cliente utiliza interpolação e ainda não possui previsão completa de física/compensação de atraso. Os sons de motor e as músicas continuam locais; o protocolo inicial prioriza estado físico e efeitos visuais dos poderes.
