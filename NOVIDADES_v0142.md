# CarWece 0.14.2 — novo transporte de internet

Parte da versão 0.14.1 completa. O modo MESMO WI-FI, que funcionou no aparelho
do usuário, mantém o mesmo caminho de rede e o mesmo formato de convite.
Física, gráficos, músicas, pistas, carros, armas e ícones não foram alterados.

## Mudança efetiva do retransmissor

A opção INTERNET deixa de depender de bore.pub e da porta TCP 7835.
O novo caminho usa o serviço gratuito Pinggy no modo TLS pass-through:

- Controle: SSH dentro de TLS validado, conectado a free.pinggy.io na porta 443.
- Jogadores: HTTPS/WSS na porta 443 do domínio exclusivo da sala.
- O retransmissor encaminha o TLS do próprio jogo sem terminá-lo.
- O certificado da sessão continua validado pelo fingerprint do convite.
- O anfitrião testa o endereço público até /health antes de liberar o convite.
- Se esse teste falha, a sala não é anunciada como pronta.
- Convites CW2 carregam o domínio da sessão; não fixam um domínio bore.pub.
- Não é necessário instalar SSH, Termux, VPN ou cadastrar uma conta no celular.
- Os cinco novos pacotes de código aberto estão incluídos em third_party/,
  com versões fixas e licenças, para reconstrução offline.

O servidor de corrida/batalha continua rodando no celular do anfitrião, em
isolate separado da interface. Não foi adicionado servidor dedicado de gameplay.
Até seis participantes continuam usando os carros de suas garagens locais.

## Limite do serviço gratuito

Cada sala de internet dura até 60 minutos. Ao expirar ou ao sair do anfitrião,
é necessário criar outra sala e compartilhar o novo convite. Não há cobrança
automática nem cadastro de pagamento. A opção MESMO WI-FI não usa esse serviço.

## Validação e limites

Os testes de transporte usam um servidor Paramiko independente, com SSH real
dentro de TLS, encaminhamento TCP real, a API /urls, TLS do jogo e WebSocket.
Eles não simulam DNS/SNI públicos nem comprovam a disponibilidade do Pinggy.
O ambiente permitiu HTTPS de documentação, mas bloqueou o protocolo SSH na
saída: a tentativa SSH-over-TLS pelo proxy recebeu HTTP 400. Não foi possível
validar o túnel no serviço público nem dois celulares em casas diferentes.

A implementação é uma substituição do caminho de rede. Não é apresentada
como uma disponibilidade pública comprovada. Veja verification/VALIDACAO_v0142.md
para os resultados finais dos testes e as limitações.

Referências oficiais:
- https://pinggy.io/docs/tls_tunnels/
- https://pinggy.io/docs/client_behind_proxy/
- https://pinggy.io/docs/api/web_debugger_api/
- https://pinggy.io/ (limite de 60 minutos do plano gratuito)
- https://pub.dev/packages/dartssh2

Instale o APK 0.14.2 em todos os aparelhos. Atualize por cima, sem desinstalar,
para preservar a carreira offline. Autoria: hirumisu.
Crédito adicional: Marcos Nascimento (Sage Corp.).
