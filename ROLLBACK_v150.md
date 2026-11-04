# CarWece — retorno à v1.5.0 (04/11/2026)

Base: commit `a7658c3` do GitHub (a v1.5.0 que rodava antes da saga de
desempenho), restaurado integralmente. Duas alterações a pedido sobre
essa base:

1. **Workflows sem verificações de artefato**
   - `signed-apk.yml`: a etapa "Verificar assinatura, músicas e
     alinhamento" virou "Preparar APK para download" (só copia o APK
     para `dist/` e gera o SHA256SUMS; sem apksigner/zipalign/checks).
   - `playstore-aab.yml`: removida a etapa "Validar bundles e
     compatibilidade de 16 KB" (e o `validation.json` da lista de
     upload). Mantida a etapa "Validar versão e segredos" do APK
     assinado, que é só a conferência dos inputs/segredos antes da
     build.
2. **Poder Propulsor removido das corridas** (o mesmo corte da antiga
   v1.6.0): enum, nome, cargas, ativação, pool dos bots e ícone saíram;
   restam 16 itens. A arma de batalha PROPULSORES é outro sistema e
   ficou. `onlineContent` novo: `carwece-brasil-3.2-sem-propulsor`.

Validação local: analyze limpo, suíte completa 279/279 verde.
pubspec segue **1.5.0+7**.
