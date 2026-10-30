import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../lib/game/content.dart';
import '../lib/game/engine.dart';
import '../lib/game/gpu_frame.dart';
import '../lib/game/math3d.dart';

/// Exports the very same vertices, shaders and camera packets used by Android.
/// The QA renderer validates the GLES pipeline without substituting a mock image.
void main(List<String> args) {
  final root = Directory(args.isEmpty ? 'gpu_qa' : args.first)
    ..createSync(recursive: true);
  void binary(String name, Float32List data) =>
      File('${root.path}/$name.bin').writeAsBytesSync(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
  final tracks = createTracks();
  for (final track in tracks) binary(track.id, GpuResources.world(track));
  binary('showroom', GpuResources.showroom);
  for (var i = 0; i < GpuResources.objects.length; i++)
    binary('object_$i', GpuResources.objects[i]);
  final shots = <Map<String, dynamic>>[];
  for (var ti = 0; ti < tracks.length; ti++) {
    final track = tracks[ti];
    for (var view = 0; view < 2; view++) {
      final race = RaceEngine(
        track: track,
        car: cars[ti % cars.length],
        seed: 42,
      );
      race.countdown = 0;
      race.time = 18;
      race.player.speed = 75;
      race.player.distance = view == 0
          ? 32
          : track.length * (ti == 0 ? .47 : .29);
      for (var i = 0; i < race.bots.length; i++) {
        race.bots[i].distance = race.player.distance + 17 + i * 12;
        race.bots[i].lane = i.isEven ? -.48 : .48;
      }
      shots.add({
        'name': '${track.id}_${view + 1}',
        'world': track.id,
        'night': track.night,
        'showroom': false,
        'frame': raceGpuFrame(race).toList(),
      });
    }
  }
  for (var i = 0; i < cars.length; i++) {
    shots.add({
      'name': 'car_${i + 1}',
      'world': 'showroom',
      'night': false,
      'showroom': true,
      'frame': garageGpuFrame(cars[i], -.69).toList(),
    });
  }
  for (final entry in [
    ('bedroom', const V3(100, .16, 440)),
    ('garage', const V3(-30, .16, 440)),
    ('arcade', const V3(10, .16, 440)),
    ('bathroom', const V3(100, .16, 440)),
    ('kitchen', const V3(50, .16, 450)),
    ('living', const V3(40, .16, 450)),
  ]) {
    final t = tracks.firstWhere((t) => t.id == entry.$1);
    final e = RaceEngine(track: t, car: cars.first, mode: RaceMode.timeTrial)
      ..countdown = 0;
    e.placeDriver(e.player, t.length * .5, 0);
    e.player.position = entry.$2;
    e.player.forward = const V3(0, 0, 1);
    e.player.normal = const V3(0, 1, 0);
    shots.add({
      'name': '${t.id}_furniture',
      'world': t.id,
      'night': false,
      'showroom': false,
      'frame': raceGpuFrame(e).toList(),
    });
    final overview = raceGpuFrame(e);
    overview.setRange(0, 3, [340.0, 230.0, 180.0]);
    overview.setRange(3, 6, [50.0, 35.0, 580.0]);
    overview.setRange(6, 9, [0.0, 1.0, 0.0]);
    overview.setRange(10, 13, [50.0, 35.0, 580.0]);
    shots.add({
      'name': '${t.id}_overview',
      'world': t.id,
      'night': false,
      'showroom': false,
      'frame': overview.toList(),
    });
  }
  final steeringRace = RaceEngine(
    track: tracks[6],
    car: cars.first,
    mode: RaceMode.timeTrial,
  )..countdown = 0;
  steeringRace.player.speed = 38;
  steeringRace.placeDriver(steeringRace.player, tracks[6].length * .46, 0);
  steeringRace.accelerating = true;
  steeringRace.steering = 1;
  steeringRace.driftPressed = true;
  for (var i = 0; i < 90; i++) {
    steeringRace.update(1 / 120);
  }
  shots.add({
    'name': 'drift_wheels',
    'world': tracks[6].id,
    'night': false,
    'showroom': false,
    'frame': raceGpuFrame(steeringRace).toList(),
  });
  final body = garageGpuFrame(cars.first, -.85);
  final d = steeringRace.player;
  // Close view isolates the actual independently transformed front tires.
  final chassis = Float32List.fromList(body.sublist(16, 32));
  final demo = framePacket(
    const V3(-7, 3.7, 8),
    const V3(0, 1, 0),
    const V3(0, 1, 0),
    const V3(0, 1, 0),
    1,
    [
      GpuInstance(0, chassis),
      for (var i = 0; i < 4; i++)
        GpuInstance(
          GpuMeshId.wheel,
          wheelModel(
            chassis,
            cars.first,
            i,
            steer: wheelSteer(d, i),
            roll: d.wheelAngles[i],
          ),
        ),
    ],
  );
  shots.add({
    'name': 'front_tires_steer',
    'world': 'showroom',
    'night': false,
    'showroom': true,
    'frame': demo.toList(),
  });
  final loopRace = RaceEngine(track: tracks.first, car: cars[3]);
  loopRace.countdown = 0;
  loopRace.time = 14;
  loopRace.player.speed = 80;
  loopRace.player.distance = tracks.first.frames
      .firstWhere((f) => f.up.y < -.9)
      .s;
  shots.add({
    'name': 'vertical_loop',
    'world': 'bedroom',
    'night': false,
    'showroom': false,
    'frame': raceGpuFrame(loopRace).toList(),
  });
  loopRace.player.distance = tracks.first.length * .47;
  loopRace.player.shield = 5;
  loopRace.boosting = true;
  loopRace.accelerating = true;
  loopRace.projectiles.add(Projectile(loopRace.player.distance + 20, .2));
  loopRace.oil.add(OilPatch(loopRace.player.distance - 7, 0));
  shots.add({
    'name': 'effects',
    'world': 'bedroom',
    'night': false,
    'showroom': false,
    'frame': raceGpuFrame(loopRace).toList(),
  });
  final track = tracks.first;
  for (final entry in [
    ('loop_entry', track.loopStart! - 18),
    ('loop_exit', track.loopEnd! + 14),
  ]) {
    loopRace.player.distance = entry.$2;
    shots.add({
      'name': entry.$1,
      'world': 'bedroom',
      'night': false,
      'showroom': false,
      'frame': raceGpuFrame(loopRace).toList(),
    });
  }
  final overview = raceGpuFrame(loopRace);
  overview.setRange(0, 3, [-350.0, 210.0, -570.0]);
  overview.setRange(3, 6, [-585.0, 58.0, -280.0]);
  overview.setRange(6, 9, [0.0, 1.0, 0.0]);
  overview.setRange(10, 13, [-585.0, 58.0, -280.0]);
  shots.add({
    'name': 'loop_overview',
    'world': 'bedroom',
    'night': false,
    'showroom': false,
    'frame': overview.toList(),
  });
  final fx = RaceEngine(track: track, car: cars.first)..countdown = 0;
  fx.bots.clear();
  fx.player.distance = 28;
  fx.player.speed = 55;
  fx.accelerating = true;
  final target = Driver('ALVO', cars[1], .5, 82, .15)..speed = 25;
  fx.bots.add(target);
  fx.item = ItemType.missile;
  fx.useItem();
  for (var i = 0; i < 16; i++) {
    fx.update(1 / 120);
  }
  shots.add({
    'name': 'missile_flight',
    'world': 'bedroom',
    'night': false,
    'showroom': false,
    'frame': raceGpuFrame(fx).toList(),
  });
  while (fx.hitCount == 0 && fx.time < 2) {
    fx.update(1 / 120);
  }
  for (var i = 0; i < 18; i++) {
    fx.update(1 / 120);
  }
  fx.player.distance = target.distance - 18;
  shots.add({
    'name': 'missile_impact',
    'world': 'bedroom',
    'night': false,
    'showroom': false,
    'frame': raceGpuFrame(fx).toList(),
  });
  final free = RaceEngine(
    track: track,
    car: cars.first,
    mode: RaceMode.timeTrial,
  )..countdown = 0;
  free.player.speed = 40;
  free.placeDriver(free.player, track.length * .45, 0);
  shots.add({
    'name': 'floor_slalom',
    'world': 'bedroom',
    'night': false,
    'showroom': false,
    'frame': raceGpuFrame(free).toList(),
  });
  free.player.position = const V3(0, TrackSpec.floorHeight, 150);
  free.player.forward = const V3(0, 0, 1);
  free.player.normal = const V3(0, 1, 0);
  shots.add({
    'name': 'floor_free',
    'world': 'bedroom',
    'night': false,
    'showroom': false,
    'frame': raceGpuFrame(free).toList(),
  });
  if (track.ramps.isNotEmpty) {
    final ramp = track.ramps.first.frame;
    final jumper =
        RaceEngine(track: track, car: cars[2], mode: RaceMode.timeTrial)
          ..countdown = 0
          ..accelerating = true;
    jumper.player.speed = 60;
    jumper.placeDriver(jumper.player, ramp.s - 10, 0);
    for (var i = 0; i < 46; i++) {
      jumper.update(1 / 120);
    }
    shots.add({
      'name': 'floor_jump',
      'world': 'bedroom',
      'night': false,
      'showroom': false,
      'frame': raceGpuFrame(jumper).toList(),
    });
  }
  final fall = RaceEngine(
    track: track,
    car: cars.first,
    mode: RaceMode.timeTrial,
  )..countdown = 0;
  fall.placeDriver(
    fall.player,
    track.frames.firstWhere((f) => f.up.y < -.999).s,
    0,
  );
  for (var i = 0; i < 144; i++) fall.update(1 / 120);
  final fallFrame = raceGpuFrame(fall);
  final fp = fall.player.position!;
  fallFrame.setRange(0, 3, [fp.x + 105, fp.y - 6, fp.z + 10]);
  fallFrame.setRange(3, 6, [fp.x, fp.y, fp.z]);
  fallFrame.setRange(6, 9, [0.0, 1.0, 0.0]);
  shots.add({
    'name': 'loop_fall',
    'world': 'bedroom',
    'night': false,
    'showroom': false,
    'frame': fallFrame.toList(),
  });
  final ground = RaceEngine(
    track: track,
    car: cars.first,
    mode: RaceMode.timeTrial,
  )..countdown = 0;
  ground.placeDriver(ground.player, track.length * .5, 0);
  ground.player.position = const V3(0, .16, -500);
  ground.player.normal = const V3(0, 1, 0);
  ground.player.forward = const V3(0, 0, 1);
  ground.projectiles.add(
    Projectile(0, 0)
      ..position = const V3(0, 9, -480)
      ..direction = const V3(0, -1, 0),
  );
  for (var i = 0; i < 28; i++) ground.update(1 / 120);
  shots.add({
    'name': 'ground_explosion',
    'world': 'bedroom',
    'night': false,
    'showroom': false,
    'frame': raceGpuFrame(ground).toList(),
  });
  File('${root.path}/circuits.json').writeAsStringSync(
    jsonEncode([
      for (final t in tracks)
        {
          'id': t.id,
          'name': t.name,
          'room': t.room,
          'length': t.length,
          'stars': t.requiredStars,
          'points': [
            for (final f in t.frames) [f.p.x, f.p.y, f.p.z],
          ],
        },
    ]),
  );
  File('${root.path}/frames.json').writeAsStringSync(jsonEncode(shots));
  for (final name in ['scene.vert', 'scene.frag', 'depth.vert', 'depth.frag']) {
    File('assets/shaders/$name').copySync('${root.path}/$name');
  }
  stdout.writeln(
    'Exported ${shots.length} views, ${tracks.length} circuits and ${GpuResources.objects.length} GPU object meshes.',
  );
}
