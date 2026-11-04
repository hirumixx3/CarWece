part of 'engine.dart';

class Mine {
  final V3 position;
  final Driver owner;
  double life = 14, arm = .65;
  Mine(this.position, this.owner);
}

class SmokeCloud {
  static const duration = 3.5;
  final V3 position;
  final Driver owner;
  double life = duration;
  SmokeCloud(this.position, this.owner);
  V3 get center => position + V3(0, (duration - life) * 1.2, 0);
  double get radius => 2 + math.sin(life) * .9;

  /// The same sphere is drawn by the renderer and sampled for visibility.
  /// No timer remains on a driver after leaving this volume.
  double densityAt(V3 point) {
    if (life <= 0) return 0;
    final distance = (point - center).length;
    if (distance >= radius) return 0;
    return ((radius - distance) / (radius * .55)).clamp(0.0, 1.0) *
        math.min(1.0, life / .45);
  }
}

class ElectricBeam {
  final V3 from, to;
  double life = .30;
  ElectricBeam(this.from, this.to);
}

class SpikeStrip {
  final TrackFrame frame;
  final Driver owner;
  final bool enhanced;
  double life = 12, arm = .5;
  SpikeStrip(this.frame, this.owner, this.enhanced);
}

extension CombatRules on RaceEngine {
  int initialCharges(ItemType type, bool enhanced) => switch (type) {
    ItemType.missile || ItemType.ice => 3,
    ItemType.salvo => enhanced ? 3 : 2,
    ItemType.propulsor => 2,
    ItemType.grenade => enhanced ? 3 : 2,
    ItemType.spikes => enhanced ? 2 : 1,
    ItemType.mine || ItemType.nitro => enhanced ? 3 : 1,
    _ => 1,
  };
  void giveItem(ItemType type, {bool enhanced = false}) {
    item = type;
    itemEnhanced = enhanced;
    itemCharges = initialCharges(type, enhanced);
  }

  ItemType rollItem() {
    if (itemBag.isEmpty) {
      itemBag.addAll(ItemType.values);
      itemBag.shuffle(random);
      if (itemHistory.isNotEmpty && itemBag.first == itemHistory.last) {
        final first = itemBag.removeAt(0);
        itemBag.add(first);
      }
    }
    // Two different choices favor catch-up tools behind, defenses at the front.
    var index = 0;
    if (itemBag.length > 1 && position >= 4) {
      final alternate = itemBag.indexWhere(
        (k) => [
          ItemType.missile,
          ItemType.nitro,
          ItemType.ice,
          ItemType.emp,
        ].contains(k),
      );
      if (alternate >= 0 && random.nextBool()) index = alternate;
    }
    if (itemHistory.isNotEmpty &&
        itemBag[index] == itemHistory.last &&
        itemBag.length > 1)
      index = (index + 1) % itemBag.length;
    final next = itemBag.removeAt(index);
    itemHistory.add(next);
    if (itemHistory.length > 32) itemHistory.removeAt(0);
    return next;
  }

  bool superchargeItem() {
    if (remoteAction != null) {
      remoteAction!('super');
      return true;
    }
    if (item == null ||
        itemEnhanced ||
        nitro < 100 ||
        paused ||
        finished ||
        countdown > 0)
      return false;
    nitro = 0;
    itemEnhanced = true;
    itemCharges = math.max(itemCharges, initialCharges(item!, true));
    tell('SUPER ${itemName(item!)}!');
    events.add('boost');
    return true;
  }

  Driver? _targetOf(Driver owner, double range) {
    for (final d in drivers) _ensure(d);
    final candidates =
        drivers
            .where(
              (d) =>
                  d != owner &&
                  d.finishTime == null &&
                  d.position != null &&
                  d.ghostTime <= 0 &&
                  (d.position! - owner.position!).length < range &&
                  (d.position! - owner.position!).dot(owner.forward!) > 3,
            )
            .toList()
          ..sort(
            (a, b) => (a.position! - owner.position!).length.compareTo(
              (b.position! - owner.position!).length,
            ),
          );
    return candidates.isEmpty ? null : candidates.first;
  }

