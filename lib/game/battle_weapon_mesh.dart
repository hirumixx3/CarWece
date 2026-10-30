part of 'gpu_frame.dart';

/// One authored attachment per collectible, using metal housings, bores,
/// fins, cartridges and colored emitters instead of a universal roof cannon.
Mesh3 buildBattleWeapon(BattlePower power) {
  final m = Mesh3(), color = battleWeapon(power).color;
  const steel = 0xff8fabb7, dark = 0xff263744, black = 0xff101820;
  void box(
    double x,
    double y,
    double z,
    double w,
    double h,
    double l, [
    int c = dark,
    int mat = Material3.metal,
  ]) => m.box(V3(x, y, z), V3(w, h, l), c, mat);
  void tube(
    V3 p,
    V3 axis,
    double l,
    double r, [
    int c = steel,
    int mat = Material3.metal,
    double? tip,
  ]) => m.cylinder(p, axis, l, r, tip ?? r, c, mat, segments: 12);
  void barrel(
    double x,
    double y,
    double z,
    double l,
    double r, [
    int c = steel,
  ]) {
    tube(V3(x, y, z), const V3(0, 0, 1), l, r, c);
    tube(V3(x, y, z + l / 2 + .012), const V3(0, 0, 1), .035, r * .70, black);
    tube(V3(x, y, z - l * .2), const V3(0, 0, 1), .13, r * 1.25, dark);
  }

  void lens(double x, double y, double z, double r) =>
      tube(V3(x, y, z), const V3(0, 0, 1), .12, r, color, Material3.glow);
  void missile(double x, double y, double z, [double size = 1]) {
    tube(V3(x, y, z), const V3(0, 0, 1), 1.7 * size, .2 * size, steel);
    tube(
      V3(x, y, z + 1.06 * size),
      const V3(0, 0, 1),
      .42 * size,
      .2 * size,
      color,
      Material3.paint,
      0,
    );
    for (final a in [0.0, math.pi / 2, math.pi, math.pi * 1.5]) {
      final r = V3(math.cos(a), math.sin(a), 0);
      m.triangle(
        V3(x, y, z - .75 * size),
        V3(x, y, z - .75 * size) + r * .44 * size,
        V3(x, y, z + .05 * size),
        dark,
        Material3.metal,
      );
    }
  }

  void coil(double x, double z, int rings, [double height = 1.2]) {
    tube(V3(x, height / 2, z), const V3(0, 1, 0), height, .12, dark);
    for (var i = 0; i < rings; i++)
      tube(
        V3(x, .2 + i * height / rings, z),
        const V3(0, 1, 0),
        .09,
        .38,
        color,
        Material3.metal,
      );
    tube(
      V3(x, height + .1, z),
      const V3(0, 1, 0),
      .22,
      .23,
      color,
      Material3.glow,
      .1,
    );
  }

  void tank(double x, double z, [int c = steel]) {
    tube(V3(x, .65, z), const V3(0, 1, 0), 1.1, .4, c);
    for (final y in [.25, 1.05])
      tube(V3(x, y, z), const V3(0, 1, 0), .09, .44, dark);
    tube(V3(x, 1.28, z), const V3(0, 1, 0), .18, .12, color);
  }

  void speaker(double x, double y, double z, double r) {
    barrel(x, y, z, .35, r, dark);
    lens(x, y, z + .2, r * .35);
  }

  void launcher(int count, [double width = 2.0]) {
    box(0, .35, .25, width + .4, .7, 1.8);
    for (var i = 0; i < count; i++)
      missile(
        (i - (count - 1) / 2) * width / math.max(1, count - 1),
        .72,
        .65,
        .8,
      );
  }

  void rack(int n, [bool spikes = false]) {
    box(0, .25, -.1, 2.1, .4, 1.5);
    for (var i = 0; i < n; i++) {
      final x = (i - (n - 1) / 2) * .62;
      tube(V3(x, .65, -.1), const V3(0, 1, 0), .35, .3, color);
      if (spikes)
        for (var j = 0; j < 4; j++) {
          final a = j * math.pi / 2;
          tube(
            V3(x + math.cos(a) * .25, .9, math.sin(a) * .25 - .1),
            const V3(0, 1, 0),
            .4,
            .07,
            steel,
            Material3.metal,
            0,
          );
        }
    }
  }

  // Common quick-release base is the only shared silhouette element.
  tube(const V3(0, .08, 0), const V3(0, 1, 0), .16, .7, dark);
  box(0, .15, -.25, 1.2, .18, 1.1, steel);
  switch (power) {
    case BattlePower.machineGun:
      box(0, .48, 0, .75, .65, 1.25);
      barrel(0, .62, 1.4, 2.3, .13);
      box(-.57, .44, -.15, .45, .65, .9, color);
      for (var i = 0; i < 6; i++)
        box(-.37 + i * .12, .63, -.35, .06, .1, .12, 0xffd8ae5b);
      break;
    case BattlePower.homingMissile:
      launcher(2, 1.25);
      lens(0, 1, .5, .15);
      break;
    case BattlePower.rocket:
      launcher(1, .7);
      barrel(0, .7, 1.5, 1.7, .38, dark);
      break;
    case BattlePower.mortar:
      box(0, .3, 0, 1.8, .4, 1.7);
      barrel(0, .75, 1.1, 1.55, .52);
      for (final x in [-.85, .85])
        tube(V3(x, .65, .3), const V3(1, 0, 0), .22, .35, color);
      break;
    case BattlePower.cannon:
      box(0, .6, .2, 1.55, .9, 1.6);
      barrel(0, .7, 1.65, 2.2, .26);
      box(0, .85, 1.65, .62, .4, .45, color);
      lens(.48, 1, .75, .09);
      break;
    case BattlePower.roadMine:
      rack(3);
      box(0, .15, -1.15, 1.9, .2, 1.1, steel);
      break;
    case BattlePower.ripperWheels:
      for (final x in [-.8, .8]) {
        tube(V3(x, .6, .2), const V3(1, 0, 0), .15, .65, steel);
        for (var j = 0; j < 8; j++) {
          final a = j * math.pi / 4;
          m.triangle(
            V3(x, .6 + math.cos(a) * .85, .2 + math.sin(a) * .85),
            V3(x, .6 + math.cos(a - .23) * .5, .2 + math.sin(a - .23) * .5),
            V3(x, .6 + math.cos(a + .23) * .5, .2 + math.sin(a + .23) * .5),
            color,
            Material3.metal,
          );
        }
      }
      break;
    case BattlePower.armorRepair:
      box(0, .65, 0, 1.8, 1.1, 1.4, 0xffe9eee2, Material3.paint);
      box(0, .69, .72, .32, .76, .04, color, Material3.glow);
      box(0, .69, .75, .92, .26, .04, color, Material3.glow);
      tank(-1, 0, color);
      break;
    case BattlePower.oilDrum:
      tank(-.5, -.1, 0xffa7683f);
      tank(.5, -.1, 0xffa7683f);
      barrel(0, .4, 1.15, 1.2, .28, dark);
      break;
    case BattlePower.laserCannon:
      box(0, .55, .6, 1, .85, 2.2);
      for (final x in [-.65, .65]) coil(x, 0, 4, .8);
      barrel(0, .55, 1.95, .7, .33);
      lens(0, .55, 2.34, .23);
      break;
    case BattlePower.sonicBoom:
      for (final x in [-.5, .5]) speaker(x, .7, .5, .58);
      box(0, .35, -.5, 1.8, .45, .7, color);
      break;
    case BattlePower.atomBlaster:
      box(0, .5, 0, 1.8, .7, 1.6);
      for (final x in [-.55, .55]) {
        barrel(x, .7, 1.4, 1.6, .24);
        lens(x, .7, 2.23, .15);
      }
      coil(0, -.5, 3, .9);
      break;
    case BattlePower.freonBomb:
      tank(-.6, -.25, 0xffd2f3ef);
      tank(.6, -.25, 0xffd2f3ef);
      barrel(0, .75, 1.3, 1.6, .48);
      lens(0, .75, 2.12, .3);
      break;
    case BattlePower.energyShield:
      for (final x in [-.85, .85]) {
        coil(x, 0, 3, 1.3);
        box(x, .7, .65, .24, 1.2, .55, color);
      }
      tube(
        const V3(0, .3, 0),
        const V3(0, 1, 0),
        .16,
        1.3,
        color,
        Material3.glow,
      );
      break;
    case BattlePower.jetBoosters:
      for (final x in [-.75, .75]) {
        barrel(x, .5, -.3, 2, .46);
        lens(x, .5, -1.32, .32);
      }
      box(0, .5, 0, .35, .7, 1.2, color);
      break;
    case BattlePower.superZapper:
      coil(0, .2, 7, 1.85);
      for (final x in [-.75, .75]) coil(x, -.35, 3, .8);
      break;
    case BattlePower.magnetMine:
      barrel(0, .6, 1.1, 1.5, .48);
      for (final x in [-.7, .7]) box(x, .8, 1.1, .3, 1.1, .65, color);
      box(0, .3, .8, 1.7, .3, .5, steel);
      break;
    case BattlePower.doomDisks:
      box(0, .3, .4, 1.9, .4, 2.1);
      for (var i = 0; i < 3; i++)
        tube(
          V3(0, .55 + i * .18, .6),
          const V3(0, 1, 0),
          .12,
          .85,
          i.isEven ? steel : color,
        );
      box(0, .7, 1.4, 1.9, .25, .3, dark);
      break;
    case BattlePower.quantumAnnihilator:
      box(0, .6, .4, 2.15, 1.05, 2.5, dark);
      barrel(0, .7, 2, 1.3, .62);
      lens(0, .7, 2.68, .43);
      for (final x in [-1.15, 1.15]) coil(x, -.2, 5, 1.25);
      break;
    case BattlePower.gridlock:
      for (var i = 0; i < 3; i++)
        for (var j = 0; j < 3; j++)
          barrel((i - 1) * .55, .35 + j * .45, .7, 1.7, .19);
      box(0, .6, -.4, 1.9, 1.35, .35, color);
      break;
    case BattlePower.whiteLightning:
      for (final x in [-.6, .6]) coil(x, .4, 6, 1.7);
      box(0, .3, -.5, 1.5, .4, .7, color);
      break;
    case BattlePower.tantrumGun:
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3;
        barrel(math.cos(a) * .32, .75 + math.sin(a) * .32, 1.2, 2.3, .105);
      }
      tube(const V3(0, .75, .15), const V3(0, 0, 1), .55, .61, color);
      tank(-1, -.3, dark);
      break;
    case BattlePower.bassQuake:
      box(0, .65, 0, 2.4, 1.25, 1.3, dark);
      for (final x in [-.65, .65]) speaker(x, .8, .8, .55);
      for (final z in [-.9, .9])
        tube(V3(0, .2, z), const V3(0, 1, 0), .2, .75, color);
      break;
    case BattlePower.invasion:
      tube(
        const V3(0, .7, 0),
        const V3(0, 1, 0),
        .35,
        1.25,
        steel,
        Material3.metal,
        .5,
      );
      tube(
        const V3(0, 1.05, 0),
        const V3(0, 1, 0),
        .4,
        .45,
        color,
        Material3.glow,
        .15,
      );
      for (var i = 0; i < 5; i++) {
        final a = i * math.pi * 2 / 5;
        lens(math.cos(a), .7, math.sin(a), .12);
      }
      break;
    case BattlePower.steelBelter:
      for (var i = 0; i < 3; i++) {
        tube(
          V3(0, .6, i * .45 - .4),
          const V3(0, 0, 1),
          .38,
          .65,
          black,
          Material3.rubber,
        );
        tube(V3(0, .6, i * .45 - .17), const V3(0, 0, 1), .04, .3, steel);
      }
      box(-.95, .4, .1, .2, .7, 1.9, color);
      box(.95, .4, .1, .2, .7, 1.9, color);
      break;
    case BattlePower.scatterMissiles:
      launcher(6, 2.5);
      break;
    case BattlePower.deathRay:
      barrel(0, .8, 1, 2.3, .35, dark);
      lens(0, .8, 2.18, .25);
      for (final x in [-.8, .8]) {
        box(x, .75, .55, .2, 1.2, 2.3, color);
        coil(x, -.7, 3, .7);
      }
      break;
    case BattlePower.discoInferno:
      tube(const V3(0, .8, 0), const V3(0, 1, 0), 1.4, .1, steel);
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        box(
          math.cos(a) * .55,
          1.45,
          math.sin(a) * .55,
          .38,
          .55,
          .38,
          i.isEven ? color : steel,
          Material3.metal,
        );
      }
      lens(0, 1.45, .82, .2);
      break;
    case BattlePower.gammaSwarm:
      for (var i = 0; i < 7; i++) {
        final a = i * 2.399;
        tube(
          V3(math.cos(a) * .65, .5 + (i % 3) * .24, math.sin(a) * .65),
          const V3(0, 1, 0),
          .65,
          .19,
          color,
          Material3.glow,
        );
      }
      box(0, .3, 0, 1.85, .3, 1.8, dark);
      break;
    case BattlePower.smogCheck:
      tank(-.55, 0, 0xff91a34d);
      tank(.55, 0, 0xff91a34d);
      for (final x in [-.55, .55]) {
        tube(V3(x, .9, -.8), const V3(0, 0, 1), 1.2, .16, dark);
      }
      break;
    case BattlePower.breathOfFire:
      tank(-.75, -.3, 0xffcb733b);
      tank(.75, -.3, 0xffcb733b);
      barrel(0, .65, 1.2, 2, .27);
      lens(0, .65, 2.23, .16);
      break;
    case BattlePower.alienLaser:
      tube(
        const V3(0, .5, .2),
        const V3(0, 0, 1),
        1.8,
        .7,
        dark,
        Material3.metal,
        .25,
      );
      for (final x in [-.6, .6]) {
        tube(
          V3(x, .65, .5),
          const V3(0, 0, 1),
          2.2,
          .12,
          color,
          Material3.glow,
        );
      }
      lens(0, .5, 1.3, .32);
      break;
    case BattlePower.haloDecoy:
      for (var i = 0; i < 12; i++) {
        final a = i * math.pi / 6;
        box(
          math.cos(a) * .9,
          .65,
          math.sin(a) * .9,
          .22,
          .3,
          .22,
          color,
          Material3.glow,
        );
      }
      tube(const V3(0, .3, 0), const V3(0, 1, 0), .3, .6, steel);
      break;
    case BattlePower.afterburner:
      barrel(0, .5, -.2, 2.2, .65, dark);
      lens(0, .5, -1.32, .48);
      for (final x in [-.85, .85]) box(x, .65, -.2, .22, .9, 1.6, color);
      break;
    case BattlePower.roadRunner:
      launcher(1, .5);
      for (final x in [-.6, .6]) box(x, .65, .6, .22, .9, 2, steel);
      lens(0, .72, 1.95, .16);
      break;
    case BattlePower.stampede:
      launcher(5, 2.2);
      box(0, 1.2, -.4, 2.6, .18, .7, color);
      break;
    case BattlePower.turtleTurnover:
      barrel(0, .7, 1.1, 1.5, .6);
      for (final x in [-.9, .9]) box(x, .5, .2, .3, .75, 1.65, color);
      tube(const V3(0, 1.1, -.5), const V3(0, 1, 0), .3, .5, steel);
      break;
    case BattlePower.craterMaker:
      barrel(0, .8, 1.05, 1.7, .7, dark);
      box(0, .3, -.2, 2.4, .4, 2.2, color);
      for (final x in [-1.0, 1.0]) tank(x, -.45, steel);
      break;
    case BattlePower.cowPuncher:
      barrel(0, .7, 1.1, 1.75, .32);
      box(0, .7, 2.1, 1.25, .7, .45, steel);
      for (final x in [-.7, .7]) box(x, .5, -.2, .2, .6, 1.7, color);
      break;
    case BattlePower.buckshot:
      for (final x in [-.38, .38]) barrel(x, .75, 1.2, 2.1, .25);
      box(0, .4, -.3, 1.65, .5, .95, color);
      break;
    case BattlePower.bearHug:
      rack(1);
      for (final x in [-.8, .8]) box(x, .6, .4, .25, .65, 1.6, steel);
      for (var i = 0; i < 5; i++)
        box((i - 2) * .35, 1, -.2, .16, .5, .25, color);
      break;
    case BattlePower.cactusPatch:
      rack(3, true);
      break;
    case BattlePower.radarJammer:
      tube(const V3(0, .8, 0), const V3(0, 1, 0), 1.4, .09, steel);
      box(0, 1.45, 0, 2.1, .15, .22, color);
      box(0, 1.75, 0, 1.2, .12, .22, steel);
      tank(.75, -.4, dark);
      break;
    case BattlePower.weaponUpgrade:
      box(0, .6, 0, 1.6, 1.05, 1.3, dark);
      for (final x in [-.85, .85]) coil(x, .2, 4, 1.1);
      lens(0, .7, .72, .36);
      box(0, 1.2, 0, .45, .18, 1, color, Material3.glow);
      break;
  }
  return m;
}
