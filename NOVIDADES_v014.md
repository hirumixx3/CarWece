# CarWece 0.14.0 — por hirumisu

- Nome de piloto salvo no próprio jogo; sem senha para a sala de amigos.
- Removida a tela de servidor dedicado, endereço de servidor, cadastro e senha.
- O online agora usa exclusivamente a hospedagem no celular e convite.
- Criação da sala no próprio celular Android e convite para entrar de outras redes.
- Até seis jogadores; corrida nos 26 circuitos e batalha nas seis arenas.
- Nenhum servidor pago, cartão ou conta de provedor necessários para esse modo.
- TLS com chave/certificado novos por sessão e identidade fixada no convite.
- Jogo e rede do anfitrião em isolate separado da interface; serviço de primeiro plano durante a hospedagem.
- Mira verde acompanha o carro selecionado; botão TROCAR MIRA editável no HUD.
- Mira funciona offline e online; teclado C; remove alvos destruídos, bloqueados ou fora de alcance.
- Mantidos ícones personalizados, músicas comprimidas, autoria de hirumisu e crédito Marcos Nascimento (Sage Corp.).

## Limites de teste

A versão é experimental. O retransmissor é um serviço público de terceiros,
sujeito à disponibilidade. O ambiente de compilação não conseguiu resolver
bore.pub para verificar o serviço público. O fluxo de rede é validado com
conexões TCP/TLS/WebSocket reais em loopback e um retransmissor de teste que
implementa o protocolo bore. Não foi testado com dois celulares em casas
diferentes. Não há migração da partida para outro celular se o anfitrião sair.
As moedas da sessão de amigos são temporárias; a carreira offline é preservada.

## Verificação reproduzível

```sh
flutter pub get
flutter analyze
flutter test --dart-define=EXPORT_GRAPHICS_WIRE=true
(cd android && ./gradlew :app:testReleaseUnitTest --no-daemon)
dart run tools/friends_qa.dart
flutter build apk --release --target-platform android-arm,android-arm64,android-x64
```

`HostIdentityTest` exporta um certificado e chave descartáveis para
`build/host_identity/`. São usados somente nos testes TCP/TLS e não devem ser
incluídos no APK nem no pacote de fontes.

Fonte do protocolo do retransmissor: https://github.com/ekzhang/bore .
A implementação Dart é própria, baseada no protocolo documentado, sem incorporar
ou exigir o executável bore no Android.
