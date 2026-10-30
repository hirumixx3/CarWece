part of 'engine.dart';

class OpponentTuning {
  final double skill, cornerForce, decision, lookAhead;
  final double boostRegen, boostStart, attackMin, attackRange, enhancedChance;
  final String description;
  const OpponentTuning(
    this.skill,
    this.cornerForce,
    this.decision,
    this.lookAhead,
    this.boostRegen,
    this.boostStart,
    this.attackMin,
    this.attackRange,
    this.enhancedChance,
    this.description,
  );
  static const easy = OpponentTuning(
    .76,
    38,
    .16,
    .36,
    0,
    100,
    10,
    0,
    0,
    'Rivais mais lentos, sem turbo nem ataques de armas.',
  );
  static const normal = OpponentTuning(
    .98,
    42,
    .14,
    .38,
    4,
    50,
    4.5,
    2,
    .20,
    'Rivais da sua categoria, turbo nas retas e uso tático de armas.',
  );
  static const hard = OpponentTuning(
    1.04,
    45,
    .11,
    .40,
    5,
    35,
    3.3,
    1.8,
    .33,
    'Ritmo mais forte, reações rápidas, mais turbo e pressão com armas.',
  );
  static OpponentTuning forDifficulty(String value) => switch (value) {
    'easy' => easy,
    'hard' => hard,
    _ => normal,
  };
}
