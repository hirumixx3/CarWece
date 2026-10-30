import 'dart:convert';
import 'dart:io';
import '../lib/game/content.dart';
import '../lib/game/engine.dart';
import '../lib/game/gpu_frame.dart';
import '../lib/game/math3d.dart';
import 'export_graphics.dart' as previous;

void main(List<String> args) {
  final directory = args.isEmpty ? 'gpu_qa_v07' : args.first;
  previous.main([directory]);
  final root = Directory(directory),
      shots =
          jsonDecode(File('$directory/frames.json').readAsStringSync()) as List;
  final tracks = createTracks(), track = tracks[1];
  void shot(String name, RaceEngine e, {V3? eye, V3? focus}) {
    final frame = raceGpuFrame(e);
    if (eye != null) frame.setRange(0, 3, [eye.x, eye.y, eye.z]);
    if (focus != null) {
      frame.setRange(3, 6, [focus.x, focus.y, focus.z]);
      frame.setRange(10, 13, [focus.x, focus.y, focus.z]);
      frame.setRange(6, 9, [0.0, 1.0, 0.0]);
    }
    shots.add({
      'name': name,
      'world': e.track.id,
      'night': e.track.night,
      'showroom': false,
      'frame': frame.toList(),
    });
  }

  void advance(RaceEngine e, double seconds) {
    for (var i = 0; i < (seconds * 120).round(); i++) e.update(1 / 120);
  }

  // Actual AI controls and physics, without moving opponents into staged lanes.
  final traffic = RaceEngine(track: track, car: cars.first, seed: 84)
    ..countdown = 0;
  for (var i = 0; i < 120 * 6; i++) {
    final c = traffic.aiControls(traffic.player);
    traffic.steering = c.$1;
    traffic.accelerating = c.$2;
    traffic.brake = c.$3;
    traffic.update(1 / 120);
  }
  var mean = V3.zero;
  for (final d in traffic.drivers) mean += d.position!;
  mean *= 1 / traffic.drivers.length;
  final f = track.at(traffic.player.routeS);
  shot(
    'ai_real_traffic',
    traffic,
    eye: mean - f.forward * 90 + const V3(0, 65, 0),
    focus: mean + f.forward * 10,
  );
  File('$directory/ai_snapshot.json').writeAsStringSync(
    jsonEncode({
      'time': traffic.time,
      'stagedPositions': false,
      'drivers': [
        for (final d in traffic.drivers)
          {
            'name': d.name,
            'distance': d.distance,
            'lane': d.lane,
            'position': [d.position!.x, d.position!.y, d.position!.z],
          },
      ],
    }),
  );
  final path = track.shortcuts.single, g = path.gate;
  final gate = RaceEngine(
    track: track,
    car: cars.first,
    mode: RaceMode.timeTrial,
  )..countdown = 0;
  gate.placeDriver(gate.player, path.entryS, 0);
  gate.player.position = g.p - g.forward * 28;
  gate.player.forward = g.forward;
  gate.player.normal = g.up;
  shot('shortcut_gate_closed', gate);
  gate.giveItem(ItemType.missile);
  gate.useItem();
  advance(gate, .35);
  if (!gate.brokenGates.contains(path.id))
    throw StateError('Actual missile failed to open gate');
  shot('shortcut_gate_broken', gate);
  advance(gate, 2.1);
  shot('shortcut_route', gate, eye: g.p + const V3(100, 100, -100), focus: g.p);
  RaceEngine combat() {
    final e = RaceEngine(
      track: track,
      car: cars.first,
      mode: RaceMode.quick,
      difficulty: 'easy',
    )..countdown = 0;
    e.bots.clear();
    final s = track.frames.firstWhere((f) => track.isFloor(f.s)).s + 70;
    e.placeDriver(e.player, s, 0);
    final d = Driver('ALVO', cars[1], .7, s + 25, 0);
    e.bots.add(d);
    e.placeDriver(d, s + 25, 0);
    return e;
  }

  final tesla = combat();
  tesla.giveItem(ItemType.tesla);
  tesla.useItem();
  shot('power_tesla', tesla);
  final ice = combat();
  ice.giveItem(ItemType.ice, enhanced: true);
  ice.useItem();
  advance(ice, .30);
  shot('power_ice', ice);
  final mine = combat();
  mine.giveItem(ItemType.mine);
  mine.useItem();
  advance(mine, .7);
  final minePosition = mine.mines.single.position;
  shot(
    'power_mine',
    mine,
    eye: minePosition - mine.player.forward! * 25 + const V3(14, 18, 0),
    focus: minePosition + mine.player.forward! * 12,
  );
  final smoke = combat();
  smoke.giveItem(ItemType.smoke);
  smoke.useItem();
  advance(smoke, 1.0);
  shot('power_smoke', smoke);
  final emp = combat();
  emp.giveItem(ItemType.emp);
  emp.useItem();
  advance(emp, .18);
  shot('power_emp', emp);
  File('${root.path}/frames.json').writeAsStringSync(jsonEncode(shots));
  File('${root.path}/circuits.json').writeAsStringSync(
    jsonEncode([
      for (final t in tracks)
        {
          'id': t.id,
          'name': t.name,
          'room': t.room,
          'length': t.length,
          'stars': t.requiredStars,
          'barriers': t.barriers.length,
          'props': t.details.length,
          'points': [
            for (final f in t.frames) [f.p.x, f.p.y, f.p.z],
          ],
          'shortcuts': [
            for (final s in t.shortcuts)
              {
                'id': s.id,
                'points': [
                  for (final f in s.frames) [f.p.x, f.p.y, f.p.z],
                ],
                'gate': [s.gate.p.x, s.gate.p.y, s.gate.p.z],
              },
          ],
        },
    ]),
  );
  stdout.writeln(
    'v0.7: ${shots.length} actual GLES views, 54 meshes; traffic packet records real simulation positions.',
  );
}
