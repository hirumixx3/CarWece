part of 'engine.dart';

/// Contacts use the visible ribbon and wedge faces. Proximity alone never
/// grants tire contact: a car must enter at grade or land on the upper face.
extension _SurfaceContacts on RaceEngine {
  double _bodyRadius(V3 axis, V3 forward, V3 right, V3 up) =>
      forward.dot(axis).abs() * Driver.halfLength +
      right.dot(axis).abs() * Driver.halfWidth +
      up.dot(axis).abs() * 1.4;

  (V3, V3) _roadCeilings(Driver d, V3 before, V3 next, V3 velocity) {
    if (identical(before, next) &&
        identical(d.ceilingCheckedPosition, next) &&
        identical(d.ceilingCheckedNormal, d.normal))
      return (next, velocity);
    final up = d.normal!, forward = d.forward!, right = up.cross(forward).unit;
    final support = track.project(before);
    final supported =
        !d.airborne &&
        !track.isFloor(support.frame.s) &&
        support.height.abs() < .3 &&
        support.lateral.abs() < track.width / 2 - .4 &&
        up.dot(support.frame.up) > .65;
    final half = V3(
      _bodyRadius(const V3(1, 0, 0), forward, right, up),
      _bodyRadius(const V3(0, 1, 0), forward, right, up),
      _bodyRadius(const V3(0, 0, 1), forward, right, up),
    );
    for (final tri in track.roadCollision.near(next)) {
      // The tires already own this local ribbon. Its tessellated inner edge
      // may fold in a tight wide turn; do not interpret that same contact as
      // a ceiling. Other branches and cars below the deck remain solid.
      final arc = (tri.s - support.frame.s).abs();
      if (supported && math.min(arc, track.length - arc) < 18) continue;
      final center = next + up * 1.4, old = before + up * 1.4, n = tri.normal;
      if (!tri.overlaps(center, half)) continue;
      final radius = _bodyRadius(n, forward, right, up);
      final oldCenter = (old - tri.a).dot(n), height = (center - tri.a).dot(n);
      final roof = height + radius;
      // A roof already in contact remains on the same side on later steps.
      if (oldCenter >= -.45 ||
          roof < -.46 ||
          !tri.containsBody(center, forward, right, up))
        continue;
      var push = n * -1;
      var depth = roof + .46;
      if (next.y + push.y * depth < TrackSpec.floorHeight + .001) {
        // The floor cannot be used to cancel a downward ceiling correction.
        // A descending ribbon becomes a real wall when there is no clearance.
        final horizontal = V3(push.x, 0, push.z), h = horizontal.length;
        if (h < .0001) {
          if (velocity.length > 3 && d.wallCooldown <= 0) {
            d.wallCooldown = .25;
            _effect(d, ImpactKind.sparks);
            if (d == player) {
              impact = .3;
              events.add('bump');
            }
          }
          next = before;
          velocity = V3.zero;
          continue;
        }
        push = horizontal * (1 / h);
        depth /= h;
      }
      next += push * (depth + .004);
      final into = velocity.dot(push);
      if (into < 0) velocity -= push * (into * 1.12);
      if (into < -3 && d.wallCooldown <= 0) {
        d.wallCooldown = .25;
        _effect(d, ImpactKind.sparks);
        if (d == player) {
          impact = .3;
          events.add('bump');
        }
      }
    }
    if (identical(before, next)) {
      d.ceilingCheckedPosition = next;
      d.ceilingCheckedNormal = up;
    }
    return (next, velocity);
  }

  (RoadTriangle, V3)? _landRoad(Driver d, V3 before, V3 next) {
    final up = d.normal!, forward = d.forward!, right = up.cross(forward).unit;
    final oldCenter = before + up * 1.4, center = next + up * 1.4;
    (RoadTriangle, V3)? hit;
    var best = double.infinity;
    for (final tri in track.roadCollision.near(next)) {
      final n = tri.normal;
      if (d.velocity.dot(n) >= -.001) continue;
      final tireFacing = n.y > .25 && up.dot(n) > .65;
      final radius = tireFacing
          ? up.dot(n) * 1.4
          : _bodyRadius(n, forward, right, up);
      final old = (oldCenter - tri.a).dot(n) - radius;
      final end = (center - tri.a).dot(n) - radius;
      if ((oldCenter - tri.a).dot(n) < -.05 || end > .02) continue;
      final t = (old / math.max(.000001, old - end)).clamp(0.0, 1.0);
      if (t >= best) continue;
      final at = oldCenter.lerp(center, t);
      if (tireFacing
          ? !tri.containsPoint(before.lerp(next, t))
          : !tri.containsBody(at, forward, right, up))
        continue;
      best = t;
      hit = (tri, next + n * (.008 - end));
    }
    return hit;
  }

  double _bodyExtent(Driver d, V3 axis) =>
      d.forward!.dot(axis).abs() * Driver.halfLength +
      d.normal!.cross(d.forward!).unit.dot(axis).abs() * Driver.halfWidth;

