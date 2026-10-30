# Validação CarWece 0.12.3+20

## APK e instalação

CarWece_v0.12.3_hirumisu.apk: 74689688 bytes.
SHA-256: `37c00aa832646e0ce2341386aeabf61c1d8e431fc59d87f0f51eda80ae914032`.
Pacote com.hirumisu.carwece, nome CarWece, versionCode 20. Android minSdk 24 / targetSdk 35, ARMv7, ARM64 e x86_64. Certificado `9e1be273e6871c23013157fad5378ffc4d5da5b222d70f84a995c8cb94ca8d7a` mantido.

Assinatura v2, CRC, alinhamento de 16 KiB, vinte PNGs de ícone e duas camadas adaptativas conferidos. Nenhum arquivo temporário ou MP3 está no APK. Os seis ELF têm tabelas de cabeçalho dentro dos limites; as três libflutter.so são idênticas às da versão anterior. Os 44 poderes e os canais nativos de música, gráficos e abertura foram conferidos. O vídeo original, SHA-256 `4e5395f7cbe6db3e29f1081c1bdc56a6c40adaf077c8a70fb9f795528fdcf204`, permanece inteiro e sem compressão ZIP.

## Colisões

Os três cenários novos iniciais falharam na 0.12.2: queda rápida atravessava o deck de altura 20 e terminava em 17,164792; carro invertido penetrava a superfície; e carro no chão percorria 144,715976 unidades sob uma descida, sem bloquear no teto. Ver road_before_v0123.txt.

A correção usa os triângulos das duas faces de todos os trechos próximos, com índice espacial e caches limitados, independente da projeção usada para navegação. Verifica o movimento entre dois passos, a extensão da carroceria e o espaço entre chão e teto. Aterrissagem exige rodas voltadas para a face superior; teto, laterais e faces verticais/invertidas geram impacto e mantêm o carro no ar. O apoio já existente no próprio trecho curvo é preservado para evitar que a triangulação local seja confundida com um teto.

Quatro regressões passaram: queda a 700 unidades/s, carro invertido caindo sobre outro deck, carro no chão atingindo uma pista descendente e impacto aéreo na face vertical de um loop. São unidades internas da simulação, não metros. Os testes anteriores de laterais, passagem sob ponte alta, impacto inferior, aterrissagem, rampas, repouso e ré continuam aprovados. O controlador de referência completou **os 26 circuitos por três voltas**.

## Economia e batalha

Corrida/batalha: primeiro 1.000, segundo 500, terceiro 250, demais zero. Não há multiplicador por dificuldade nem bônus por acertos/eliminações. Contrarrelógio concluído paga 1.000 por ser uma corrida individual em primeiro; exploração e partidas não encerradas não pagam. Testes verificam as seis posições em todas as três dificuldades de corrida, as seis posições da batalha, coerência entre resultado/saldo e bloqueio de registro duplicado de batalha.

FÁCIL/NORMAL/DIFÍCIL aparecem na seleção de arena e são salvos independentemente das corridas. Dois testes de interface, em 1280×720 e 800×360, selecionam Fácil, preservam a corrida em Difícil e verificam o BattleEngine iniciado. Todas as armas continuam sendo obtidas no mapa, com munição finita. Os níveis usam, respectivamente, skill base dos bots 0,72/0,88/0,98; intervalo base de ataque 2,1/1,1/0,58 segundos; dispersão 0,24/0,11/0,055 e fator do dano base das armas 0,72/0,86/0,94. O dano do jogador não recebe esse fator. Efeitos periódicos e colisões continuam usando suas próprias regras.

## Músicas compactas

Vinte faixas completas em AAC-LC, M4A, mono, 24 kHz e alvo de 32 kbps: **193016589 → 19504785 bytes**, redução de 89,89%. A escolha prioriza tamanho e perde estéreo/qualidade. Nenhuma faixa foi removida nem cortada. Cada M4A foi sondado e decodificado integralmente por FFmpeg, com duração a menos de 0,3 segundo da fonte. Depois da geração, todos os arquivos finais foram conferidos novamente por tamanho/SHA-256, e os bytes empacotados correspondem ao catálogo e às fontes compactas. Todos estão sem compressão ZIP, permitindo AssetFileDescriptor no MediaPlayer.

Os IDs e títulos foram mantidos, com Legends Never Die repetindo no menu e outras dezenove músicas na corrida/batalha e seletor no pause. O player Android agora valida nomes .m4a do catálogo. A documentação oficial dos formatos Android inclui AAC-LC/M4A mono e as taxas de amostragem usadas: https://developer.android.com/media/platform/supported-formats . Isso não substitui audição no aparelho.

Os MP3 originais não entram no novo APK nem no novo ZIP; permanecem na versão 0.12.2 do projeto e nas fontes locais. tools/compress_music.py reproduz a conversão com os MP3 como entrada, sem sobrescrevê-los. Ver audio_compression_v0123.json e audio_assets_v0123.json.

## Suítes, desempenho e limites

**192 testes Flutter** passaram; analisador sem problemas. **51 testes JVM** passaram, zero falhas/erros/ignorados, usando código de produção e JUnit/Hamcrest oficiais. Logs, XML e native_summary_v0123.json acompanham a fonte. Isso inclui controles multitoque, HUD, economia, campeonato, poderes, áudio, abertura e os contratos gráficos reais.

O microbenchmark AOT de CPU no computador registrou, nas três cargas medidas, medianas de 978/739/697 µs e médias de 1.084/880/748 µs por atualização de simulação/serialização. Ver performance_v0123.json. São valores do host, não FPS de Android. A nova colisão e o novo equilíbrio alteram trajetórias; a comparação de checksums da versão 0.12.2 é histórica. As otimizações gráficas, AUTO, modelos compactos/indexados, cache de mapas e carregamento em isolate permanecem no código. Shaders e modelos visuais não foram modificados nesta atualização; a bateria de imagens da versão anterior não foi refeita.

Não houve execução/instalação em celular físico ou emulador Android, audição pelo MediaPlayer real, medição de FPS, RAM total, bateria ou temperatura no aparelho. A mesma assinatura permite atualizar sobre a instalação anterior; o fluxo real ainda precisa de teste no celular. A documentação e testes não garantem ausência absoluta de todo bug de física em qualquer situação.

O relatório da versão anterior está em VALIDACAO_v0122.md. Arquivos com outras versões são históricos.
