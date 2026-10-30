import 'dart:math' as math;
import 'dart:ui';

const hudLabels = <String, String>{
  'position': 'Posição',
  'lap': 'Volta',
  'clock': 'Tempo',
  'pause': 'Pausa',
  'title': 'Circuito',
  'map': 'Minimapa',
  'guide': 'Checkpoint e reposição',
  'speed': 'Velocímetro e turbo',
  'left': 'Esquerda',
  'right': 'Direita',
  'brake': 'Freio',
  'gas': 'Acelerador',
  'drift': 'Drift',
  'boost': 'Turbo',
  'item': 'Item',
  'super': 'Supercarga',
  'target': 'Trocar mira (batalha)',
};

/// Fraction of the available travel area, plus a uniform size multiplier.
/// A saved layout fits a different landscape screen without losing its buttons.
class HudPlacement {
  final double x, y, scale;
  const HudPlacement(this.x, this.y, this.scale);
  Map<String, double> toJson() => {'x': x, 'y': y, 'scale': scale};
}

class HudLayout {
  final Map<String, HudPlacement> items;
  HudLayout([Map<String, HudPlacement>? items]) : items = {...?items};
  HudLayout copy() => HudLayout(items);
  Map<String, Object> toJson() => {
    for (final e in items.entries) e.key: e.value.toJson(),
  };
  factory HudLayout.restore(Object? data) {
    final layout = HudLayout();
    if (data is! Map) return layout;
    for (final id in hudLabels.keys) {
      final row = data[id];
      if (row is! Map) continue;
      final x = row['x'], y = row['y'], scale = row['scale'];
      if (x is! num ||
          y is! num ||
          scale is! num ||
          !x.isFinite ||
          !y.isFinite ||
          !scale.isFinite)
        continue;
      layout.items[id] = HudPlacement(
        x.toDouble().clamp(0, 1),
        y.toDouble().clamp(0, 1),
        scale.toDouble().clamp(.65, 1.8),
      );
    }
    return layout;
  }

  static Rect defaultRect(String id, Size screen, double s) {
    final p = 18 * s, w = screen.width, h = screen.height;
    Rect r(double x, double y, double width, double height) =>
        Rect.fromLTWH(x, y, width * s, height * s);
    return switch (id) {
      'position' => r(p, p, 86, 70),
      'lap' => r(p + 95 * s, p, 80, 62),
      'clock' => r(w - p - 166 * s, p, 110, 62),
      'pause' => r(w - p - 46 * s, p, 46, 56),
      'title' => Rect.fromLTWH(
        math.min(250 * s, w * .34),
        p + 8 * s,
        math.max(80 * s, w - 500 * s),
        58 * s,
      ),
      'map' => r(p + 3 * s, 100 * s, 120, 107),
      'guide' => r(p, 212 * s, 158, 116),
      'speed' => r((w - 164 * s) / 2, h - p - 94 * s, 164, 90),
      'left' => r(p, h - p - 76 * s, 76, 76),
      'right' => r(p + 86 * s, h - p - 76 * s, 76, 76),
      'brake' => r(p + 175 * s, h - p - 62 * s, 64, 62),
      'gas' => r(w - p - 112 * s, h - p - 94 * s, 112, 94),
      'drift' => r(w - p - 112 * s, h - p - 160 * s, 112, 59),
      'boost' => r(w - p - 200 * s, h - p - 76 * s, 76, 76),
      'item' => r(w - p - 279 * s, h - p - 70 * s, 70, 70),
      'super' => r(w - p - 279 * s, h - p - 107 * s, 70, 30),
      'target' => r(w - p - 279 * s, h - p - 169 * s, 70, 54),
      _ => throw ArgumentError.value(id, 'id'),
    };
  }

  Rect rect(String id, Size screen, double s) {
    final base = defaultRect(id, screen, s), custom = items[id];
    final zoom = custom?.scale ?? 1;
    final fit = math
        .min(
          zoom,
          math.min(
            (screen.width - 4) / base.width,
            (screen.height - 4) / base.height,
          ),
        )
        .clamp(.01, 1.8);
    final width = base.width * fit, height = base.height * fit;
    final maxX = math.max(0.0, screen.width - width),
        maxY = math.max(0.0, screen.height - height);
    return Rect.fromLTWH(
      custom == null ? base.left.clamp(0, maxX) : custom.x * maxX,
      custom == null ? base.top.clamp(0, maxY) : custom.y * maxY,
      width,
      height,
    );
  }

  void move(String id, Offset delta, Size screen, double s) {
    final r = rect(id, screen, s), current = items[id];
    final maxX = math.max(0.0, screen.width - r.width),
        maxY = math.max(0.0, screen.height - r.height);
    items[id] = HudPlacement(
      maxX == 0 ? 0 : (r.left + delta.dx).clamp(0, maxX) / maxX,
      maxY == 0 ? 0 : (r.top + delta.dy).clamp(0, maxY) / maxY,
      current?.scale ?? 1,
    );
  }

  void resize(String id, double scale, Size screen, double s) {
    if (!scale.isFinite) return;
    if (!items.containsKey(id)) move(id, Offset.zero, screen, s);
    final old = items[id]!;
    items[id] = HudPlacement(old.x, old.y, scale.clamp(.65, 1.8));
  }
}
