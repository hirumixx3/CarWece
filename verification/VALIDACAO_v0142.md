# Validação CarWece 0.14.2+25

Base: código completo da 0.14.1. INTERNET substitui a dependência de bore.pub
por SSH dentro de TLS para Pinggy, com controle e jogadores na porta 443.
MESMO WI-FI mantém o transporte direto. Física, renderização, carros, pistas,
armas, música, splash e ícones foram preservados.
86 arquivos de núcleo/arte/recursos idênticos ao ZIP da 0.14.1.

- Flutter analyze: sem problemas.
- Suíte Flutter: 213 testes aprovados. Interface novamente executada em
  1280×720 e 800×360, sem exceções, e créditos conferidos.
- JVM/Android: 52 testes aprovados, zero falhas/erros/ignorados.
- SSH/TLS: servidor Paramiko independente executado junto aos clientes.
  Controle SSH real dentro de TLS, encaminhamento TCP remoto, API /urls,
  TLS do jogo com certificado da sessão e WebSocket reais.
- Recusa de encaminhamento, domínio de convite inválido, rota quebrada e
  certificado externo incorreto rejeitados antes de publicar um convite.
- Seis clientes: certificados/convites errados e nome duplicado rejeitados,
  sétimo participante recusado; batalha, mira sincronizada, troca de alvo,
  saída do anfitrião, recriação e corrida aprovadas.
- O encerramento aguarda os recursos IO do novo túnel. A espera pelo servidor
  ao encerrar é limitada para não impedir a liberação do retransmissor.
- Caminho direto sem retransmissor também aprovado com seis clientes.
  Nos testes locais o endereço privado é injetado e as conexões usam loopback.
- Novas dependências oficiais estão em third_party/, com versões e licenças,
  para reconstrução offline. Não foram alteradas.
- APK: pacote/nome corretos, versão 0.14.2, código 25, três ABIs, assinatura
  v2 pelo certificado original e alinhamento ZIP de 16 KB verificados.
- Vinte PNGs e duas declarações de ícones adaptativos iguais às fontes.
  Vinte músicas e vídeo com hashes preservados. Seis ELF válidas;
  engine Flutter idêntico ao SDK após remoção normal dos símbolos.

## Limites da verificação

O servidor local não emula DNS nem roteamento SNI do serviço público.
Não foi possível verificar o serviço Pinggy público: uma tentativa de
SSH-over-TLS pelo proxy do ambiente recebeu HTTP 400; sockets diretos não
conseguem resolver o destino. HTTPS de documentação é permitido.
Esses resultados não provam indisponibilidade do serviço para o usuário,
nem comprovam uma conexão entre duas casas.
Não houve teste em aparelhos/emulador Android, descoberta de interface Wi-Fi,
medição de FPS, bateria, memória ou latência pública nesta entrega.

O aplicativo verifica a rota pública real antes de liberar um convite em
produção. No teste local, essa verificação usa a porta de encaminhamento
local do servidor SSH, com o mesmo TLS e /health do jogo.
Essa exceção de teste não é configurada pela interface do aplicativo.

A sala de internet gratuita tem limite de 60 minutos e depende do provedor.
O anfitrião continua executando o gameplay no celular. Não há migração
automática se o anfitrião sair ou a conexão cair.

APK: CarWece_v0.14.2_hirumisu.apk
Bytes: 81970228
SHA-256: fa97d153b57d700fddc309614937c0a551b8a21e4b5d1330528fb698012eb2c3
Certificado SHA-256: 9e1be273e6871c23013157fad5378ffc4d5da5b222d70f84a995c8cb94ca8d7a

Arquivos *v0142* registram a validação desta entrega; os demais são históricos.
