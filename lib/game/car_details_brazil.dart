part of 'gpu_mesh.dart';

/// Original stylized miniature details for the Brazilian-market collection.
/// Factory logos and externally sourced meshes/textures are not used.
void buildBrazilCarDetails(Mesh3 m, CarSpec car) {
  final d = car.design, l = d.halfLength, w = d.halfWidth, c = car.color;
  const dark = 0xff18262d, chrome = 0xffc4ced0, white = 0xfff1eed6;
  void box(V3 p, V3 size, int color, [int material = Material3.paint]) =>
      m.roundedBox(p, size, .018, color, material);
  void lamp(double x, double y, bool rear, double radius, int color) =>
      m.cylinder(
        V3(x, y, rear ? -l - .045 : l + .045),
        const V3(0, 0, 1),
        .05,
        radius,
        radius,
        color,
        Material3.glow,
        segments: 20,
      );
  void grille(double width, double height, {bool chromeBars = false}) {
    box(V3(0, .91, l + .032), V3(width, height, .04), dark, Material3.rubber);
    for (var j = 0; j < 4; j++) {
      box(
        V3(0, .91 + (j - 1.5) * height / 4, l + .058),
        V3(width * .95, .018, .012),
        chromeBars ? chrome : 0xff53616a,
        Material3.metal,
      );
    }
  }

  void lamps({bool round = false, bool twin = false, double height = .21}) {
    for (final side in [-1.0, 1.0]) {
      if (round) {
        lamp(side * w * .65, 1.05, false, .19, white);
        if (twin) lamp(side * w * .36, 1.05, false, .17, white);
      } else {
        box(
          V3(side * w * .66, 1.06, l + .04),
          V3(w * .51, height, .05),
          white,
          Material3.glow,
        );
      }
      box(
        V3(side * w * .75, .82, l + .045),
        const V3(.22, .085, .055),
        0xffffb343,
        Material3.glow,
      );
      box(
        V3(side * w * .67, 1.02, -l - .045),
        V3(w * .48, .20, .05),
        0xffd33135,
        Material3.glow,
      );
      box(
        V3(side * w * .67, 1.09, -l - .073),
        V3(w * .45, .045, .015),
        0xffec9e40,
        Material3.glow,
      );
    }
  }

  // Bumpers and plate recess: each silhouette is independent of car paint.
  for (final side in [-1.0, 1.0]) {
    box(
      V3(0, .62, side * (l + .06)),
      V3(w * 1.82, .12, .19),
      [
            'br_fusca',
            'br_brasilia',
            'br_opala',
            'br_chevette',
            'br_corcel',
            'br_delrey',
            'br_sp2',
            'br_kombi',
            'br_karmann',
            'br_chambord',
            'br_fissore',
            'br_fnm',
            'br_aero',
          ].contains(car.id)
          ? chrome
          : dark,
      Material3.metal,
    );
    box(
      V3(0, .86, side * (l + .061)),
      const V3(.56, .17, .035),
      0xffd7dfd6,
      Material3.paint,
    );
  }
  switch (car.id) {
    case 'br_fusca':
      // Four rounded fenders and compound curved cabin, not a sedan repaint.
      for (final side in [-1.0, 1.0]) {
        for (final z in [d.frontAxle, d.rearAxle]) {
          _worldEllipsoid(
            m,
            V3(side * w * .80, 1.02, z),
            const V3(.43, .40, .97),
            c,
            segments: 14,
          );
        }
        m.cylinder(
          V3(side * w * .76, 1.29, l - .21),
          const V3(0, .22, 1).unit,
          .10,
          .25,
          .25,
          chrome,
          Material3.metal,
          segments: 20,
        );
        m.cylinder(
          V3(side * w * .76, 1.29, l - .15),
          const V3(0, .22, 1).unit,
          .09,
          .21,
          .21,
          white,
          Material3.glow,
          segments: 20,
        );
        box(
          V3(side * (w + .02), .56, -.05),
          const V3(.24, .10, 2.45),
          dark,
          Material3.rubber,
        );
        lamp(side * w * .73, .92, true, .15, 0xffdd342d);
        box(
          V3(side * w * .70, 1.58, l - .77),
          const V3(.20, .09, .26),
          0xffedb549,
          Material3.glow,
        );
      }
      for (var j = 0; j < 7; j++) {
        box(
          V3(0, d.belt + .01, -l + .30 + j * .11),
          const V3(.82, .02, .035),
          dark,
        );
      }
      box(
        V3(0, d.belt + .015, 2.18),
        const V3(.035, .035, 1.38),
        chrome,
        Material3.metal,
      );
    case 'br_gurgel':
      grille(1.50, .35);
      lamps(round: true);
      for (final side in [-1.0, 1.0]) {
        box(V3(side * w * .82, 1.75, -.85), const V3(.08, 1.12, .10), dark);
        box(
          V3(side * w * .91, .67, .1),
          const V3(.28, .18, 2.40),
          dark,
          Material3.rubber,
        );
      }
      m.cylinder(
        V3(0, 1.17, -l - .33),
        const V3(0, 0, 1),
        .41,
        .68,
        .68,
        dark,
        Material3.rubber,
        segments: 24,
      );
      m.cylinder(
        V3(0, 1.17, -l - .55),
        const V3(0, 0, 1),
        .04,
        .38,
        .38,
        chrome,
        Material3.metal,
        segments: 18,
      );
    case 'br_saveiro':
      grille(1.55, .23);
      lamps();
      // Visible recessed bed, side lips and transverse ribs.
      box(
        V3(0, d.belt + .018, -1.75),
        V3(w * 1.52, .05, 2.02),
        dark,
        Material3.rubber,
      );
      for (final side in [-1.0, 1.0])
        box(
          V3(side * w * .88, d.belt + .13, -1.75),
          const V3(.14, .24, 2.08),
          c,
        );
      for (var j = 0; j < 7; j++)
        box(
          V3(0, d.belt + .052, -2.61 + j * .27),
          V3(w * 1.43, .035, .035),
          0xff708084,
          Material3.metal,
        );
      box(V3(0, 1.08, -l - .08), V3(w * 1.6, .12, .03), c);
    case 'br_sp2':
      grille(1.0, .15);
      lamps(round: true, twin: true);
      for (final side in [-1.0, 1.0])
        box(V3(side * (w + .02), .70, 0), const V3(.04, .12, 4.8), 0xffd53e30);
    case 'br_puma_gte':
      lamps(round: true);
      grille(1.40, .16);
      for (final side in [-1.0, 1.0])
        box(
          V3(side * w * .63, d.belt + .13, l - .48),
          const V3(.50, .20, .59),
          c,
        );
    case 'br_puma_gtb':
      grille(1.48, .23);
      lamps(round: true, twin: true);
      for (var j = 0; j < 5; j++)
        box(
          V3(0, d.belt + .04, l - .58 - j * .14),
          const V3(1.13, .025, .06),
          dark,
        );
      box(
        V3(0, 1.02, -l - .07),
        V3(w * 1.74, .11, .05),
        0xffcc3033,
        Material3.glow,
      );
    case 'br_miura':
      grille(1.25, .17);
      lamps(height: .11);
      for (final side in [-1.0, 1.0]) {
        box(
          V3(side * w * .58, d.belt + .18, l - .52),
          const V3(.59, .28, .55),
          c,
        );
        box(
          V3(side * w * .58, d.belt + .19, l - .23),
          const V3(.45, .14, .04),
          white,
          Material3.glow,
        );
        box(V3(side * (w + .015), 1.0, -.9), const V3(.04, .25, .64), dark);
      }
    case 'br_opala' || 'br_maverick':
      grille(1.65, .29, chromeBars: true);
      lamps(round: true, twin: car.id == 'br_opala');
      for (final side in [-1.0, 1.0]) {
        box(
          V3(side * .47, d.belt + .035, l - 1.00),
          const V3(.35, .05, 1.70),
          dark,
        );
        box(V3(side * (w + .025), .77, -.20), const V3(.04, .17, 3.90), dark);
      }
    case 'br_brasilia':
      grille(1.15, .13);
      lamps(round: true, twin: true);
      for (var j = 0; j < 5; j++)
        box(
          V3(0, d.belt + .025, -l + .28 + j * .11),
          const V3(1.64, .025, .035),
          dark,
        );
    case 'br_chevette':
      grille(1.53, .24, chromeBars: true);
      lamps(round: true);
    case 'br_fiat147':
      grille(1.49, .26);
      lamps(height: .25);
    case 'br_uno':
      grille(1.40, .24);
      lamps(height: .27);
      box(V3(0, .48, l + .07), const V3(1.81, .13, .13), c);
      box(V3(0, d.belt + .15, -l + .22), V3(w * 1.72, .11, .38), dark);
    case 'br_gol_gti' || 'br_kadett' || 'br_escort':
      grille(1.48, .19);
      lamps(height: car.id == 'br_escort' ? .19 : .24);
      box(V3(0, d.belt + .18, -l + .23), V3(w * 1.70, .10, .35), dark);
      for (final side in [-1.0, 1.0]) {
        box(
          V3(side * w * .58, .59, l + .07),
          const V3(.37, .15, .06),
          white,
          Material3.glow,
        );
        box(
          V3(side * (w + .02), .64, .05),
          const V3(.05, .08, 3.7),
          0xffbd2e32,
        );
      }
    case 'br_palio':
      grille(.95, .15);
      lamps(height: .24);
      for (final side in [-1.0, 1.0])
        box(
          V3(side * w * .69, 1.16, -l - .04),
          const V3(.22, .46, .07),
          0xffd92d38,
          Material3.glow,
        );
    case 'br_parati':
      grille(1.51, .23);
      lamps();
      for (final side in [-1.0, 1.0])
        box(
          V3(side * w * .56, d.roof + .16, -.66),
          const V3(.06, .07, 2.08),
          dark,
          Material3.rubber,
        );
    case 'br_kombi':
      // Tall van: full-height window band, sliding-door seam, round lamps.
      lamps(round: true);
      grille(.8, .14, chromeBars: true);
      for (final side in [-1.0, 1.0]) {
        box(
          V3(side * (w + .02), d.roof - .42, -.2),
          V3(.04, .62, l * 1.45),
          dark,
          Material3.glass,
        );
        box(
          V3(side * (w + .03), 1.32, .42),
          const V3(.02, 1.5, .03),
          dark,
          Material3.rubber,
        );
      }
    case 'br_troller':
      // Raised 4x4: rear spare wheel, roll bars and roof lamps.
      lamps(height: .2);
      grille(1.2, .26);
      m.cylinder(
        V3(0, 1.62, -l - .18),
        const V3(0, 0, 1),
        .34,
        .62,
        .62,
        dark,
        Material3.rubber,
        segments: 20,
      );
      for (final side in [-1.0, 1.0]) {
        box(
          V3(side * w * .8, d.roof + .1, .3),
          const V3(.07, .2, 1.9),
          dark,
          Material3.metal,
        );
        box(
          V3(side * w * .55, d.roof + .3, 1.15),
          const V3(.2, .12, .06),
          white,
          Material3.glow,
        );
      }
    case 'br_emis':
      // Open buggy: roll hoop, exposed rear deck and round lamps.
      lamps(round: true);
      for (final side in [-1.0, 1.0])
        box(
          V3(side * w * .62, d.roof + .28, -.55),
          const V3(.08, .62, .08),
          dark,
          Material3.metal,
        );
      box(
        V3(0, d.roof + .6, -.55),
        V3(w * 1.24, .08, .08),
        dark,
        Material3.metal,
      );
      box(V3(0, .98, -l - .02), V3(w * 1.5, .3, .06), dark, Material3.rubber);
    case 'br_karmann' || 'br_interlagos' || 'br_chambord':
      lamps(round: true, twin: car.id != 'br_interlagos');
      grille(1.05, .18, chromeBars: true);
    case 'br_hofstetter':
      // Low wedge: slim intake, flush lamps and rear louvres.
      lamps(height: .15);
      box(V3(0, .68, l + .03), V3(w * 1.5, .12, .04), dark, Material3.rubber);
      for (var i = 0; i < 5; i++) {
        box(
          V3(0, 1.34 + i * .07, -1.15 + i * .16),
          V3(w * 1.15, .03, .07),
          dark,
          Material3.rubber,
        );
      }
    case 'br_caravan' || 'br_variant':
      grille(1.45, .22, chromeBars: car.id == 'br_caravan');
      lamps();
      for (final side in [-1.0, 1.0])
        box(
          V3(side * w * .56, d.roof + .15, -.6),
          const V3(.06, .07, 2.1),
          dark,
          Material3.rubber,
        );
    case 'br_uirapuru' || 'br_santa_matilde' || 'br_miura_saga' || 'br_adamo':
      lamps(round: car.id == 'br_uirapuru', height: .19);
      grille(1.1, .16);
      box(
        V3(0, d.belt + .34, -l + .3),
        V3(w * 1.55, .07, .34),
        dark,
        Material3.rubber,
      );
    case 'br_br800' || 'br_supermini':
      lamps(round: true);
      grille(.7, .12);
    default:
      grille(
        car.id == 'br_omega' ? 1.19 : 1.51,
        .22,
        chromeBars: ['br_santana', 'br_delrey', 'br_corcel'].contains(car.id),
      );
      lamps(height: ['br_marea', 'br_tempra'].contains(car.id) ? .18 : .23);
      if (car.id == 'br_monza')
        box(V3(0, d.belt + .16, -l + .24), V3(w * 1.72, .10, .36), c);
      if (['br_tempra', 'br_marea', 'br_omega'].contains(car.id)) {
        for (final side in [-1.0, 1.0])
          box(
            V3(side * w * .58, .56, l + .06),
            const V3(.32, .12, .05),
            white,
            Material3.glow,
          );
      }
  }
}
