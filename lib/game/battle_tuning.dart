part of 'engine.dart';

class BattleTuning {
  final double skill, attackDelay, aimSpread, weaponDamage;
  final String description;
  const BattleTuning(
    this.skill,
    this.attackDelay,
    this.aimSpread,
    this.weaponDamage,
    this.description,
  );
  static const easy = BattleTuning(
    .72,
    2.1,
    .24,
    .72,
    'Mais tempo para reagir, rivais mais lentos e armas menos fortes.',
  );
  static const normal = BattleTuning(
    .88,
    1.1,
    .11,
    .86,
    'Pressão moderada e mais intervalo entre os ataques.',
  );
  static const hard = BattleTuning(
    .98,
    .58,
    .055,
    .94,
    'Rivais mais precisos e rápidos, ainda com pausas entre os ataques.',
  );
  static BattleTuning forDifficulty(String difficulty) => switch (difficulty) {
    'easy' => easy,
    'hard' => hard,
    _ => normal,
  };
}
