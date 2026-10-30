> Revisão: menu aleatório. Veja `GUIA_APK_MUSICAS.md`. Este ZIP contém código-fonte;
> não contém APK. Foram executados 32 testes isolados do controlador de música.
> O build Flutter/Android e o workflow GitHub ainda precisam ser executados.

# CarWece 1.0.0 — Play Store / GitHub Actions

Base completa: CarWece 0.14.4, por hirumisu.
Crédito adicional: Marcos Nascimento (Sage Corp.).

Esta edição usa Android API 36, versão 1.0.0 e uma chave de assinatura própria.
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
