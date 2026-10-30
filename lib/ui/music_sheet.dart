import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../music.dart';
import '../platform.dart';
import 'widgets.dart';

class MusicSheet extends StatefulWidget {
  final GameStore store;
  const MusicSheet({super.key, required this.store});
  @override
  State<MusicSheet> createState() => _MusicSheetState();
}

class _MusicSheetState extends State<MusicSheet> {
  GameStore get store => widget.store;
  @override
  Widget build(BuildContext context) {
    final player = store.soundtrack;
    return AnimatedBuilder(
      animation: player,
      builder: (context, _) => SizedBox(
        height: math.min(620, MediaQuery.sizeOf(context).height * .94),
        child: ColoredBox(
          color: ink,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 5, 18, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.queue_music_rounded, color: cyan),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        player.scene == 'battle'
                            ? 'MÚSICAS DA BATALHA'
                            : 'MÚSICAS DA CORRIDA',
                        style: display(25),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar músicas',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton.filledTonal(
                      key: const ValueKey('music-play-pause'),
                      tooltip: player.playing
                          ? 'Pausar música'
                          : 'Reproduzir música',
                      onPressed: () => unawaited(player.toggle()),
                      icon: Icon(
                        player.playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            player.current?.title ?? 'Sua trilha, seu ritmo.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: body(14, color: cyan),
                          ),
                          Text(
                            player.error ??
                                (player.status == 'loading'
                                    ? 'Carregando música…'
                                    : player.current?.artist ??
                                          '${player.scene == 'battle' ? battleSongs.length : raceSongs.length} faixas disponíveis offline'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: body(11, color: muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    TextButton.icon(
                      key: const ValueKey('music-next'),
                      onPressed: () => unawaited(player.next()),
                      icon: const Icon(Icons.skip_next_rounded),
                      label: const Text('PULAR FAIXA'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      key: const ValueKey('music-shuffle'),
                      selected: store.settings.musicShuffle,
                      avatar: const Icon(Icons.shuffle_rounded, size: 17),
                      label: const Text('ALEATÓRIO'),
                      onSelected: (v) {
                        setState(() => store.settings.musicShuffle = v);
                        store.changed();
                        unawaited(player.setShuffle(v));
                      },
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.volume_up_rounded, size: 20, color: muted),
                    Expanded(
                      child: Slider(
                        key: const ValueKey('music-volume'),
                        value: store.settings.music,
                        onChanged: (v) {
                          setState(() => store.settings.music = v);
                          unawaited(store.audio(scene: player.scene));
                        },
                        onChangeEnd: (_) => store.changed(),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 4, color: Color(0xff34435c)),
                Expanded(
                  child: ListView.builder(
                    key: const ValueKey('race-music-list'),
                    itemCount: (player.scene == 'battle' ? battleSongs : raceSongs).length,
                    itemBuilder: (context, index) {
                      final song = (player.scene == 'battle' ? battleSongs : raceSongs)[index],
                          selected = player.trackId == song.id;
                      return ListTile(
                        key: ValueKey('song-${song.id}'),
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -2),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        leading: Icon(
                          selected
                              ? Icons.equalizer_rounded
                              : Icons.music_note_rounded,
                          color: selected ? cyan : muted,
                          size: 22,
                        ),
                        title: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: body(13, color: selected ? cyan : cream),
                        ),
                        subtitle: Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: body(10, color: muted),
                        ),
                        trailing: Text(
                          song.durationLabel,
                          style: body(11, color: muted),
                        ),
                        selected: selected,
                        selectedTileColor: const Color(0x1937d8c3),
                        onTap: () => unawaited(player.select(song.id)),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    'A corrida continua pausada. Ao terminar uma faixa, a próxima começa sozinha.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body(10, color: muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
