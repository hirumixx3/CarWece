# CarWece 0.14.1 — criação de salas

Esta versão parte integralmente da 0.14.0. Mantém carros, circuitos, arenas,
mira verde, botão TROCAR MIRA, créditos, músicas e todos os ícones da 0.13.1.

## Falha ao criar sala pela internet

- Até três tentativas de conexão antes de desistir, com limite de tempo.
- O aviso de desconexão da sala não é mais disparado durante uma tentativa
  inicial que falhou ou durante o encerramento voluntário.
- O motivo da falha é preservado: retransmissor inalcançável, sem resposta,
  conexão encerrada, abertura recusada ou autenticação exigida pelo serviço.
- O progresso informa quando uma nova tentativa está em andamento.
- Uma queda após a abertura encerra a hospedagem e orienta gerar outro convite.
- Conexões pendentes são fechadas quando a criação é cancelada.

O protocolo JSON/NUL foi conferido no código publicado do bore 0.6.0:
https://docs.rs/bore-cli/latest/src/bore_cli/shared.rs.html
Os quadros e o formato Hello/Connection da 0.14.0 já eram compatíveis; não foi
identificado um erro de formato que, por si só, explicasse a queda da imagem.

## Alternativa independente: MESMO WI-FI

- Há duas opções explícitas antes de criar a sala: INTERNET e MESMO WI-FI.
- MESMO WI-FI permite hospedar e entrar diretamente na rede local, sem bore.pub
  e sem precisar de internet. Todos devem estar no mesmo Wi-Fi ou ponto de acesso.
- Convites CWL1 contêm o endereço privado e a identidade TLS da sessão.
  Convites CW1 da internet mantêm o formato anterior.
- As duas opções usam TLS com certificado validado pelo convite, nomes próprios,
  até seis jogadores, corridas e batalhas.
- Uma sala local não é anunciada como acessível de outras casas.
- Redes de convidados com isolamento entre aparelhos podem impedir o modo local.

## Limites da correção

INTERNET continua dependendo de bore.pub e da permissão de conexões TCP na rede.
Repetir tentativas e tratar erros não recupera um serviço externo fora do ar nem
remove bloqueios da operadora/roteador. O erro da imagem, isoladamente, não permite
distinguir essas causas. Não foi possível verificar o serviço público neste
ambiente: a consulta DNS de bore.pub falhou. Não foi feito teste com celulares
Android reais, na mesma rede ou em casas diferentes. O teste do caminho local
usa TCP/TLS/WebSocket reais em loopback, com o endereço privado do convite
simulado; não valida a descoberta de Wi-Fi no Android. Os relatórios descrevem
exatamente os testes locais feitos.

Use a mesma versão do APK em todos os celulares. Atualize por cima da instalação
anterior para preservar a carreira offline. Não desinstale o jogo antes de atualizar.
