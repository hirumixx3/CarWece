# CarWece 0.14.3+26 — alternativas de conexão do retransmissor

Base: código completo da 0.14.2. Autoria: hirumisu.
Crédito adicional: Marcos Nascimento (Sage Corp.).

## Problemas encontrados no código

A versão 0.14.2 só tentava SSH dentro de TLS no endereço free.pinggy.io.
Se essa conexão falhasse, repetia o mesmo caminho e desistia. O serviço
oferece também SSH direto na porta 443, que não era tentado pelo jogo.
A consulta de /urls era feita uma única vez: endereço ainda não alocado,
resposta vazia ou API temporariamente indisponível encerravam a criação.
A imagem enviada não contém o erro nativo de rede, portanto não comprova
se a falha no aparelho foi DNS, TCP ou a conexão TLS externa.

## Alterações

- Primeiro tenta SSH direto em free.pinggy.io e a.pinggy.io, na porta 443.
- Se necessário, tenta SSH dentro de TLS nos mesmos endereços.
- Cada tentativa tem prazo de 20 segundos e libera os recursos da anterior.
- A hospedagem aguarda até 95 segundos antes do prazo global de criação.
- /urls é consultado novamente se o endereço ainda não estiver disponível.
- Endereços TLS anunciados no terminal também podem ser utilizados, com
  validação do domínio e do certificado do próprio jogo.
- O teste de saúde público tenta novamente durante a inicialização.
- Nenhum convite é liberado antes de /health responder pelo túnel com o
  certificado correto da sessão, protocolo e conteúdo compatíveis.
- Se todas as alternativas falharem, aparece diagnóstico com a etapa da
  falha, sem substituir a mensagem por uma falsa confirmação de sala pronta.
- O cliente verifica respostas do servidor e detecta até oito segundos sem
  receber dados, mesmo que o retransmissor mantenha o TCP aberto. Uma
  reconexão antiga não substitui uma sala nova já conectada.
- O encerramento aguarda o fechamento SSH e os encaminhamentos antes de
  finalizar o isolate, permitindo liberar a sala e criar outra.
- Interface e créditos exibem a versão 0.14.3. A assinatura anterior é usada
  para atualização sobre o APK instalado.

O jogo continua hospedado no celular do anfitrião. O retransmissor encaminha
os bytes TLS: corrida, batalha e decisões da partida não rodam nele.
O SSH direto também cifra o controle; o TLS próprio do jogo continua fixado
pelo certificado do convite em todas as conexões dos jogadores.
Não é necessário cadastrar senha ou conta no retransmissor.

## Verificação

Os testes usam servidor Paramiko independente, sockets TCP, SSH e TLS reais.
Incluem servidor que aceita apenas SSH direto, servidor que aceita apenas
SSH dentro de TLS, primeiro endereço inacessível, resposta /urls atrasada,
API indisponível com anúncio fragmentado no terminal, timeout seguido de
outra rota, cancelamento e recriação. Os relatórios finais estão em
verification/*v0143*.

Esses cenários reproduzem classes de falhas do transporte, não o estado da
rede do aparelho. O ambiente de desenvolvimento não permite acesso direto
SSH ao Pinggy público. Os testes locais não comprovam disponibilidade do
serviço nem funcionamento entre dois celulares em redes diferentes.
A correção acrescenta alternativas ausentes na 0.14.2; ainda requer teste
no aparelho para confirmar a causa específica mostrada na imagem.

## Instalação

Atualize todos os celulares com o APK 0.14.3, sem desinstalar a versão anterior.
Abra ONLINE > INTERNET > CRIAR MINHA SALA e aguarde o resultado das tentativas.
A sala gratuita do provedor pode durar até 60 minutos; depois é preciso criar
outra e compartilhar um convite novo. MESMO WI-FI usa a conexão direta.

Referências oficiais consultadas:
- https://pinggy.io/docs/usages/
- https://pinggy.io/docs/client_behind_proxy/
- https://pinggy.io/docs/usages_sdk_python/
- https://pinggy.io/docs/api/web_debugger_api/
