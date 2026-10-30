# CarWece — músicas originais e menu aleatório

## Alteração desta revisão

O menu usa as cinco músicas originais em uma fila embaralhada independente da opção de aleatório de corrida/batalha. O sorteio acontece na abertura do aplicativo, ao reabrir o aplicativo em uma tela de menu e a cada retorno real ao menu principal. Também ocorre ao sair de corrida/batalha para uma tela de menu. Navegar do menu principal para suas opções mantém a faixa; voltar ao menu principal escolhe a próxima.

As atualizações de animação, volume e áudio do menu não reiniciam a música. Dentro da mesma execução, a fila evita repetição imediata e percorre as cinco faixas antes de reiniciar o ciclo, salvo seleção manual/falha de reprodução. Encerrar completamente o processo inicia um novo sorteio; não há histórico persistente entre processos.

Corridas continuam com 15 faixas próprias e batalhas com 5. Pausa manual e volume são respeitados. Voltar do segundo plano durante corrida/batalha mantém a faixa e sua posição. Perda momentânea de foco de áudio não é tratada como uma nova entrada no menu.

Também foram corrigidos o título da tela de seleção de músicas, referências a músicas antigas nos testes, o controle de aleatório da batalha que enviava a cena errada e efeitos de clique que podiam trocar indevidamente a playlist para menu.

## Estado desta entrega

**Este pacote é código-fonte, não um APK.**

- 32 testes do controlador Kotlin passaram em execução isolada na JVM, com adaptador de asserções e compilação do código de produção sem alterações.
- Os 25 arquivos musicais foram conferidos contra seus tamanhos e hashes SHA-256.
- Flutter analyze, testes Flutter, build Android e execução em aparelho não foram executados nesta revisão: o ambiente não possui Flutter/Android SDK e falhou ao tentar acessar os servidores de download.
- O workflow foi atualizado, mas não foi executado no GitHub nesta entrega.
- O relatório atual está em `verification/menu_random/`. Relatórios antigos nas demais pastas são históricos, não comprovantes desta revisão.

## Gerar APK assinado no GitHub

Coloque o conteúdo do projeto na raiz do repositório, incluindo a pasta oculta `.github`.

Em **Settings > Secrets and variables > Actions**, cadastre:

| Secret | Conteúdo |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Conteúdo do `.jks.b64` do kit privado |
| `ANDROID_KEYSTORE_PASSWORD` | Senha do keystore enviada separadamente |
| `ANDROID_KEY_PASSWORD` | Senha da chave enviada separadamente |
| `ANDROID_KEY_ALIAS` | Alias `hirumi` |

Não publique JKS, Base64 ou senhas no repositório. O código contém somente o certificado público.

Abra **Actions > CarWece - APK assinado > Run workflow**. Mantenha `version_name=1.0.0` ou escolha outra versão. Escolha um `version_code` superior ao último já publicado; o padrão 7 não é prova de que esse código está disponível na sua conta.

O workflow analisa/testa o Flutter, executa os testes nativos de música, compila o APK release, confere o certificado, o alinhamento e os 25 arquivos de música. Se todos os passos passarem, o APK estará no artefato **CarWece-APK-assinado**, acompanhado do SHA-256 e do relatório de assinatura. A chave temporária é removida ao terminar.

O workflow AAB anterior continua disponível para Play Store e não foi executado nesta revisão.

## Build local

Requisitos do projeto: Flutter 3.35.7, Java 17, Android SDK API 36, build-tools 35.0.0 e NDK 27.0.12077973. Configure `ANDROID_KEYSTORE_PATH` com o caminho absoluto do JKS e as variáveis de assinatura indicadas acima (Base64 não é necessário no build local).

```bash
flutter pub get
flutter analyze
flutter test
(cd android && ./gradlew :app:testReleaseUnitTest --tests com.hirumisu.carwece.MusicDirectorTest)
flutter build apk --release --build-name=1.0.0 --build-number=7 --dart-define=CARWECE_VERSION_NAME=1.0.0
python3 tools/check_apk_music.py build/app/outputs/flutter-apk/app-release.apk
```

Para repetir somente a verificação isolada do controlador com Java/Kotlin instalados:

```bash
python3 tools/run_music_tests_offline.py
```

Essa verificação isolada não substitui os testes Flutter, a compilação Android ou um teste de reprodução no celular.
