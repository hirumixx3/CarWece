part of 'gpu_mesh.dart';

/// Additional room layouts use the existing safe RoomProp catalogue instead of
/// forcing the old fixed bed/tub/cabinets through a newly authored circuit.
void buildBrazilIndoorWorld(Mesh3 m, TrackSpec track) {
  final material = track.tiled
      ? Material3.tile
      : ['QUARTO', 'SALA'].contains(track.room)
      ? Material3.wood
      : track.room == 'GARAGEM'
      ? Material3.concrete
      : Material3.wall;
  m.box(const V3(0, -1, 0), const V3(1800, 2, 1800), track.floor, material);
  for (final side in [-1.0, 1.0]) {
    m.box(
      V3(side * 880, 110, 0),
      const V3(5, 220, 1760),
      track.wall,
      Material3.wall,
    );
    m.box(
      V3(0, 110, side * 880),
      const V3(1760, 220, 5),
      track.wall,
      Material3.wall,
    );
    m.box(
      V3(side * 876, 4, 0),
      const V3(3, 8, 1750),
      0xffe1d0ae,
      Material3.wood,
    );
    m.box(
      V3(0, 4, side * 876),
      const V3(1750, 8, 3),
      0xffe1d0ae,
      Material3.wood,
    );
  }
  buildRoomProps(m, track);
  buildCourseObjects(m, track);
  for (final o in track.scenery) {
    m.roundedBox(
      o.center,
      o.size,
      1,
      o.color,
      track.tiled ? Material3.plastic : Material3.wood,
    );
  }
}
