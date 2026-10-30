# Validação CarWece 0.14.1+24

Base: código completo da 0.14.0. Escopo: criação de salas, novas tentativas,
avisos de conexão e opção explícita MESMO WI-FI. Nenhuma alteração de física,
renderização, carros, circuitos, armas, músicas, splash ou ícones.
86 arquivos do núcleo, arte e recursos conferidos contra o ZIP original.

- Flutter analyze: sem problemas.
- Suíte Flutter: 213 testes aprovados. O teste de interface foi novamente
  executado após acrescentar a verificação dos seletores INTERNET/MESMO WI-FI.
- JVM/Android: 52 testes aprovados; zero falhas/erros/ignorados.
- Regressões de retransmissão: quedas transitórias, três falhas persistentes,
  recusa, exigência de autenticação, timeout, cancelamento, quadros fragmentados,
  heartbeat, porta inválida, limite de quadro e convites.
- Integração com seis clientes reais TCP/TLS/WebSocket e retransmissor local
  simulado: duas quedas antes do sucesso, erro original preservado, certificados
  e convites incorretos recusados, nomes duplicados e sétimo jogador recusados,
  corrida/batalha, mira sincronizada e encerramento pelo anfitrião.
- Integração direta sem retransmissor: os mesmos cenários de sessão passaram.
  As conexões usam loopback; o convite usa endereço privado injetado no teste.
  A descoberta de interface Wi-Fi e dois celulares Android reais NÃO foram testados.
- Interface renderizada em 1280×720 e 800×360, incluindo seletor de rede.
- APK: três ABIs; nome/pacote corretos; versão 0.14.1, código 24; assinatura
  v2 com o certificado original; alinhamento ZIP de 16 KB verificado.
- Vinte PNGs e duas declarações de ícones adaptativos conferidos; músicas e vídeo
  idênticos às fontes. Seis bibliotecas ELF íntegras; libflutter.so idênticas ao engine do SDK após remoção de símbolos.

## Limites materiais

O serviço bore.pub NÃO foi verificado publicamente: a consulta DNS falhou neste
ambiente. Não é possível concluir, pela imagem, se a rede do usuário está bloqueada
ou se o serviço recusou/encerrou a conexão. O formato de protocolo da 0.14.0 já
correspondia ao bore 0.6.0; esta versão corrige tratamento, repetição e avisos,
sem prometer disponibilidade de um serviço externo.
Não foi feita validação em aparelho/emulador Android, nem medição de FPS,
memória, bateria, latência pública ou conexão entre casas diferentes.

APK: CarWece_v0.14.1_hirumisu.apk
Bytes: 77382220
SHA-256: 07248d15fb67cef4c23f80fde9e6f9dbd7d35d9de996c8029e79fde9e1bf5ae6
Certificado SHA-256: 9e1be273e6871c23013157fad5378ffc4d5da5b222d70f84a995c8cb94ca8d7a

Os arquivos *v0141* registram os testes desta entrega; os demais são históricos.
A dependência JUnit usada pelo teste JVM veio da mesma distribuição Gradle,
disponibilizada em repositório Maven local para execução offline.
