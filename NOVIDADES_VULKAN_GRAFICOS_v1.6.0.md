# CarWece v1.6.0 — Vulkan, correções gráficas e novo acabamento

## Vulkan
- O app agora roda com o **Impeller ativado e backend Vulkan**
  (`EnableImpeller=true`, `ImpellerBackend=vulkan` no AndroidManifest):
  menus, HUD, composição da tela e o caminho de compatibilidade passam a
  ser apresentados pela pipeline Vulkan nos aparelhos compatíveis.
- O manifesto declara `android.hardware.vulkan.version` (1.1) e
  `android.hardware.vulkan.level` (1) como **opcionais**: quem não tem
  Vulkan continua instalando e jogando pelo caminho compatível.
- A cena 3D nativa continua no renderer GLES 3.0 atual nesta versão; a
  troca dela por um renderer Vulkan nativo próprio é uma reescrita de
  motor (NDK/SPIR-V) que precisa de validação em aparelho real antes de
  virar o caminho padrão — não foi simulada com uma troca cosmética.

## Bugs gráficos corrigidos
- **Buracos pretos/magenta nos brilhos**: a curva em S do grade
  fotográfico era aplicada em HDR e virava negativa acima de ~2,37,
  furando os destaques do clearcoat. O grade agora roda em espaço de
  tela (0..1), depois do tone mapping.
- **Textura "nadando" nos carros**: o ruído procedural de pintura,
  borracha, metal escovado e plástico usava coordenadas do mundo e se
  movia sobre os carros em movimento. Agora usa coordenadas do objeto.
- **Normais erradas em efeitos escalados**: o shader usava `mat3(model)`
  direto; feixes, fumaça e explosões (escala não uniforme) tinham
  iluminação torta. Corrigido com a matriz normal inversa-transposta.
- **Sombra cortada em quadrado**: onde o frustum da luz terminava, a
  sombra sumia de uma vez. Agora há um fade suave na borda.
- **Mistura de transparências fora de ordem**: escudo, fumaça, gelo e
  explosões agora são desenhados de trás para frente, sem um efeito
  distante sobrescrever um próximo.
- **Mundo transparente não projeta mais sombra**: blocos do mundo que
  não podem projetar sombra são pulados no passe de profundidade.
- **Vidro respeita sombra**: os para-brisas não brilham mais através de
  áreas sombreadas.

## Melhorias de design e gráficos
- **Sombras melhores no ALTA**: filtro PCF 5×5 (antes 3×3).
- **Antisserrilhado no MÉDIA**: MSAA 2× na superfície (o ALTA mantém 4×).
- **Pista com cara de circuito usado**: faixa central escura de borracha
  (racing line) e linhas de borda contínuas em creme nas 76 pistas.
- **Showroom de estúdio**: a plataforma giratória ganhou anéis de aço
  escovado embutidos e juntas radiais.
- **Atalho menos neon**: o decalque do atalho saiu do verde-limão para um
  verde dessaturado, combinando com a paleta realista.
- Exposição dos efeitos sem luz alinhada com a cena (1,28).

## Remoção
- **Poder PROPULSOR removido das corridas** (a pedido): saiu do
  `ItemType`, da bolsa de itens, da IA dos bots, das cargas, do efeito e
  do ícone do HUD. Restam 16 itens; Salva Tripla, Dreno de Energia e
  Fantasma continuam. A arma de batalha "PROPULSORES" é outro sistema e
  não foi alterada.

## Versão
- pubspec: **1.6.0+8**; `onlineContent`: `carwece-brasil-3.3-vulkan-graficos`.
