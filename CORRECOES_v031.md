# Pocket Rush 0.3.1 — correção da regressão gráfica

Autor: hirumisu. Versão Android 0.3.1 / código 4.

## Causa confirmada

`GpuResources.objects` passou de 9 para 17 malhas na v0.3 para incluir fumaça, explosão, rastro e clarão de dano. `MainActivity` ainda verificava `meshes.size <= 16`. Logo, o pedido de criação nativa sempre era recusado antes de iniciar EGL. A interface capturava a exceção e mostrava `RacePainter`/`GaragePainter`, os desenhos antigos de compatibilidade. Os testes GLES de desenvolvimento contornavam esse canal e não detectavam o limite errado.

## Correção

- `MainActivity` usa `GraphicsContract.validateCreate`, com capacidade para até 64 malhas e validação de triângulos, dados finitos, índices e instâncias. As 17 malhas atuais são aceitas.
- O Android mantém a renderização GPU. Se ocorrer outra falha nativa, mostra o motivo e a ação TENTAR NOVAMENTE; não muda automaticamente para o desenho antigo.
- A nova tentativa libera a textura anterior. Os shaders só ficam em cache após carregarem com sucesso.
- Sem alteração em física, circuitos, malhas 3D, pacotes de quadro ou shaders da v0.3. A comparação de bytes está em `verification/preserved_v031.json`.

## Prevenção

- Teste Flutter exporta os bytes reais de um pedido `create`, com o cenário, as 17 malhas e uma instância do modelo 16.
- Seis testes JVM decodificam esse StandardMethodCodec com a biblioteca Flutter e passam pelo mesmo validador usado pela Activity. Verificam aceitação dos 17 modelos e modelos futuros dentro do orçamento; rejeição de malha incompleta, índice inexistente, NaN e pacote truncado.
- Três testes de interface Android com canal simulado conferem uso da textura GPU, tratamento de erro sem fallback e liberação/recriação da textura.
- O script de compilação e o workflow incluem o teste da ponte Android.

A validação JVM não inicia EGL, e os testes de widget simulam as respostas do canal. A instalação e a renderização em aparelho físico continuam dependendo do teste no Android do usuário.