  void _activatePower(Driver owner, ItemType type, bool enhanced) {
    final human = owner == player;
    switch (type) {
      case ItemType.missile:
      case ItemType.ice:
        var target = enhanced ? _targetOf(owner, 180) : null;
        var aim = owner.forward!;
        if (type == ItemType.missile)
          for (final path in track.shortcuts) {
            if (brokenGates.contains(path.id)) continue;
            final to = path.gate.p + const V3(0, 4, 0) - owner.position!;
            if (to.length < 95 &&
                to.dot(owner.forward!) > 8 &&
                to.unit.dot(owner.forward!) > .94) {
              target = null;
              aim = to.unit;
              break;
            }
          }
        projectiles.add(
          Projectile(
              owner.distance + 6,
              owner.lane,
              owner: owner,
              target: target,
              speed: math.max(125, owner.speed + 60),
              kind: type,
              enhanced: enhanced,
            )
            ..position =
                owner.position! + owner.forward! * 6 + owner.normal! * 1.6
            ..direction = aim,
        );
        if (human)
          tell(
            enhanced
                ? '${itemName(type)} GUIADO!'
                : '${itemName(type)} DISPARADO!',
          );
      case ItemType.shield:
        owner.shield = enhanced ? 10 : 6;
        owner.shieldEnhanced = enhanced;
        if (human)
          tell(enhanced ? 'SUPER ESCUDO • 10 SEGUNDOS' : 'ESCUDO • 6 SEGUNDOS');
      case ItemType.oil:
        oil.add(
          OilPatch(owner.distance - 6, owner.lane, owner: owner)
            ..position = owner.position! - owner.forward! * 6,
        );
        if (human) tell('ÓLEO NA PISTA!');
      case ItemType.nitro:
        if (human) {
          nitro = math.min(100, nitro + 60);
          flash = .3;
          tell('TURBO RECARREGADO!');
        } else {
          owner.velocity += owner.forward! * 18;
        }
      case ItemType.mine:
        mines.add(
          Mine(
            owner.position! - owner.forward! * 7 + owner.normal! * .4,
            owner,
          ),
        );
        if (human) tell('MINA ARMADA ATRÁS DO CARRO');
      case ItemType.emp:
        final radius = enhanced ? 125.0 : 85.0;
        projectiles.removeWhere(
          (p) =>
              p.position != null &&
              (p.position! - owner.position!).length < radius,
        );
        mines.removeWhere(
          (m) => (m.position - owner.position!).length < radius,
        );
        for (final d in drivers)
          if (d != owner &&
              d.ghostTime <= 0 &&
              (d.position! - owner.position!).length < radius) {
            d.weaponLock = enhanced ? 4 : 2.5;
            if (d == player && enhanced) {
              item = null;
              itemCharges = 0;
            }
            if (networked && enhanced) {
              networkPowers[d]?.item = null;
              networkPowers[d]?.charges = 0;
            }
            _effect(d, ImpactKind.pulse);
          }
        _effect(owner, ImpactKind.pulse);
        if (human) tell('EMP • ARMAS E EXPLOSIVOS NEUTRALIZADOS');
      case ItemType.tesla:
        final target = _targetOf(owner, enhanced ? 90 : 60);
        if (target != null) {
          beams.add(
            ElectricBeam(
              owner.position! + owner.normal! * 1.5,
              target.position! + target.normal! * 1.5,
            ),
          );
          if (target.shield > 0) {
            _damage(target, ImpactKind.electric, source: owner);
          } else {
            target.electricTime = enhanced ? 3.0 : 1.7;
            target.velocity *= .65;
            _effect(target, ImpactKind.electric);
            if (human) hitCount++;
          }
          if (target == player) tell('TESLA • MOTOR EM PANE');
        }
        if (human)
          tell(
            target == null ? 'TESLA • NENHUM ALVO À FRENTE' : 'TESLA • ACERTO!',
          );
      case ItemType.smoke:
        owner.smokeEmit = enhanced ? 6 : 3.2;
        owner.emitClock = 0;
        if (human) tell('CORTINA DE FUMAÇA');
      case ItemType.grenade:
        projectiles.add(
          Projectile(
              owner.distance + 7,
              owner.lane,
              owner: owner,
              kind: type,
              enhanced: enhanced,
              speed: 55,
            )
            ..position =
                owner.position! + owner.forward! * 7 + owner.normal! * 3
            ..direction = owner.forward!
            ..ballisticVelocity =
                owner.velocity * .45 + owner.forward! * 48 + owner.normal! * 20
            ..life = 2.0,
        );
        if (human) tell('GRANADA • LANÇADA EM ARCO');
      case ItemType.shockwave:
        final radius = enhanced ? 58.0 : 38.0;
        _effect(owner, ImpactKind.force);
        for (final d in drivers) {
          if (d == owner || d.finishTime != null || d.ghostTime > 0) continue;
          final delta = d.position! - owner.position!;
          if (delta.length > radius || delta.dot(owner.normal!).abs() > 10)
            continue;
          if (d.shield > 0) {
            _damage(d, ImpactKind.sparks, source: owner);
            continue;
          }
          final planar = delta - d.normal! * delta.dot(d.normal!);
          d.velocity +=
              (planar.length > .1 ? planar.unit : owner.forward!) *
              (enhanced ? 26 : 18);
          d.stun = math.max(d.stun, .35);
          d.damage = math.max(d.damage, .55);
          d.hitFlash = .5;
          _effect(d, ImpactKind.sparks);
          if (human) hitCount++;
          if (d == player) {
            impact = .6;
            tell('ONDA DE IMPACTO • EMPURRADO!');
          }
        }
        events.add('hit');
        if (human) tell('ONDA DE IMPACTO • ABRA ESPAÇO!');
      case ItemType.repair:
        owner.damage = owner.stun = owner.spinTime = owner.hitFlash = 0;
        owner.freezeTime = owner.electricTime = owner.punctureTime = 0;
        owner.repairGlow = 1.4;
        if (enhanced) {
          owner.shield = math.max(owner.shield, 4);
          owner.shieldEnhanced = false;
        }
        _effect(owner, ImpactKind.repair);
        if (human)
          tell(
            enhanced ? 'SUPER REPARO • PROTEÇÃO POR 4 S' : 'CARRO REPARADO!',
          );
      case ItemType.spikes:
        final f = driverFrame(owner);
        spikeStrips.add(
          SpikeStrip(
            TrackFrame(f.p - f.forward * 7, f.right, f.up, f.forward, f.s),
            owner,
            enhanced,
          ),
        );
        if (human) tell('ESPINHOS • FAIXA SOLTA NA PISTA');
      case ItemType.salvo:
        // Three rockets in a fan (five and homing when enhanced), reusing
        // the missile flight model and gate-breaking aim of the single shot.
        var baseAim = owner.forward!;
        for (final path in track.shortcuts) {
          if (brokenGates.contains(path.id)) continue;
          final to = path.gate.p + const V3(0, 4, 0) - owner.position!;
          if (to.length < 95 &&
              to.dot(owner.forward!) > 8 &&
              to.unit.dot(owner.forward!) > .94) {
            baseAim = to.unit;
            break;
          }
        }
        final right = owner.normal!.cross(baseAim).unit;
        final angles = enhanced
            ? const [-0.17, -0.085, 0.0, 0.085, 0.17]
            : const [-0.11, 0.0, 0.11];
        for (var k = 0; k < angles.length; k++) {
          final aim = (baseAim + right * angles[k]).unit;
          projectiles.add(
            Projectile(
                owner.distance + 6,
                owner.lane,
                owner: owner,
                target: enhanced && k == 2 ? _targetOf(owner, 190) : null,
                speed: math.max(125, owner.speed + 60),
                kind: ItemType.missile,
                enhanced: enhanced,
              )
              ..position =
                  owner.position! + owner.forward! * 6 + owner.normal! * 1.6
              ..direction = aim,
          );
        }
        if (human) {
          tell(
            enhanced
                ? 'SUPER SALVA • CINCO FOGUETES!'
                : 'SALVA TRIPLA • TRÊS FOGUETES!',
          );
        }
      case ItemType.dreno:
        // Steal momentum from the nearest rival ahead: they sputter, the
        // owner surges. Shields block it through the normal damage path.
        final target = _targetOf(owner, enhanced ? 140 : 95);
        if (target == null) {
          if (human) tell('DRENO • NENHUM ALVO À FRENTE');
        } else if (target.shield > 0) {
          _damage(target, ImpactKind.electric, source: owner);
          if (human) tell('DRENO • BLOQUEADO PELO ESCUDO');
        } else {
          target.electricTime = math.max(
            target.electricTime,
            enhanced ? 1.8 : 1.1,
          );
          target.velocity *= enhanced ? .45 : .6;
          _effect(target, ImpactKind.electric);
          if (human) {
            nitro = math.min(100, nitro + (enhanced ? 55 : 35));
            hitCount++;
            tell('DRENO • ENERGIA ROUBADA!');
          } else {
            owner.velocity += owner.forward! * (enhanced ? 16 : 11);
          }
          if (target == player) tell('DRENO • SUA ENERGIA FOI ROUBADA!');
        }
      case ItemType.propulsor:
        // A hop over trouble plus a forward surge, on the normal jump model.
        owner.velocity +=
            owner.normal! * (enhanced ? 31 : 24) + owner.forward! * 9;
        owner.jumpVelocity = math.max(owner.jumpVelocity, enhanced ? 8 : 6);
        owner.airborne = true;
        if (human) {
          nitro = math.min(100, nitro + 20);
          tell(
            enhanced
                ? 'SUPER PROPULSOR • SALTO ALTO!'
                : 'PROPULSOR • SALTO COM IMPULSO!',
          );
        }
      case ItemType.fantasma:
        // Intangible for a few seconds: rivals, projectiles, mines, oil and
        // strips all pass through; the driver cannot be hit or blocked.
        owner.ghostTime = enhanced ? 6.5 : 4.5;
        _effect(owner, ImpactKind.pulse);
        if (human) {
          tell(
            enhanced
                ? 'SUPER FANTASMA • INTANGÍVEL POR 6,5 S'
                : 'FANTASMA • INTANGÍVEL POR 4,5 S',
          );
        }
    }
  }

