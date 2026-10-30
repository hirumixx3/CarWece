# Validação CarWece 0.14.4+27

Base: código completo da 0.14.3. Autoria: hirumisu.
Crédito adicional: Marcos Nascimento (Sage Corp.).

- 219 testes Flutter aprovados; análise sem problemas.
- 52 testes nativos aprovados, sem falhas, erros ou testes ignorados.
- Três regressões reproduzidas antes da correção: carro sobre o plano do
  checkpoint, checkpoint sobreposto já contado antes da entrada do atalho,
  e salto dentro do atalho. As três passaram após a correção.
- Todos os atalhos foram percorridos e a volta atual foi concluída sem exigir
  outro circuito completo. Entrar pela saída e andar para trás não dão crédito.
- Testes anteriores de portões fechados, destruição, loops, quedas, pista sólida,
  colisões, circuitos completos, batalha, rede e progresso offline passaram.
- JOGAR ONLINE aparece como botão grande ciano entre os modos principais.
  Home e créditos renderizados; online verificado em 1280×720 e 800×360.
- Emblemas de teste retirados do aplicativo. Setas verdes dos atalhos retiradas
  da geometria; a mensagem para segui-las foi removida.
- Transporte online, bibliotecas de terceiros, mídias, ícones, código nativo e
  chave de assinatura comparados byte a byte com a 0.14.3 e preservados.
- Pacote com.hirumisu.carwece, nome CarWece, versão 0.14.4, código 27,
  armeabi-v7a/arm64-v8a/x86_64, assinatura original v2 e alinhamento de 16 KB.
- Vinte PNGs, dois ícones adaptativos, vídeo, músicas, shaders e ELF verificados.
- JOGAR ONLINE presente nos três binários. Os antigos emblemas de teste e o
  aviso para seguir setas verdes estão ausentes dos três binários de release.

A criação de sala pela internet na 0.14.3 foi confirmada pelo usuário. Não
houve novo teste em dois celulares nesta entrega; a correção de checkpoints
foi verificada na simulação compartilhada pelo offline e pelo anfitrião online.
A imagem da home de QA usa o canal gráfico simulado, sem renderização nativa
completa do carro. O código do renderizador nativo não foi alterado.

APK: CarWece_v0.14.4_hirumisu.apk
Bytes: 81986656
SHA-256: fc8268ab2136fa3110cae5aaf4fe8975c80589140a552d18eee4bc4b9b130b04
Certificado SHA-256: 9e1be273e6871c23013157fad5378ffc4d5da5b222d70f84a995c8cb94ca8d7a

Os arquivos *v0144* registram esta entrega; os demais são históricos.
