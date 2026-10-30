# Compilar CarWece 1.0.0 pelo GitHub

Autoria: hirumisu. Crédito adicional: Marcos Nascimento (Sage Corp.).
Base do jogo: 0.14.4, com online, atalhos e checkpoints corrigidos.

## Arquivos e assinatura

Os AABs 1 a 6 exibem a versão 1.0.0 e têm códigos diferentes. Todos usam a
mesma chave RSA de 4096 bits, com alias **hirumi**. Use as senhas fornecidas no kit privado. Não grave senhas no repositório.
Guarde o JKS e uma cópia de backup.

No código-fonte há somente `android/hirumi-upload-certificate.pem`, que é público.
O JKS e seu Base64 são privados e foram entregues no kit de assinatura separado.
Não envie esses dois arquivos ao repositório, mesmo se ele for privado.

## Configurar quatro Secrets

1. Extraia o projeto e coloque seu conteúdo na raiz do repositório: `pubspec.yaml`,
   `lib/`, `android/` e `.github/` devem estar no nível principal do GitHub.
2. Em Settings > Secrets and variables > Actions > New repository secret, adicione:

| Secret | Valor |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Conteúdo inteiro de `hirumi-upload.jks.b64`, no kit privado |
| `ANDROID_KEYSTORE_PASSWORD` | Senha do keystore, fornecida separadamente |
| `ANDROID_KEY_PASSWORD` | Senha da chave, fornecida separadamente |
| `ANDROID_KEY_ALIAS` | `hirumi` |

3. Abra Actions > CarWece - AAB assinado > Run workflow.
4. Para repetir estes seis arquivos, use versão `1.0.0`, primeiro código `1`,
   quantidade `6`. Para atualizações após publicar o código 6, use `7` ou maior.
5. Ao terminar, baixe o artifact `CarWece-1.0.0-AABs`; ele contém os AABs,
   `SHA256SUMS.txt` e `release-manifest.json`.

O workflow instala API 36, resolve as dependências, analisa o código, executa
os testes e compila. Também valida os manifests e a estrutura com bundletool,
a assinatura e o alinhamento de 16 KB das bibliotecas de 64 bits. As senhas entram por variáveis de ambiente. O JKS é
reconstruído no diretório temporário do runner e removido ao terminar.
O script também recusa arquivos assinados por um certificado diferente do
certificado público deste projeto. Os AABs não incluem o JKS nem as senhas.

Se preferir gerar o Base64 novamente:

```sh
base64 -w 0 hirumi-upload.jks > hirumi-upload.jks.b64
```

Em PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('hirumi-upload.jks')) | Set-Content -Encoding ascii hirumi-upload.jks.b64
```

## Compilar localmente

Com Flutter e Android SDK instalados, configure as quatro variáveis abaixo.
O caminho precisa apontar para a chave privada entregue separadamente.

```sh
export ANDROID_KEYSTORE_PATH='/caminho/absoluto/hirumi-upload.jks'
export ANDROID_KEYSTORE_PASSWORD='SUA_SENHA_DO_KEYSTORE'
export ANDROID_KEY_PASSWORD='SUA_SENHA_DA_CHAVE'
export ANDROID_KEY_ALIAS='hirumi'
flutter pub get
python3 tools/build_play_bundles.py --version-name 1.0.0 --first-code 1 --count 6
```

Para uma única atualização posterior:

```sh
python3 tools/build_play_bundles.py --version-name 1.0.1 --first-code 7 --count 1
```

Os arquivos saem em `dist/`. O nome exibido no jogo acompanha `--version-name`.
É possível usar `android/key.properties`, copiando o exemplo, com comandos Flutter
diretos; o script de lote acima usa as quatro variáveis de ambiente.

## Enviar à Play Console

Use o AAB correspondente à versão que deseja publicar. Os códigos 1 a 6 são
sucessivos; não são seis aplicativos distintos. Cada atualização precisa de um
código maior e ainda não utilizado. A versão exibida pode continuar 1.0.0.

Esta é uma nova identidade de publicação. Os APKs de desenvolvimento foram
assinados com outra chave e tinham código 27: estes AABs não os atualizam
localmente. Faça backup do progresso antes de remover uma instalação de testes.

A chave entregue assina o envio dos AABs. Ao configurar Play App Signing,
a assinatura dos APKs distribuídos é gerenciada conforme a opção escolhida
na Play Console. O certificado PEM também é fornecido para identificar a chave.
Nenhuma publicação ou configuração da sua conta foi executada aqui.

## Referências oficiais

- [API mínima de destino exigida pela Play Store](https://support.google.com/googleplay/android-developer/answer/11926878)
- [Versionamento e códigos de versão](https://developer.android.com/studio/publish/versioning)
- [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756)
- [Compatibilidade com páginas de 16 KB](https://developer.android.com/guide/practices/page-sizes)
- [Flutter para Android](https://docs.flutter.dev/deployment/android)
