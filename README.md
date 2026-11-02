> Auditoria e correções de 02/11/2026. Este ZIP contém código-fonte, não APK.
> Leia `RELATORIO_AUDITORIA_CARWECE.txt` para arquitetura, alterações, testes e limites.
> Validação local: 253 testes Flutter e 65 Kotlin aprovados; APK debug compilado;
> 75 voltas simuladas concluídas e integração LAN/TLS local com seis jogadores.
> Workflows GitHub e publicação assinada ainda dependem dos seus Secrets e execução.

# CarWece 1.2.0 — Play Store / GitHub Actions

Base completa: CarWece 0.14.4, por hirumisu.
Crédito adicional: Marcos Nascimento (Sage Corp.).

Esta edição usa Android API 36, versão 1.2.0 (build local 3) e uma chave de assinatura própria.
Os workflows sugerem versionCode 7 ou superior; escolha um código maior que o último já publicado.
O botão online em destaque, os checkpoints corrigidos e as funções da 0.14.4
foram preservados. As mídias, ícones e o transporte online não foram alterados.

Leia **README_GITHUB_PLAYSTORE.md** para configurar quatro Secrets e gerar AABs.
A chave privada é entregue separadamente; este projeto contém somente o
certificado público. Não coloque o JKS nem o arquivo Base64 no repositório.

O workflow está em `.github/workflows/playstore-aab.yml`. Ele só roda ao acionar
Run workflow, gera de um a seis AABs e disponibiliza os arquivos nos Artifacts.
Não publica automaticamente na Play Store.

Ferramentas fixadas: Flutter 3.35.7, Dart 3.9.2, Java 17, AGP 8.9.1,
Gradle 8.12, compileSdk/targetSdk 36, minSdk 24 e NDK 27.0.12077973.

Validação reproduzível: `flutter pub get`, `flutter analyze`,
`flutter test --concurrency=1` e, na pasta `android`, `./gradlew testDebugUnitTest`.
Os testes Kotlin geram automaticamente seus pacotes gráficos reais usando Flutter.
Para compilar para teste: `flutter build apk --debug`.
Para release assinado, siga o guia de Secrets; nunca substitua sua chave de publicação.
Documentos e resultados de versões antigas foram mantidos como histórico; as evidências
novas estão exclusivamente em `verification/auditoria_2026_11_02/`.
