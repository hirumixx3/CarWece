# CarWece v1.7.2 — Correção da piscada no ALTA e qualidade restaurada

## A piscada no ALTA (bug da v1.7.1, corrigido)
No hardware fraco, a v1.7.1 ligou ao mesmo tempo a resolução dinâmica
(cena renderizada num alvo fora da tela e copiada para a tela com
`glBlitFramebuffer`) e um framebuffer de tela com MSAA 2×. No OpenGL ES
essa cópia é **inválida**: blit só pode resolver de multissample para
simples, nunca o contrário — a cópia falhava todo quadro e a tela
mostrava buffers pretos/velhos piscando, como na captura enviada.

Correção: com resolução dinâmica, o framebuffer da tela fica sempre
simples e o **MSAA mora dentro do alvo da cena** (renderbuffers
multissample de verdade, resolvidos para a textura antes da cópia
final) — que é o desenho correto e ainda devolve o anti-serrilhado.

## Qualidade restaurada no A05s (a v1.7.1 tinha cortado demais)
- **MÉDIA**: largura de renderização de volta a 1280 (o teto de 1152
  agora só vale para o ALTA, em 1280), **MSAA 2× de volta** (dentro do
  alvo da cena), mapa de sombra de volta a **1024**.
- **ALTA**: **MSAA 4×** (era 2×), filtro de sombra de volta a **5×5**
  perto da câmera, largura 1280.
- **Escala dinâmica sem teto de 85%**: o orçamento continua começando
  em 85% e só sobe para 100% quando o aparelho prova que aguenta;
  continua descendo degraus antes de cair quadro.
- **Sombra em quadros alternados só sob pressão**: enquanto o orçamento
  está saudável, a sombra atualiza todo quadro; o meio-ritmo só entra
  se o aparelho começar a sofrer.
- Permanecem da v1.7.1: ritmo travado em **60 fps estáveis** (sem
  perseguir os 90 Hz) e a detecção de hardware.

## Compatibilidade
- Sem mudança de simulação: online continua compatível com a v1.6.0.
- pubspec: **1.7.2+11**.
