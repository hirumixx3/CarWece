# CarWece 0.14.4 — por hirumisu

Jogo Flutter/Android de corrida arcade com miniaturas, 26 circuitos, seis
arenas de batalha, garagem de 31 carros, poderes coletáveis e HUD editável.
Mantém os ícones personalizados e músicas comprimidas da versão 0.13.1.
Crédito adicional: Marcos Nascimento (Sage Corp.).

## Novidades da 0.14.4

O botão JOGAR ONLINE agora fica em destaque junto de CORRER e BATALHA.
Os emblemas de teste foram removidos dos menus e créditos. A validação de
checkpoints aceita o cruzamento real da linha e percorre o atalho sem exigir
passar exatamente por planos estreitos invisíveis. As setas verdes dos atalhos
foram removidas; portões, barreiras e o mapa continuam disponíveis.

## Online: hospedagem no celular

A opção INTERNET usa Pinggy TLS pass-through. O controle tenta primeiro SSH
direto na porta 443 e depois SSH dentro de TLS, com alternativas free.pinggy.io
e a.pinggy.io. Jogadores usam HTTPS/WSS na porta 443, sem bore.pub.
O certificado do jogo é validado pelo convite. O anfitrião só recebe um convite
CW2 depois de o endereço público responder ao teste de saúde.
Cada sala gratuita tem limite de 60 minutos e precisa do anfitrião conectado.

MESMO WI-FI mantém o caminho direto da 0.14.1. Não precisa de internet nem
retransmissor. Até seis participantes podem jogar corridas e batalhas.
O nome é local, os carros vêm da garagem local e os resultados da sessão
não substituem a carreira offline. Mira verde e TROCAR MIRA são preservados.

Veja LEIA_PRIMEIRO.md e NOVIDADES_v0144.md. Os testes de SSH direto, SSH/TLS e encaminhamento
foram executados com servidor local independente; incluem falha da conexão TLS
seguida de criação por SSH, API indisponível e alocação de endereço atrasada. A saída deste ambiente não
permitiu o teste do SSH público; não houve validação entre celulares reais.

## Compilar e verificar

Use Flutter 3.35.7 / Dart 3.9.2 ou ambiente compatível, Java 17, Android SDK 35
e NDK 27.0.12077973. O APK abrange armeabi-v7a, arm64-v8a e x86_64, com
Android mínimo 7/API 24 e target 35. O código inclui a chave de teste do
projeto para permitir atualizar o APK de testes anterior; não use essa chave
para uma publicação de produção.

```sh
flutter pub get
flutter analyze
flutter test --dart-define=EXPORT_GRAPHICS_WIRE=true
(cd android && ./gradlew :app:testReleaseUnitTest --no-daemon)
dart run tools/friends_qa.dart --lan
python3 -m pip install paramiko
python3 tools/run_relay_qa.py
flutter build apk --release --target-platform android-arm,android-arm64,android-x64
```

O teste Kotlin HostIdentityTest produz identidade TLS descartável em
build/host_identity/ para o teste de rede. Nunca incorpore esses arquivos no APK
ou nas fontes. A aplicação gera outra identidade aleatória a cada sessão.
O núcleo do anfitrião está em lib/online/host/; ele roda dentro do aplicativo.
Não é necessário instalar ou executar um servidor dedicado.

Os relatórios desta versão ficam em verification/*v0144*.
A criação da sala pela internet na 0.14.3 foi confirmada pelo usuário.
Os arquivos do transporte permanecem idênticos nesta atualização. Os arquivos com outras
versões registram validações históricas, não novos testes desta entrega.
