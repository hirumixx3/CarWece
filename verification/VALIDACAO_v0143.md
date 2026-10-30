# Validação CarWece 0.14.3+26

Base: código completo da 0.14.2. Autoria: hirumisu.
Crédito adicional: Marcos Nascimento (Sage Corp.).

## Resultados

- Regressão inicial: 213 testes Flutter aprovados.
- Após os ajustes finais do cliente: 19 testes de interface online, simulação
  e regressão de protocolo aprovados; análise Flutter sem problemas.
- Código Android sem alterações: 52 testes JVM aprovados, sem falhas.
- Servidor Paramiko independente: SSH direto e SSH dentro de TLS, sockets TCP
  reais, encaminhamento, TLS próprio do jogo e WebSocket reais.
- Falha de TLS seguida de SSH direto, bloqueio de SSH seguido de TLS,
  primeiro destino inacessível, /urls vazio e atrasado, API indisponível com
  anúncio fragmentado no terminal, timeout, cancelamento e recriação aprovados.
- Recusa do retransmissor, endereço não autorizado, certificado incorreto e
  rota pública quebrada rejeitados antes de liberar convite.
- Seis participantes nos dois tipos de controle: nomes repetidos e sétimo
  jogador rejeitados, corrida e batalha, mira sincronizada e troca de alvo.
- Ao sair o anfitrião, todos os cinco convidados precisam detectar a queda;
  o teste não verifica somente o primeiro. Nova sala criada em seguida.
- O cliente detecta oito segundos sem respostas do jogo, mesmo quando o
  retransmissor deixa a conexão TCP aberta. Reconexões antigas não substituem
  uma nova conexão. O fechamento aguarda SSH e encaminhamentos com prazo.
- O teste direto sem retransmissor também passou; endereço privado injetado,
  conexões em loopback. Não comprova descoberta da interface no Android.
- Pacote com.hirumisu.carwece, versão 0.14.3, código 26, três ABIs, assinatura
  original v2 e alinhamento ZIP de 16 KB verificados.
- Vinte PNGs e dois ícones adaptativos, vídeo, músicas, shaders e código nativo
  conferidos pelo verificador do APK. Pistas, carros e física preservados.
- Nos três libapp.so foram verificadas as rotas alternativas e a mensagem
  da nova detecção de ausência de resposta, para impedir entrega de build antigo.

## Limites

A falha de conexão TLS foi reproduzida contra um servidor de teste que aceita
SSH direto; a imagem do aparelho não revela a causa nativa específica.
Não há teste do Pinggy público neste ambiente, nem dois aparelhos Android em
redes externas. As verificações do endereço público no laboratório usam a
porta local de encaminhamento do servidor independente e o mesmo TLS do jogo.
Não demonstram disponibilidade pública, DNS/SNI do provedor ou latência real.
Não se trata de garantia de funcionamento em qualquer operadora.
O serviço gratuito continua sujeito ao limite de 60 minutos por sala.

APK: CarWece_v0.14.3_hirumisu.apk
Bytes: 81986612
SHA-256: 9428d23d14d49b521cff2f704f2092063615c7785c0538e365cbe8e68093df53
Certificado SHA-256: 9e1be273e6871c23013157fad5378ffc4d5da5b222d70f84a995c8cb94ca8d7a

Relatórios *v0143* correspondem a esta entrega; os demais são históricos.
