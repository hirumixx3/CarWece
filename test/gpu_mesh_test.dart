import 'package:flutter_test/flutter_test.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';
import 'package:carwece/game/gpu_frame.dart';
import 'package:carwece/game/gpu_mesh.dart';
import 'package:carwece/game/math3d.dart';

void main() {
  final tracks = createTracks();
  test(
    'All uploaded meshes have finite complete triangles and valid materials',
    () {
      Iterable<List<double>> meshes() sync* {
        for (final track in tracks) yield GpuResources.world(track);
        yield GpuResources.showroom;
        yield* GpuResources.objects;
      }

      for (final data in meshes()) {
        expect(data.length % 36, 0);
        expect(data.every((v) => v.isFinite), isTrue);
        var invalidNormal = -1, invalidMaterial = -1;
        for (var i = 0; i < data.length; i += 12) {
          final normal = V3(data[i + 3], data[i + 4], data[i + 5]);
          if ((normal.length - 1).abs() > .0001) invalidNormal = i;
          if (data[i + 11] < 0 || data[i + 11] > 17) invalidMaterial = i;
        }
        expect(
          invalidNormal,
          -1,
          reason: 'Non-unit normal at float offset $invalidNormal',
        );
        expect(
          invalidMaterial,
          -1,
          reason: 'Invalid material at float offset $invalidMaterial',
        );
      }
    },
  );
  test('Car winding agrees with normals, preventing inverted lighting', () {
    for (final car in cars) {
      final d = buildCarMesh(car).buffer;
      V3 p(int offset) => V3(d[offset], d[offset + 1], d[offset + 2]);
      for (var i = 0; i < d.length; i += 36) {
        final geometric = (p(i + 12) - p(i)).cross(p(i + 24) - p(i));
        if (geometric.length < 1e-6) continue;
        final normal = p(i + 3) + p(i + 15) + p(i + 27);
        expect(
          geometric.dot(normal),
          greaterThanOrEqualTo(-1e-5),
          reason: '${car.id}: triangle ${i ~/ 36}',
        );
      }
    }
  });
  test(
    'Camera and model packets remain finite throughout the vertical loop',
    () {
      final race = RaceEngine(track: tracks.first, car: cars.first);
      for (final f in tracks.first.frames) {
        race.player.distance = f.s;
        race.player.lane = .7;
        final data = raceGpuFrame(race);
        expect(data.every((v) => v.isFinite), isTrue);
        expect(data.length, 15 + data[14].toInt() * 17);
        final up = V3(data[6], data[7], data[8]);
        expect(up.dot(f.up), greaterThan(.999));
        expect(data[31], 1);
      }
    },
  );
  test(
    'GLES instance packets include shield, missiles, oil and turbo effects',
    () {
      final race = RaceEngine(track: tracks[2], car: cars[3]);
      race.countdown = 0;
      race.player.shield = 5;
      race.player.speed = 80;
      race.boosting = true;
      race.accelerating = true;
      race.projectiles.add(Projectile(20, 0));
      race.oil.add(OilPatch(-6, 0));
      final data = raceGpuFrame(race);
      final indices = [
        for (var i = 0; i < data[14].toInt(); i++) data[15 + i * 17].toInt(),
      ];
      expect(
        indices,
        containsAll([
          3,
          GpuMeshId.pickup,
          GpuMeshId.rocket,
          GpuMeshId.oil,
          GpuMeshId.shield,
          GpuMeshId.flame,
        ]),
      );
      expect(indices.every((i) => i < GpuResources.objects.length), isTrue);
      expect(indices.length, lessThanOrEqualTo(128));
    },
  );
}
