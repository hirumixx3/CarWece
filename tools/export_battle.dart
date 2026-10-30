import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../lib/game/content.dart';
import '../lib/game/engine.dart';
import '../lib/game/gpu_frame.dart';
import '../lib/game/math3d.dart';

void main(List<String> args) {
  final root = Directory(args.isEmpty ? 'gpu_qa_battle' : args.first)
    ..createSync(recursive: true);
  void binary(String name, Float32List data) =>
      File('${root.path}/$name.bin').writeAsBytesSync(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
  final meshes = [...GpuResources.objects, ...BattleGpuMeshes.objects];
  for (var i = 0; i < meshes.length; i++) binary('object_$i', meshes[i]);
  for (final name in ['scene.vert', 'scene.frag', 'depth.vert', 'depth.frag'])
    File('assets/shaders/$name').copySync('${root.path}/$name');
  final frames = <Map<String, dynamic>>[], arenas = createBattleArenas();
  void shot(String name, BattleEngine e, {V3? eye, V3? focus}) {
    final frame = raceGpuFrame(e);
    if (eye != null) frame.setRange(0, 3, [eye.x, eye.y, eye.z]);
    if (focus != null) {
      frame.setRange(3, 6, [focus.x, focus.y, focus.z]);
      frame.setRange(10, 13, [focus.x, focus.y, focus.z]);
      frame.setRange(6, 9, [0.0, 1.0, 0.0]);
    }
    frames.add({
      'name': name,
      'world': e.track.id,
      'showroom': false,
      'night': e.track.night,
      'frame': frame.toList(),
    });
  }

  void advance(BattleEngine e, double seconds) {
    for (var i = 0; i < (seconds * 120).round(); i++) e.update(1 / 120);
  }

  for (final a in arenas) {
    binary(a.track.id, GpuResources.world(a.track));
    final e = BattleEngine(arena: a, car: cars.first, freeRoam: true)
      ..countdown = 0;
    e.human.health = 70;
    shot(
      '${a.track.id}_overview',
      e,
      eye: const V3(-760, 1050, -740),
      focus: const V3(0, 0, 0),
    );
    shot('${a.track.id}_drive', e);
    final ramp = a.track.ramps.first, r = ramp.frame;
    e.player.position = r.p-r.forward*(ramp.length/2+8);
    e.player.forward = r.forward; e.player.normal = r.up;
    shot('${a.track.id}_ramp', e,
      eye:r.p+r.right*48+r.up*30-r.forward*40,
      focus:r.p+r.up*4);
    shot('${a.track.id}_room', e,
      eye:const V3(360,115,-660),focus:const V3(595,105,-875));
    for (var i = 0; i < a.track.loops.length; i++) {
      final loop = a.track.loops[i],
          middle = a.track.at((loop.start + loop.end) / 2);
      e.placeDriver(e.player, loop.start - 85, 0);
      final entry = a.track.at(loop.start);
      final eye =
          middle.p +
          entry.right * 175 +
          const V3(0, 70, 0) -
          entry.forward * 190;
      shot(
        '${a.track.id}_loop_${i + 1}',
        e,
        eye: V3(eye.x.clamp(-820, 820), eye.y, eye.z.clamp(-820, 820)),
        focus: middle.p - const V3(0, 35, 0),
      );
    }
  }
  final a = arenas.first;
  for (final p in BattlePower.values) {
    final e = BattleEngine(arena: a, car: cars.first, freeRoam: true)
      ..countdown = 0;
    e.player.position = const V3(0, .16, -30);
    e.player.forward = const V3(0, 0, 1);
    e.player.normal = const V3(0, 1, 0);
    for (var i = 0; i < e.bots.length; i++) {
      e.bots[i].position = V3((i - 1) * 12.0, .16, i == 1 ? 8 : 35);
      e.bots[i].forward = const V3(0, 0, -1);
      e.bots[i].normal = const V3(0, 1, 0);
    }
    e.human.health = 65;
    e.giveWeapon(e.player, p, 3);
    e.human.target = e.bots[1];
    e.human.manualTarget = true;
    advance(e, .3);
    shot(
      'mount_${p.name}',
      e,
      eye: const V3(12, 9, -15),
      focus: const V3(0, 2.7, -30),
    );
    if ([
      BattlePower.smogCheck,
      BattlePower.roadMine,
      BattlePower.bearHug,
      BattlePower.cactusPatch,
    ].contains(p))
      e.bots[1].position = const V3(0, .16, -42);
    e.useItem();
    final rays = [
      BattlePower.laserCannon,
      BattlePower.quantumAnnihilator,
      BattlePower.deathRay,
      BattlePower.alienLaser,
      BattlePower.superZapper,
      BattlePower.whiteLightning,
    ];
    if (!rays.contains(p))
      advance(
        e,
        [
              BattlePower.invasion,
              BattlePower.gammaSwarm,
              BattlePower.discoInferno,
            ].contains(p)
            ? .7
            : .08,
      );
    shot(
      'weapon_${p.name}',
      e,
      eye: const V3(-25, 23, -70),
      focus: const V3(0, 3, 8),
    );
  }
  File('${root.path}/frames.json').writeAsStringSync(jsonEncode(frames));
  File('verification/battle_catalog_v012.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'arenas': [
        for (final a in arenas)
          {
            'id': a.track.id,
            'name': a.track.name,
            'room': a.track.room,
            'loops': a.track.loops.length,
            'floorNodes': a.nav.length,
            'spawns': a.spawns.length,
            'ammoPickups': a.supplies.length,
            'repairPickups': a.health.length,
          },
      ],
      'weapons': [
        for (final w in battleWeapons)
          {
            'id': w.power.name,
            'name': w.name,
            'reference': w.reference,
            'description': w.description,
            'ammo': w.ammo,
            'damage': w.damage,
            'cooldown': w.cooldown,
          },
      ],
      'frames': frames.length,
      'meshes': meshes.length,
      'stagedViews': true,
      'deviceCapture': false,
    }),
  );
  stdout.writeln(
    'Exported ${frames.length} GLES views, ${arenas.length} arenas and ${meshes.length} meshes.',
  );
}
