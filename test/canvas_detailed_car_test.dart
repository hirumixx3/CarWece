import 'package:carwece/game/content.dart';
import 'package:carwece/game/gpu_mesh.dart';
import 'package:carwece/game/renderer.dart';
import 'package:flutter_test/flutter_test.dart';

double _minY(List<Face3> faces) => faces
    .expand((face) => face.vertices)
    .map((v) => v.y)
    .reduce((a, b) => a < b ? a : b);

double _maxY(List<Face3> faces) => faces
    .expand((face) => face.vertices)
    .map((v) => v.y)
    .reduce((a, b) => a > b ? a : b);

void main() {
  test('meshCarFaces reproduz corpo + rodas em detalhe total', () {
    final spec = cars[25];
    final faces = Scene3.meshCarFaces(spec, lift: .33);
    final expected =
        buildCarMesh(spec).triangles + buildWheelMesh(spec).triangles * 4;
    expect(faces.length, expected);
    for (final face in faces) {
      for (final v in face.vertices) {
        expect(v.x.isFinite && v.y.isFinite && v.z.isFinite, isTrue);
      }
    }
    // Wheel bottoms touch the ground; the body rides above them.
    expect(_minY(faces), closeTo(0, .02));
    expect(_maxY(faces), greaterThan(2.0));
  });

  test('clusterização corta triângulos sem desmontar o carro', () {
    final spec = cars[25];
    final full = Scene3.meshCarFaces(spec, lift: .12);
    final clustered = Scene3.meshCarFaces(spec, cell: .18, lift: .12);
    expect(clustered.length, lessThan(full.length * .6));
    expect(clustered.length, greaterThan(600));
    expect(_minY(clustered), lessThan(.25));
    expect(_maxY(clustered), greaterThan(_maxY(full) - .3));
  });

  test('carro brasileiro da Coleção Azul também converte', () {
    final spec = cars.firstWhere((c) => c.body == 100);
    final faces = Scene3.meshCarFaces(spec, cell: .18, lift: .12);
    expect(faces.length, greaterThan(600));
    expect(_minY(faces), lessThan(.25));
  });
}
