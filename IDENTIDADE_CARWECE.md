# CarWece 0.5.1 — hirumisu

O aplicativo passa a se chamar **CarWece** e usa `com.hirumisu.carwece` como applicationId, namespace Kotlin e prefixo dos canais nativos. A Activity e os testes JVM foram movidos para `com/hirumisu/carwece`. O pacote Dart passa a se chamar `carwece`; imports, canais de teste e a configuração do protocolo foram atualizados juntos.

O título do app, menu principal, créditos e letreiros de cenário usam a nova marca. Os recursos gráficos preservam as duas imagens aprovadas: o foreground transparente renderizado do RX-7 do jogo e o background Liquid Glass gerado na conversa. Os originais estão em `branding/`; nenhuma nova interpretação artística substitui essas imagens.

Há camadas de 108 dp nas cinco densidades Android, definidas por `mipmap-anydpi-v26/ic_launcher.xml` e `ic_launcher_round.xml`. Recursos legados de 48 dp e suas variantes redondas atendem às versões anteriores. O carro permanece dentro da região central segura; as prévias em `previews/branding/` mostram as máscaras circular e de cantos arredondados.

A chave de desenvolvimento permanece igual. O pacote novo é uma instalação independente: os dados privados de Pocket Rush não são transferidos automaticamente para CarWece. As atualizações seguintes devem continuar usando `com.hirumisu.carwece` e o mesmo certificado para preservar o progresso de CarWece.

Referências de implementação: [ícones adaptativos Android](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive) e [applicationId/namespace](https://developer.android.com/build/configure-app-module).
