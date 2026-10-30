import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game/content.dart';
import '../game/engine.dart';
import '../game/math3d.dart';
import 'widgets.dart';
import 'map_geometry.dart';

class BattleMapPainter extends CustomPainter {
  final ArenaSpec arena;
  final BattleEngine? battle;
  BattleMapPainter(this.arena, {this.battle});
  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 1760;
    Offset point(V3 p) =>
        Offset(size.width / 2 + p.x * scale, size.height / 2 - p.z * scale);
    final bounds = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: 1700 * scale,
      height: 1700 * scale,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(9)),
      Paint()..color = const Color(0xff1b3543),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(9)),
      Paint()
        ..color = const Color(0xff68808b)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final geometry = ArenaMapGeometry.forTrack(arena.track);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.drawPath(
      geometry.obstacles,
      Paint()..color = const Color(0xff667576),
    );
    canvas.drawPath(
      geometry.floor,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xff4a7e83)
        ..strokeWidth = 1 / scale,
    );
    canvas.drawPath(
      geometry.raised,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xffffa467)
        ..strokeWidth = 2.2 / scale,
    );
    canvas.restore();
    if (battle == null) {
      for (final p in arena.supplies)
        canvas.drawCircle(
          point(p),
          2.2,
          Paint()..color = const Color(0xffffcc77),
        );
      for (final p in arena.health)
        canvas.drawCircle(
          point(p),
          3,
          Paint()..color = const Color(0xff8ceca5),
        );
    } else {
      final b = battle!;
      for (final p in b.pickups.where((p) => p.cooldown <= 0))
        canvas.drawCircle(
          point(p.position),
          1.6,
          Paint()
            ..color = p.health
                ? const Color(0xff8ceca5)
                : const Color(0xffffcc77),
        );
      for (final d in b.bots) {
        final f = b.fighters[d]!;
        if (!f.alive || f.jammer > 0) continue;
        canvas.drawCircle(
          point(d.position!),
          d == b.human.target ? 3.5 : 2.5,
          Paint()
            ..color = d == b.human.target
                ? const Color(0xff42ff67)
                : Color(d.car.color),
        );
      }
      final p = point(b.player.position!), f = b.player.forward!;
      final forward = Offset(f.x, -f.z),
          right = Offset(-forward.dy, forward.dx);
      canvas.drawPath(
        Path()..addPolygon([
          p + forward * 5,
          p - forward * 3 + right * 3,
          p - forward * 3 - right * 3,
        ], true),
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BattleMapPainter old) =>
      battle != null || old.battle != null || arena != old.arena;
}

class BattleArmory extends StatefulWidget {
  final BattleEngine? battle;
  final VoidCallback? onSelected;
  const BattleArmory({super.key, this.battle, this.onSelected});
  @override
  State<BattleArmory> createState() => _BattleArmoryState();
}

class _BattleArmoryState extends State<BattleArmory> {
  bool catalog = false;
  String query = '';
  @override
  Widget build(BuildContext context) {
    final b = widget.battle;
    final entries = battleWeapons
        .where(
          (w) =>
              (b == null || catalog || (b.human.ammo[w.power] ?? 0) > 0) &&
              ('${w.name} ${w.reference} ${w.family}').toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    return ColoredBox(
      color: ink,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, color: cyan),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    b == null ? 'ARSENAL DA BATALHA' : 'ARMAS NO CARRO',
                    style: display(27),
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar arsenal',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('battle-weapon-search'),
                    onChanged: (v) => setState(() => query = v),
                    style: body(13),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Buscar arma ou poder',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                if (b != null) ...[
                  const SizedBox(width: 10),
                  FilterChip(
                    label: const Text('CATÁLOGO'),
                    selected: catalog,
                    onSelected: (v) => setState(() => catalog = v),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: entries.isEmpty && b != null && query.isEmpty
                  ? Center(
                      child: Text(
                        'SEM PODER\nPasse pelas caixas no mapa para se armar.',
                        textAlign: TextAlign.center,
                        style: body(15, color: cyan),
                      ),
                    )
                  : ListView.builder(
                      key: const ValueKey('battle-armory-list'),
                      itemCount: entries.length,
                      itemBuilder: (context, i) {
                        final w = entries[i],
                            ammo = b?.human.ammo[w.power] ?? 0,
                            owned = b != null && ammo > 0;
                        return Card(
                          color: b?.human.selected == w.power
                              ? const Color(0xff244652)
                              : panel,
                          child: ListTile(
                            key: ValueKey('battle-weapon-${w.power.name}'),
                            dense: true,
                            leading: Icon(
                              w.support
                                  ? Icons.shield_outlined
                                  : Icons.flash_on_rounded,
                              color: Color(w.color),
                            ),
                            title: Text(w.name, style: body(13)),
                            subtitle: Text(
                              '${w.reference} • ${w.family}\n${w.description}',
                              style: body(10, color: muted),
                            ),
                            trailing: b == null
                                ? null
                                : Text(
                                    owned ? '×$ammo' : 'COLETE',
                                    style: body(
                                      11,
                                      color: owned ? cyan : muted,
                                    ),
                                  ),
                            onTap: owned
                                ? () {
                                    b.selectWeapon(w.power);
                                    widget.onSelected?.call();
                                    setState(() {});
                                  }
                                : null,
                          ),
                        );
                      },
                    ),
            ),
            Text(
              b == null
                  ? '44 adaptações: 13 gadgets, 6 armas básicas, 13 especiais, 10 combos e 2 bônus.'
                  : 'A arena permanece pausada. Feche o painel e toque CONTINUAR.',
              style: body(10, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

class BattleRivals extends StatelessWidget {
  final BattleEngine battle;
  final double scale;
  final VoidCallback onReset, onTarget;
  const BattleRivals({
    super.key,
    required this.battle,
    required this.scale,
    required this.onReset,
    required this.onTarget,
  });
  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          battle.freeRoam
              ? 'EXPLORAÇÃO LIVRE'
              : 'VIDA DOS RIVAIS • TOQUE PARA MIRAR',
          style: body(8 * s, color: cyan),
        ),
        for (final d in battle.bots)
          InkWell(
            onTap: () {
              if (battle.selectTarget(d)) {
                onTarget();
              }
            },
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 1.4 * s),
              child: Row(
                children: [
                  SizedBox(
                    width: 39 * s,
                    child: Text(
                      d.name,
                      style: body(
                        8 * s,
                        color: battle.human.target == d ? cyan : cream,
                      ),
                    ),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: battle.fighters[d]!.health / 100,
                      minHeight: 3 * s,
                      color: battle.fighters[d]!.health > 35
                          ? const Color(0xff8de39c)
                          : orange,
                      backgroundColor: const Color(0xff334255),
                    ),
                  ),
                  SizedBox(
                    width: 22 * s,
                    child: Text(
                      '${battle.fighters[d]!.health.ceil()}',
                      textAlign: TextAlign.right,
                      style: body(8 * s, color: muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (battle.freeRoam)
          Expanded(
            child: Text(
              'Loops, saltos e 44 poderes.\nSem voltas ou checkpoints.',
              style: body(10 * s, color: muted),
            ),
          ),
        TextButton.icon(
          onPressed: onReset,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size(60, 20 * s),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: Icon(Icons.replay_rounded, size: 13 * s),
          label: Text('REPOR CARRO', style: body(8 * s, color: cream)),
        ),
      ],
    );
  }
}
