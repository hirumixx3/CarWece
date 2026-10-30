# Validação — CarWece 0.13.1+22 — novo ícone

Atualização dos recursos do launcher a partir de `01-23764.png`, preservado em `branding/icon_source_v0131.png`, SHA-256 `d2a32fa95fc553b906f98b7e29276533c9131092eccfc0e4a1037927b169f026`.

Removida somente a margem transparente externa (arte em 925×925, origem 362/362); imagem dimensionada e centralizada nas camadas adaptáveis. Versões comum e redonda conferidas visualmente.

- APK `CarWece_v0.13.1_hirumisu.apk`: 76.661.104 bytes.
- SHA-256 `6fd1956dcd194623892ea8a48fad074a87dbc41a3ab87e1071f539dc865d26a6`.
- CarWece, com.hirumisu.carwece, versionCode 22, Android API 24+, target 35, ARMv7/ARM64/x86_64.
- Certificado anterior: `9e1be273e6871c23013157fad5378ffc4d5da5b222d70f84a995c8cb94ca8d7a`.
- flutter analyze sem problemas; release compilado; assinatura e alinhamento de 16 KB aprovados.
- 20 PNGs compilados comparados pixel a pixel com os mipmaps do projeto em cinco densidades: launcher, round, foreground e background. Todos diferem dos ícones anteriores.
- Duas declarações adaptáveis compiladas apontam para as novas camadas.
- Seis ELF empacotados com tabelas dentro dos limites. As três libflutter.so são idênticas às da 0.13.0. Sem arquivos nativos temporários no APK.
- Introdução, vinte M4As completos, catálogo e shader comparados com as fontes aprovadas. Sem MP3s ou entradas temporárias no APK.

O protocolo online continua carwece-0.13.0, compatível com o servidor já entregue. Esta versão altera ícones e a identificação da versão. As simulações funcionais não foram repetidas para esta alteração visual; os 202 testes Flutter, 51 JVM e testes de rede da 0.13.0 estão em VALIDACAO_v013.md e nos relatórios históricos. Não houve instalação em celular nesta validação.

Evidências atuais: analyze_v0131.txt, build_v0131.txt, apk_verify_v0131.txt, icons_v0131.json, native_integrity_v0131.json, icon_replacement_v0131.json, audio_assets_v0131.json e apk_meta.json.