  void _iceImpact(Projectile p, V3 point, Driver? target) {
    final f = track.project(point).frame;
    effects.add(
      ImpactEffect(f.s, 0, ImpactKind.frost)
        ..pose = TrackFrame(point, f.right, const V3(0, 1, 0), f.forward, f.s),
    );
    if (target == null) return;
    if (target.shield > 0) {
      _damage(target, ImpactKind.frost, source: p.owner);
      return;
    }
    target.freezeTime = p.enhanced ? 4.0 : 2.4;
    target.velocity *= .48;
    if (p.owner == player) {
      hitCount++;
      tell('GELO • ADVERSÁRIO CONGELADO!');
    }
    if (target == player) tell('CONGELADO • AGUARDE O DEGelo'.toUpperCase());
    events.add('hit');
  }

  void _combatStatus(double dt) {
    drafting = false;
    for (final d in drivers) {
      d.freezeTime = math.max(0, d.freezeTime - dt);
      d.electricTime = math.max(0, d.electricTime - dt);
      d.weaponLock = math.max(0, d.weaponLock - dt);
      d.punctureTime = math.max(0, d.punctureTime - dt);
      d.repairGlow = math.max(0, d.repairGlow - dt);
      if (d.freezeTime > 0) d.velocity *= math.exp(-dt * .65);
      if (d.smokeEmit > 0) {
        d.smokeEmit -= dt;
        d.emitClock -= dt;
        if (d.emitClock <= 0) {
          d.emitClock = .28;
          clouds.add(
            SmokeCloud(d.position! - d.forward! * 7 + d.normal! * 2, d),
          );
        }
      }
    }
    if (networked) {
      for (final follower in networkDrivers) {
        if (follower.speed <= 30) continue;
        for (final leader in networkDrivers) {
          if (leader == follower) continue;
          final delta = follower.position! - leader.position!;
          final along = delta.dot(leader.forward!);
          if (along < -8 &&
              along > -35 &&
              delta.dot(leader.normal!.cross(leader.forward!)).abs() < 4) {
            follower.boostEnergy = math.min(100, follower.boostEnergy + dt * 6);
            if (follower == player) drafting = true;
            break;
          }
        }
      }
      return;
    }
    for (final d in bots) {
      final delta = player.position! - d.position!,
          along = delta.dot(d.forward!);
      if (along < -8 &&
          along > -35 &&
          delta.dot(d.normal!.cross(d.forward!)).abs() < 4 &&
          player.speed > 30) {
        drafting = true;
        nitro = math.min(100, nitro + dt * 6);
      }
    }
  }

