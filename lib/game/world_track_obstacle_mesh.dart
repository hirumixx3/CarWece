part of 'gpu_mesh.dart';

final _expansionObstaclePrototypes = <String, Mesh3>{};

/// Reuse the authored diorama toys at racing-obstacle scale. Fit the actual
/// sculpted bounds, not assumed radii: small cacti/dinosaurs have fixed-width
/// details in their canonical mesh. Inverse-scale normals preserve lighting.
void buildExpansionTrackObstacleMesh(Mesh3 m, ExpansionTrackObstacle obstacle) {
  final prop = obstacle.prop;
  final source = _expansionObstaclePrototypes.putIfAbsent(prop.kind, () {
    final mesh = Mesh3();
    _buildExpansionObstaclePrototype(mesh, prop.kind);
    return mesh;
  }).data;
  final minimum = [double.infinity, double.infinity, double.infinity];
  final maximum = [-double.infinity, -double.infinity, -double.infinity];
  for (var i = 0; i < source.length; i += 12) {
    for (var axis = 0; axis < 3; axis++) {
      minimum[axis] = math.min(minimum[axis], source[i + axis]);
      maximum[axis] = math.max(maximum[axis], source[i + axis]);
    }
  }
  final sizes = [prop.size.x, prop.size.y, prop.size.z];
  final center = [prop.center.x, prop.center.y, prop.center.z];
  final scale = List.generate(
    3,
    (i) => sizes[i] / math.max(.001, maximum[i] - minimum[i]),
  );
  for (var i = 0; i < source.length; i += 12) {
    final n = V3(
      source[i + 3] / scale[0],
      source[i + 4] / scale[1],
      source[i + 5] / scale[2],
    ).unit;
    m.data.addAll([
      for (var axis = 0; axis < 3; axis++)
        center[axis] +
            (source[i + axis] - (minimum[axis] + maximum[axis]) / 2) *
                scale[axis],
      n.x,
      n.y,
      n.z,
      ...source.getRange(i + 6, i + 12),
    ]);
  }
}

