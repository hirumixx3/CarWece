# CarWece 1.0.0 — pacote de publicação

Base: jogo completo da 0.14.4. Autoria: hirumisu.
Crédito adicional: Marcos Nascimento (Sage Corp.).

- Seis AABs reais gerados pelo Flutter/Gradle, versão 1.0.0, códigos 1 a 6.
- Pacote com.hirumisu.carwece; compileSdk/targetSdk 36 e minSdk 24.
- Todos assinados com a mesma nova chave RSA de 4096 bits, alias hirumi.
- Certificado SHA-256: 36d37a19082d266b741937d4ac7d0fc0d7d581017d1a5b5cae4bab5b5d91433a.
- Bundletool 1.18.3 validou estrutura e manifests de todos os seis bundles.
- Jarsigner validou as assinaturas e o certificado foi comparado ao PEM entregue.
- As bibliotecas arm64-v8a e x86_64 têm segmentos ELF LOAD de 65536 bytes,
  compatíveis com páginas de 16 KB; o BundleConfig solicita alinhamento de 16 KB.
- 28 assets declarados foram comparados com as fontes em cada AAB.
- Nenhum AAB contém o JKS privado, seu Base64 ou key.properties.
- APK universal gerado a partir do AAB 1: identidade, três ABIs, assinatura v2,
  alinhamento ZIP de 16 KB, vinte PNGs, dois ícones adaptativos, vídeo, músicas,
  shaders e bibliotecas nativas conferidos.
- 219 testes Flutter aprovados; análise sem problemas.
- 52 testes JVM/API 36 aprovados, sem falhas, erros ou testes ignorados.
- 111 arquivos de jogabilidade, rede, UI auxiliar, mídias, ícones e código
  nativo permanecem idênticos à base 0.14.4. O nome de versão exibido acompanha
  a configuração de build, com padrão 1.0.0.
- Workflow GitHub Actions incluído. YAML e restauração da chave via Secrets
  verificados localmente. O workflow não foi executado na conta do usuário.

Não houve envio à Play Console, aprovação da loja ou nova execução em aparelho
Android/ambiente de memória de 16 KB. A verificação de 16 KB é estrutural.
Esta assinatura é nova e não substitui diretamente os APKs de teste anteriores.
A chave privada é entregue separadamente do projeto para o GitHub.