  void _combatObjects(double dt) {
    for (final beam in beams) beam.life -= dt;
    beams.removeWhere((b) => b.life <= 0);
    for (final m in mines) {
      m.life -= dt;
      m.arm -= dt;
      if (m.arm > 0) continue;
      for (final d in drivers) {
        if (d.finishTime != null ||
            d.ghostTime > 0 ||
            d.jump > 3 ||
            d.airborne ||
            (d == m.owner && m.life > 12))
          continue;
        if ((d.position! - m.position).length < 4.4) {
          _detonate(
            Projectile(0, 0, owner: m.owner),
            m.position,
            const V3(0, 1, 0),
            direct: d,
          );
          m.life = 0;
          break;
        }
      }
    }
    mines.removeWhere((m) => m.life <= 0);
    for (final strip in spikeStrips) {
      strip.life -= dt;
      strip.arm -= dt;
      if (strip.arm > 0) continue;
      for (final d in drivers) {
        if (d.finishTime != null ||
            d.ghostTime > 0 ||
            d.airborne ||
            d.jump > .6 ||
            (d == strip.owner && strip.life > 10.6))
          continue;
        final delta = d.position! - strip.frame.p;
        if (delta.dot(strip.frame.right).abs() > 7 ||
            delta.dot(strip.frame.forward).abs() > 3.5 ||
            delta.dot(strip.frame.up).abs() > 2.5)
          continue;
        if (d.shield > 0) {
          _damage(d, ImpactKind.sparks, source: strip.owner);
        } else {
          d.punctureTime = strip.enhanced ? 6 : 4;
          d.hitFlash = .5;
          d.damage = math.max(d.damage, .35);
          d.velocity *= .82;
          _effect(d, ImpactKind.sparks);
          if (strip.owner == player) hitCount++;
          if (d == player) tell('PNEUS FURADOS • ADERÊNCIA REDUZIDA');
          events.add('hit');
        }
        strip.life = 0;
        break;
      }
    }
    spikeStrips.removeWhere((s) => s.life <= 0);
    if (spikeStrips.length > 16)
      spikeStrips.removeRange(0, spikeStrips.length - 16);
    for (final cloud in clouds) {
      cloud.life -= dt;
    }
    clouds.removeWhere((c) => c.life <= 0);
    if (clouds.length > 22) clouds.removeRange(0, clouds.length - 22);
    for (final d in drivers) {
      d.smokeExposure = 0;
      if (d.finishTime != null) continue;
      final sight = d.position! + d.normal! * 1.1;
      for (final cloud in clouds) {
        if (d == cloud.owner) continue;
        d.smokeExposure = math.max(d.smokeExposure, cloud.densityAt(sight));
      }
    }
    if (mines.length > 20) mines.removeRange(0, mines.length - 20);
  }
}