void _buildExpansionObstaclePrototype(Mesh3 m, String kind) {
  const up = V3(0, 1, 0), bark = 0xff795338, cut = 0xffd9b575;
  void branch(
    V3 a,
    V3 b,
    double radius,
    int color, [
    int material = Material3.plastic,
  ]) {
    final d = b - a;
    m.cylinder(
      (a + b) * .5,
      d.unit,
      d.length,
      radius,
      radius * .72,
      color,
      material,
      segments: 10,
    );
  }

  switch (kind) {
    case 'stump':
      m.cylinder(V3.zero, up, 25, 16, 13, bark, Material3.wood, segments: 12);
      m.cylinder(
        const V3(0, 12.6, 0),
        up,
        .4,
        12,
        12,
        cut,
        Material3.wood,
        segments: 16,
      );
      for (final r in [4.0, 8.0]) {
        for (var i = 0; i < 16; i++) {
          final a = i * math.pi / 8, b = (i + 1) * math.pi / 8;
          branch(
            V3(math.cos(a) * r, 12.9, math.sin(a) * r),
            V3(math.cos(b) * r, 12.9, math.sin(b) * r),
            .3,
            bark,
            Material3.wood,
          );
        }
      }
      for (var i = 0; i < 5; i++) {
        final a = i * math.pi * 2 / 5;
        branch(
          const V3(0, -6, 0),
          V3(math.cos(a) * 20, -12, math.sin(a) * 20),
          4,
          bark,
          Material3.wood,
        );
      }
      // Shelf mushrooms and a green sprout sell the scale of the stump.
      for (var i = 0; i < 3; i++) {
        final a = i * 2.2 + .6;
        _worldEllipsoid(
          m,
          V3(math.cos(a) * 15.5, -2 + i * 3.0, math.sin(a) * 15.5),
          const V3(3.4, 1.1, 3.4),
          0xffe8734a,
          segments: 8,
        );
      }
      branch(
        const V3(3, 12.6, 2),
        const V3(4.5, 19, 3),
        .8,
        0xff5d8a4a,
        Material3.plastic,
      );
      _worldEllipsoid(
        m,
        const V3(4.5, 19.6, 3),
        const V3(3.2, 1.6, 3.2),
        0xff6fa855,
        segments: 8,
      );
    case 'fossil':
      _worldEllipsoid(
        m,
        const V3(0, -3, 0),
        const V3(23, 8, 18),
        0xff9b805d,
        segments: 10,
      );
      branch(const V3(-15, 5, 0), const V3(15, 5, 0), 1.8, 0xffe8d6aa);
      for (var i = -2; i <= 2; i++) {
        for (final sign in [-1.0, 1.0]) {
          branch(
            V3(i * 5.0, 5, 0),
            V3(i * 5.0 + 2, 7, sign * 10),
            1.2,
            0xffe8d6aa,
          );
        }
      }
      _worldEllipsoid(
        m,
        const V3(16, 5, 0),
        const V3(5, 4, 5),
        0xffe8d6aa,
        segments: 10,
      );
      // Tail vertebrae trailing away from the ribcage.
      for (var i = 0; i < 4; i++) {
        _worldEllipsoid(
          m,
          V3(-19 - i * 4.5, 1.5 - i * .5, i.isEven ? 1.5 : -1.5),
          V3(3.4 - i * .5, 2.4 - i * .3, 3.4 - i * .5),
          0xffe8d6aa,
          segments: 8,
        );
      }
    case 'dune':
      _worldEllipsoid(
        m,
        const V3(0, -4, 0),
        const V3(25, 11, 19),
        0xffc49452,
        segments: 10,
      );
      _worldEllipsoid(
        m,
        const V3(-5, 2, 0),
        const V3(16, 8, 14),
        0xffe2b86e,
        segments: 10,
      );
      // Wind-scattered stones and a dry shrub on the crest.
      for (var i = 0; i < 4; i++) {
        _worldEllipsoid(
          m,
          V3(-14 + i * 8.0, -1 + (i % 2), 8 - i * 4.0),
          const V3(2.2, 1.4, 2),
          0xff8a6f4d,
          segments: 7,
        );
      }
      for (var i = 0; i < 4; i++) {
        final a = i * 1.7 + .5;
        branch(
          const V3(9, 6, -6),
          V3(9 + math.cos(a) * 6, 13 + (i % 2) * 2.0, -6 + math.sin(a) * 6),
          .7,
          0xff7a6a42,
          Material3.wood,
        );
      }
    case 'snowball':
      _worldEllipsoid(
        m,
        V3.zero,
        const V3(18, 17, 18),
        0xffecf7ff,
        segments: 12,
      );
      _worldEllipsoid(
        m,
        const V3(13, -8, 9),
        const V3(8, 7, 8),
        0xfff4fbff,
        segments: 10,
      );
      _worldEllipsoid(
        m,
        const V3(-12, -10, -8),
        const V3(6, 5, 6),
        0xffe2f1fa,
        segments: 10,
      );
      _worldEllipsoid(
        m,
        const V3(3, -11, -4),
        const V3(18, 5, 15),
        0xffc3dfe9,
        segments: 10,
      );
    case 'coral':
      _worldEllipsoid(
        m,
        const V3(0, -12, 0),
        const V3(18, 5, 14),
        0xffa58d69,
        segments: 10,
      );
      for (var i = 0; i < 5; i++) {
        final x = (i - 2) * 5.0, z = i.isEven ? -5.0 : 5.0;
        branch(
          V3(x, -10, z),
          V3(x * 1.2, 10 + i % 3 * 4.0, z),
          2.3,
          0xffdf806a,
        );
        branch(V3(x, 1, z), V3(x + 7, 8, z + 3), 1.7, 0xffefaf81);
      }
      // Flat fan corals between the branches.
      for (var i = 0; i < 3; i++) {
        _worldEllipsoid(
          m,
          V3((i - 1) * 8.0, 2 + i * 2.0, i.isEven ? 7.0 : -7.0),
          const V3(5.5, 7, 1.2),
          0xfff2a65a,
          segments: 9,
        );
      }
    case 'driftwood':
      m.cylinder(
        V3.zero,
        const V3(1, 0, 0),
        48,
        8,
        6,
        0xffae9971,
        Material3.wood,
        segments: 12,
      );
      branch(
        const V3(-5, 2, 0),
        const V3(-15, 9, 10),
        3.5,
        0xffae9971,
        Material3.wood,
      );
      branch(
        const V3(12, 0, 0),
        const V3(19, 5, -11),
        2.5,
        0xffc8b38b,
        Material3.wood,
      );
      // Broken twig stubs along the trunk.
      for (var i = 0; i < 3; i++) {
        branch(
          V3(-14 + i * 13.0, 3, 4),
          V3(-16 + i * 13.0, 8, 9),
          1.4,
          0xffc8b38b,
          Material3.wood,
        );
      }
    default:
      buildExpansionPropMesh(
        m,
        RoomProp(
          kind,
          V3.zero,
          expansionObstaclePrototypeSize(kind),
          0xff87a06a,
        ),
      );
  }
}
