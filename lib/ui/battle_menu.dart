import 'package:flutter/material.dart';
import '../game/content.dart';
import '../game/engine.dart';
import 'battle_widgets.dart';
import 'widgets.dart';

class BattleSelection extends StatelessWidget {
  final List<ArenaSpec> arenas;
  final int selected, victories;
  final bool freeRoam;
  final CarSpec car;
  final String difficulty;
  final ValueChanged<String> onDifficulty;
  final ValueChanged<int> onSelect;
  final ValueChanged<bool> onMode;
  final VoidCallback onBack, onStart;
  const BattleSelection({
    super.key,
    required this.arenas,
    required this.selected,
    required this.freeRoam,
    required this.car,
    required this.difficulty,
    required this.onDifficulty,
    required this.victories,
    required this.onSelect,
    required this.onMode,
    required this.onBack,
    required this.onStart,
  });
  @override
  Widget build(BuildContext context) {
    final arena = arenas[selected];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'LIBERDADE PARA ATACAR',
          'ARENAS ABERTAS',
          onBack,
          trailing: RushBadge('$victories VITÓRIAS', color: cyan),
        ),
        Row(
          children: [
            ChoiceChip(
              label: const Text('BATALHA • ELIMINAÇÃO'),
              selected: !freeRoam,
              onSelected: (_) => onMode(false),
            ),
            const SizedBox(width: 10),
            ChoiceChip(
              label: const Text('EXPLORAR / TESTAR PODERES'),
              selected: freeRoam,
              onSelected: (_) => onMode(true),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const Dialog(
                  child: SizedBox(
                    width: 760,
                    height: 430,
                    child: BattleArmory(),
                  ),
                ),
              ),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('ARSENAL • 44'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 360,
                child: GridView.count(
                  crossAxisCount: 2,
                  childAspectRatio: 1.75,
                  mainAxisSpacing: 9,
                  crossAxisSpacing: 9,
                  children: [
                    for (var i = 0; i < arenas.length; i++)
                      Material(
                        color: i == selected ? const Color(0xff274758) : panel,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          key: ValueKey('battle-arena-$i'),
                          onTap: () => onSelect(i),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(11),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  arenas[i].track.room,
                                  style: body(
                                    10,
                                    color: Color(arenas[i].track.accent),
                                    spacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Expanded(
                                  child: Text(
                                    arenas[i].track.name,
                                    style: display(21),
                                    maxLines: 2,
                                  ),
                                ),
                                Text(
                                  '${arenas[i].track.loops.length} LOOP${arenas[i].track.loops.length > 1 ? "S" : ""} • ÁREA LIVRE',
                                  style: body(9, color: muted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(arena.track.name, style: display(32)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xff132539),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: CustomPaint(
                            painter: BattleMapPainter(arena),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      arena.tagline,
                      style: body(11, color: muted),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      freeRoam
                          ? 'Sem ataques ou cronômetro. Três alvos se reconstroem. Comece sem armas e colete poderes nas caixas.'
                          : 'VOCÊ + 5 RIVAIS • 100 DE VIDA • ÚLTIMO SOBREVIVENTE\nTodos começam sem armas: colete nas caixas. Limite de cinco minutos.',
                      style: body(11, color: cyan),
                    ),
                    if (!freeRoam) ...[
                      const SizedBox(height: 4),
                      Text(
                        BattleTuning.forDifficulty(difficulty).description,
                        style: body(10, color: muted),
                      ),
                      Text(
                        'PÓDIO: 1º 1.000 • 2º 500 • 3º 250 MOEDAS',
                        style: body(10, color: orange),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(car.name, style: display(22)),
                  Text(
                    'DIFICULDADE ${difficulty == "easy"
                        ? "FÁCIL"
                        : difficulty == "hard"
                        ? "DIFÍCIL"
                        : "NORMAL"} • DIREÇÃO E ACELERAÇÃO MANUAIS',
                    style: body(10, color: muted),
                  ),
                ],
              ),
            ),
            if (!freeRoam)
              Padding(
                padding: const EdgeInsets.only(right: 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'DIFICULDADE DA BATALHA',
                      style: body(9, color: muted),
                    ),
                    Wrap(
                      spacing: 5,
                      children: [
                        for (final entry in const {
                          'easy': 'FÁCIL',
                          'normal': 'NORMAL',
                          'hard': 'DIFÍCIL',
                        }.entries)
                          ChoiceChip(
                            key: ValueKey('battle-difficulty-${entry.key}'),
                            label: Text(entry.value, style: body(11)),
                            selected: difficulty == entry.key,
                            onSelected: (_) => onDifficulty(entry.key),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            RushButton(
              freeRoam ? 'EXPLORAR ARENA' : 'INICIAR BATALHA',
              primary: true,
              icon: freeRoam
                  ? Icons.explore_outlined
                  : Icons.local_fire_department_rounded,
              onTap: onStart,
            ),
          ],
        ),
      ],
    );
  }
}

class BattleResults extends StatelessWidget {
  final BattleEngine battle;
  final VoidCallback onAgain, onArenas, onHome;
  const BattleResults({
    super.key,
    required this.battle,
    required this.onAgain,
    required this.onArenas,
    required this.onHome,
  });
  @override
  Widget build(BuildContext context) {
    final won = battle.result?.position == 1 && battle.human.alive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(battle.arena.track.name, 'RESULTADO DA BATALHA', onHome),
        Row(
          children: [
            Text(
              won
                  ? 'SOBREVIVENTE!'
                  : battle.human.alive
                  ? 'FIM DA BATALHA'
                  : 'CARRO DESTRUÍDO',
              style: display(44, color: won ? cyan : orange),
            ),
            const Spacer(),
            RushBadge('+${battle.reward} MOEDAS', color: orange),
          ],
        ),
        Text(
          '${battle.result?.position ?? 1}º LUGAR • ${battle.human.kills} eliminações • ${battle.human.damageDealt.round()} de dano • ${battle.time.toInt()}s${battle.timedOut ? " • LIMITE DE TEMPO" : ""}',
          style: body(12, color: muted),
        ),
        const SizedBox(height: 15),
        Expanded(
          child: ListView(
            children: [
              for (final d in battle.standings)
                Container(
                  margin: const EdgeInsets.only(bottom: 7),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: d == battle.player ? const Color(0xff274252) : panel,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          d.name,
                          style: display(
                            22,
                            color: d == battle.player ? cyan : cream,
                          ),
                        ),
                      ),
                      Expanded(child: Text(d.car.name, style: body(12))),
                      Text(
                        '${battle.fighters[d]!.kills} ELIM.   ${battle.fighters[d]!.damageDealt.round()} DANO   ${battle.fighters[d]!.health.ceil()} VIDA',
                        style: body(11, color: muted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            RushButton('MENU', compact: true, onTap: onHome),
            const SizedBox(width: 10),
            RushButton('OUTRA ARENA', compact: true, onTap: onArenas),
            const SizedBox(width: 10),
            RushButton('JOGAR NOVAMENTE', primary: true, onTap: onAgain),
          ],
        ),
      ],
    );
  }
}
