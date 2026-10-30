# Validação — CarWece 0.13.0+21 — 28/10/2026

## Entrega

- APK universal de 76.525.192 bytes: `CarWece_v0.13.0_hirumisu.apk`.
- SHA-256: `35d7dda0ca204bcb036896beea6804cc8f330d486f6dd7ba14fc7a8b315acdfe`.
- Pacote `com.hirumisu.carwece`, nome CarWece, versionCode 21, Android API 24+, target 35, GLES 3.0, ARMv7/ARM64/x86_64.
- Certificado anterior preservado: `9e1be273e6871c23013157fad5378ffc4d5da5b222d70f84a995c8cb94ca8d7a`.
- Os vinte PNGs dos ícones e as duas composições adaptáveis foram comparados. Vídeo de abertura e vinte músicas M4A foram comparados byte a byte com os arquivos aprovados. Não há MP3s no APK. Os créditos de Marcos Nascimento (Sage Corp.) estão compilados nas três arquiteturas.

## Verificações executadas

- **202 testes Flutter aprovados**, sem falhas. Incluem os testes anteriores de condução, loops, superfícies sólidas, poderes, progressão, músicas, introdução e renderização, além das verificações novas de rede e telas online.
- **51 testes JVM aprovados**, sem falhas, erros ou testes ignorados: GraphicsContract 7, BattleGraphicsContract 6, RenderOptimization 9, MusicDirector 19, IntroDirector 10.
- `flutter analyze` e `dart analyze` do servidor: nenhum problema.
- APK release compilado, assinatura verificada e alinhamento de 16 KB conferido. Cabeçalhos e tabelas ELF dentro dos limites dos seis arquivos nativos.
- Servidor headless e programas de QA compilados para executáveis Dart AOT Linux x86_64. Testes de rede executados com HTTP e WebSockets reais em loopback, usando o cliente entregue.
- **26 circuitos e 6 arenas** carregados em salas com dois clientes reais autenticados; verificados o mapa, comandos, snapshot, munição, classificação individual e recompensa única. Para testar os resultados rapidamente, o QA ajusta no servidor os estados finais/tempo: não equivale a completar 32 partidas manuais pela internet.
- **Sete clientes reais autenticados** no teste de resiliência: seis na sala e o sétimo rejeitado. Verificados autorização do anfitrião, rejeição de carro bloqueado, espera pelos seis carregamentos, pause local, reconexão à mesma simulação, transferência de anfitrião, abandono sem prêmio e nova partida na sala.
- Campos de posição e moedas enviados pelo cliente são ignorados. Inventários e nitro são independentes; armas não vêm pré-carregadas. A munição, os efeitos visuais e os 44 tipos de armas são preservados na serialização. Vácuo, plataformas de turbo e superescudo foram verificados também para jogadores visitantes.
- Vetor conhecido de PBKDF2-HMAC-SHA256 aprovado; cadastro de teste usa as 600 mil iterações de produção. Banco restaurado após salvamento; senha não aparece em texto e tokens são persistidos somente como hashes no servidor.
- Telas de login/seleção verificadas em 1280×720 e 800×360. Créditos conferidos visualmente. As imagens em `previews/online_v013` são renderizações de widgets, com textura/áudio de plataforma simulados.

## Limites

Esta é uma alfa online. **Não foi publicado um servidor público**. Não houve teste em aparelho Android, rede móvel ou internet entre aparelhos. Não houve medição de FPS, bateria, calor, latência ou capacidade de uma VM gratuita. O contêiner Docker/Caddy, a emissão pública de certificado e o executável ARM64 deverão ser conferidos na hospedagem escolhida. A compilação AOT testada aqui é Linux x86_64; o Docker compila na arquitetura da VM.

O cliente interpola o estado recebido e ainda não tem previsão completa da física nem compensação de atraso de tiros. Os sons de motor/músicas são locais; o protocolo inicial prioriza física e efeitos visuais. Não há recuperação de senha. A carreira online é independente da offline e começa com RX-7; cada servidor possui seu próprio banco. Partidas em curso não sobrevivem ao reinício do servidor.

Evidências atuais: `tests_v013.txt`, `analyze_v013.txt`, `native_v013/`, `native_summary_v013.json`, `online_transport_v013.json`, `online_resilience_v013.json`, `online_aot_v013.txt`, `resilience_aot_v013.txt`, `server_analyze_v013.txt`, `server_build_v013.txt`, `apk_meta.json`, `native_integrity_v013.json`, `audio_assets_v013.json` e `icons_v013.json`. Relatórios de versões anteriores são históricos.