  (V3, V3) _roadShell(Driver d, V3 before, V3 next, V3 velocity) {
    final ceiling = _roadCeilings(d, before, next, velocity);
    next = ceiling.$1;
    velocity = ceiling.$2;
    final p = track.project(next), f = p.frame;
    if (track.isFloor(f.s)) return (next, velocity);
    final width = track.width / 2, extent = _bodyExtent(d, f.right) + .12;
    final height = p.height + d.jump * d.normal!.dot(f.up);
    final bodyHeight = 2.8 * d.normal!.dot(f.up).abs() + _bodyExtent(d, f.up);
    if (height > 1.12 || height + bodyHeight < -.45) return (next, velocity);
    final side = p.lateral >= 0 ? 1.0 : -1.0;
    if ((p.lateral.abs() - width).abs() > extent + .4) return (next, velocity);
    final oldLateral = (before - f.p).dot(f.right);
    final outside = oldLateral.abs() > width;
    final boundary = outside ? width + .2 + extent : width - .38 - extent;
    final penetration = outside
        ? boundary - p.lateral.abs()
        : p.lateral.abs() - boundary;
    if (penetration <= 0) return (next, velocity);
    final normal = f.right * side * (outside ? 1 : -1);
    next += normal * (penetration + .004);
    final into = velocity.dot(normal);
    if (into < 0) velocity -= normal * (into * 1.22);
    if (into < -3 && d.wallCooldown <= 0) {
      d.wallCooldown = .25;
      _effect(d, ImpactKind.sparks);
      if (d == player) {
        impact = .3;
        events.add('bump');
      }
    }
    return (next, velocity);
  }

  (V3, V3, bool) _rampMotion(
    Driver d,
    V3 before,
    V3 next,
    V3 velocity, {
    bool allowSupport = true,
  }) {
    for (final ramp in track.ramps) {
      final f = ramp.frame, delta = next - f.p, old = before - f.p;
      var x = delta.dot(f.right), z = delta.dot(f.forward);
      final oldX = old.dot(f.right), oldZ = old.dot(f.forward);
      final w = ramp.width / 2, l = ramp.length / 2;
      final rx = _bodyExtent(d, f.right) + .1;
      final rz = _bodyExtent(d, f.forward) + .1;
      final y = delta.dot(f.up) + d.jump;
      final top = ((z / ramp.length + .5).clamp(0, 1)) * ramp.height;
      final oldTop = ((oldZ / ramp.length + .5).clamp(0, 1)) * ramp.height;
      final normal = (f.up - f.forward * (ramp.height / ramp.length)).unit;
      final wasOn =
          d.activeRamp == ramp ||
          (oldX.abs() < w - .2 &&
              oldZ >= -l &&
              oldZ <= l &&
              (old.dot(f.up) - oldTop).abs() < .22 &&
              d.normal!.dot(normal) > .8);
      final entrance =
          oldZ <= -l + .4 &&
          z >= -l &&
          z <= -l + 2.2 &&
          oldX.abs() < w - rx &&
          old.dot(f.up).abs() < .45 &&
          velocity.dot(f.forward) > 0;
      if (allowSupport &&
          (wasOn || entrance) &&
          x.abs() < w - .15 &&
          z >= -l &&
          z <= l) {
        final limit = math.max(.2, w - rx - .25);
        if (x.abs() > limit) {
          final n = f.right * -x.sign;
          final into = velocity.dot(n);
          if (into < 0) velocity -= n * (into * 1.15);
          x = x.clamp(-limit, limit);
        }
        next = f.p + f.right * x + f.forward * z + f.up * top;
        _transport(d, normal);
        // Preserve speed when the wheels first climb the slope.
        velocity -= normal * velocity.dot(normal);
        d.activeRamp = ramp;
        return (next, velocity, true);
      }
      if (d.activeRamp == ramp) {
        d.activeRamp = null;
        if (z > l || x.abs() >= w) {
          d.airborne = true;
          d.contactCooldown = .12;
          d.fallTime = 0;
          if (d == player) {
            tell('SALTO!');
            events.add('jump');
          }
          return (next, velocity, false);
        }
      }
      // Wedge sides and the tall rear face block approaches from outside.
      if (!allowSupport &&
          old.dot(f.up) >= oldTop - .08 &&
          oldZ >= -l &&
          oldZ <= l &&
          oldX.abs() < w)
        continue;
      if (x.abs() >= w + rx ||
          z < -l ||
          z >= l + rz ||
          y >= top - .08 ||
          y + 2.8 < 0)
        continue;
      final sidePen = w + rx - x.abs(), rearPen = l + rz - z;
      V3 push;
      double depth;
      if (oldZ >= l || (oldX.abs() < w && rearPen < sidePen)) {
        push = f.forward;
        depth = rearPen;
      } else {
        push = f.right * (oldX >= 0 ? 1.0 : -1.0);
        depth = sidePen;
      }
      next += push * (depth + .004);
      final into = velocity.dot(push);
      if (into < 0) velocity -= push * (into * 1.22);
      if (into < -3 && d.wallCooldown <= 0) {
        d.wallCooldown = .25;
        _effect(d, ImpactKind.sparks);
        if (d == player) {
          impact = .3;
          events.add('bump');
        }
      }
    }
    return (next, velocity, false);
  }

  WorldRamp? _landRamp(Driver d, V3 before, V3 next) {
    if (d.contactCooldown > 0) return null;
    for (final r in track.ramps) {
      final f = r.frame, delta = next - f.p;
      final z = delta.dot(f.forward), x = delta.dot(f.right);
      if (z < -r.length / 2 || z > r.length / 2 || x.abs() > r.width / 2 - .5)
        continue;
      final n = (f.up - f.forward * (r.height / r.length)).unit;
      final surface =
          f.p +
          f.forward * z +
          f.right * x +
          f.up * ((z / r.length + .5) * r.height);
      if ((before - surface).dot(n) >= -.05 &&
          (next - surface).dot(n) <= .12 &&
          d.velocity.dot(n) < 0)
        return r;
    }
    return null;
  }
}
