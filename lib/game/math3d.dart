import 'dart:math' as math;

class V3 {
  final double x, y, z;
  const V3(this.x, this.y, this.z);
  static const zero = V3(0, 0, 0);
  V3 operator +(V3 v) => V3(x + v.x, y + v.y, z + v.z);
  V3 operator -(V3 v) => V3(x - v.x, y - v.y, z - v.z);
  V3 operator *(double k) => V3(x * k, y * k, z * k);
  double dot(V3 v) => x * v.x + y * v.y + z * v.z;
  V3 cross(V3 v) => V3(y * v.z - z * v.y, z * v.x - x * v.z, x * v.y - y * v.x);
  double get length => math.sqrt(dot(this));
  V3 get unit {
    final magnitude = length;
    return magnitude < .00001 ? const V3(0, 0, 1) : this * (1 / magnitude);
  }

  V3 lerp(V3 b, double t) =>
      V3(x * (1 - t) + b.x * t, y * (1 - t) + b.y * t, z * (1 - t) + b.z * t);
  V3 rotate(V3 axis, double angle) {
    final c = math.cos(angle),
        s = math.sin(angle),
        projection = axis.dot(this) * (1 - c);
    return V3(
      x * c + (axis.y * z - axis.z * y) * s + axis.x * projection,
      y * c + (axis.z * x - axis.x * z) * s + axis.y * projection,
      z * c + (axis.x * y - axis.y * x) * s + axis.z * projection,
    );
  }
}

double wrap(double n, double max) => ((n % max) + max) % max;
double mix(double a, double b, double t) => a + (b - a) * t;

V3 catmull(V3 a, V3 b, V3 c, V3 d, double t) {
  final t2 = t * t, t3 = t2 * t;
  return (b * 2 +
          (c - a) * t +
          (a * 2 - b * 5 + c * 4 - d) * t2 +
          (b * 3 - a - c * 3 + d) * t3) *
      0.5;
}

/// Uniform cubic B-spline: rounds toy-track corners without spline overshoot.
V3 roadSpline(V3 a, V3 b, V3 c, V3 d, double t) {
  final t2 = t * t, t3 = t2 * t, u = 1 - t;
  return (a * (u * u * u) +
          b * (3 * t3 - 6 * t2 + 4) +
          c * (-3 * t3 + 3 * t2 + 3 * t + 1) +
          d * t3) *
      (1 / 6);
}
