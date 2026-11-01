import 'dart:math' as math;
import 'math3d.dart';

part 'circuits.dart';
part 'loop_circuits.dart';
part 'scenery.dart';
part 'race_course.dart';
part 'battle_content.dart';
part 'road_geometry.dart';
part 'world_expansion.dart';
part 'world_track_obstacles.dart';

enum DriveType { rear, all, front }

class CarSpec {
  final String id, name, tag, description;
  final int color, accent, cost;
  final double speed, acceleration, handling;
  final int body;
  final DriveType drive;
  final int requiredStars;
  final String tier;
  const CarSpec(
    this.id,
    this.name,
    this.tag,
    this.description,
    this.color,
    this.accent,
    this.speed,
    this.acceleration,
    this.handling,
    this.cost,
    this.body, {
    this.drive = DriveType.rear,
    this.requiredStars = 0,
    this.tier = 'ESPORTIVO',
  });
  CarDesign get design => carDesigns[body];
}

/// Model proportions, not performance specifications. Units match the toy world.
class CarDesign {
  final double halfLength, halfWidth, belt, roof, roofFront, roofRear;
  final double glassFront, glassRear, frontAxle, rearAxle, wheelRadius;
  final bool sedan, hatch;
  final int spokes, rimColor;
  const CarDesign(
    this.halfLength,
    this.halfWidth,
    this.belt,
    this.roof,
    this.roofFront,
    this.roofRear,
    this.glassFront,
    this.glassRear,
    this.frontAxle,
    this.rearAxle, {
    this.wheelRadius = .61,
    this.sedan = false,
    this.hatch = false,
    this.spokes = 6,
    this.rimColor = 0xffd5dce4,
  });
  double get wheelTrack => halfWidth - .19;
}

const carDesigns = <CarDesign>[
  CarDesign(
    3.60,
    1.77,
    1.27,
    1.94,
    .38,
    -1.08,
    1.40,
    -2.28,
    2.17,
    -2.05,
    spokes: 5,
    rimColor: 0xff52473c,
  ), // RX-7 Fortune
  CarDesign(
    3.64,
    1.65,
    1.43,
    2.30,
    .64,
    -1.17,
    1.48,
    -2.02,
    2.16,
    -2.03,
    sedan: true,
    spokes: 6,
  ), // Evolution IX
  CarDesign(
    3.65,
    1.69,
    1.37,
    2.16,
    .36,
    -1.25,
    1.44,
    -2.12,
    2.15,
    -2.08,
    spokes: 6,
  ), // R34
  CarDesign(
    3.39,
    1.69,
    1.35,
    2.11,
    .45,
    -.82,
    1.36,
    -2.38,
    2.03,
    -1.94,
    spokes: 5,
  ), // Z33
  CarDesign(
    3.62,
    1.73,
    1.32,
    2.08,
    .30,
    -1.00,
    1.48,
    -2.25,
    2.16,
    -2.09,
    spokes: 5,
  ), // A80
  CarDesign(
    3.65,
    1.76,
    1.21,
    1.89,
    .68,
    -.85,
    1.66,
    -1.47,
    2.17,
    -2.16,
    spokes: 5,
  ), // NA1
  CarDesign(
    3.50,
    1.70,
    1.42,
    2.25,
    .58,
    -1.12,
    1.49,
    -2.02,
    2.12,
    -2.02,
    sedan: true,
    spokes: 8,
    rimColor: 0xffc89a3f,
  ), // 22B
  CarDesign(
    3.19,
    1.53,
    1.39,
    2.25,
    .72,
    -1.62,
    1.43,
    -2.59,
    1.94,
    -1.89,
    hatch: true,
    spokes: 5,
    rimColor: 0xffe9e8dc,
  ), // EK9
  CarDesign(
    3.48,
    1.63,
    1.30,
    2.01,
    .42,
    -1.09,
    1.44,
    -2.16,
    2.08,
    -2.04,
    spokes: 7,
  ), // S15
  CarDesign(
    3.56,
    1.67,
    1.38,
    2.19,
    .52,
    -1.14,
    1.52,
    -2.02,
    2.12,
    -2.02,
    spokes: 10,
  ), // E46
  CarDesign(
    3.58,
    1.80,
    1.27,
    2.03,
    .32,
    -.92,
    1.55,
    -2.30,
    2.08,
    -2.12,
    wheelRadius: .64,
    spokes: 10,
    rimColor: 0xff343d43,
  ), // 992 GT3 RS
  CarDesign(
    3.66,
    1.83,
    1.10,
    1.76,
    .85,
    -.87,
    1.85,
    -1.80,
    2.19,
    -2.18,
    wheelRadius: .60,
    spokes: 6,
    rimColor: 0xff303a3e,
  ), // Huracan
  CarDesign(
    3.10,
    1.48,
    1.20,
    1.96,
    .26,
    -.72,
    1.28,
    -1.78,
    1.91,
    -1.79,
    wheelRadius: .56,
    spokes: 7,
  ), // MX-5 NA, removable hardtop
  CarDesign(
    3.67,
    1.75,
    1.37,
    2.11,
    .22,
    -1.10,
    1.55,
    -2.36,
    2.17,
    -2.05,
    wheelRadius: .64,
    spokes: 5,
    rimColor: 0xff303942,
  ), // Mustang GT
  CarDesign(
    3.65,
    1.79,
    1.41,
    2.11,
    .45,
    -1.25,
    1.48,
    -2.17,
    2.15,
    -2.15,
    wheelRadius: .64,
    spokes: 10,
    rimColor: 0xff343a43,
  ), // GT-R R35
  CarDesign(
    3.62,
    1.82,
    1.18,
    1.83,
    .76,
    -.79,
    1.77,
    -1.90,
    2.15,
    -2.16,
    wheelRadius: .60,
    spokes: 5,
  ), // F40
  CarDesign(
    3.28,
    1.52,
    1.34,
    2.14,
    0.35,
    -1.23,
    1.47,
    -2.45,
    1.98,
    -1.89,
    hatch: true,
    spokes: 8,
  ), // TOYOTA AE86 TRUENO
  CarDesign(
    3.51,
    1.65,
    1.31,
    2.1,
    0.46,
    -1.07,
    1.48,
    -2.15,
    2.1,
    -1.99,
    sedan: true,
    spokes: 5,
  ), // MAZDA RX-8
  CarDesign(
    3.28,
    1.56,
    1.28,
    1.98,
    0.18,
    -0.69,
    1.27,
    -1.73,
    1.99,
    -1.86,
    spokes: 5,
  ), // HONDA S2000
  CarDesign(
    3.32,
    1.73,
    1.34,
    2.04,
    0.4,
    -0.78,
    1.34,
    -2.2,
    1.99,
    -1.91,
    spokes: 5,
  ), // NISSAN 370Z
  CarDesign(
    3.43,
    1.76,
    1.26,
    2.01,
    0.24,
    -0.91,
    1.45,
    -2.05,
    2.06,
    -1.97,
    spokes: 10,
  ), // TOYOTA GR SUPRA A90
  CarDesign(
    3.05,
    1.6,
    1.48,
    2.43,
    0.7,
    -1.4,
    1.39,
    -2.25,
    1.85,
    -1.77,
    hatch: true,
    spokes: 10,
  ), // TOYOTA GR YARIS
  CarDesign(
    3.48,
    1.65,
    1.33,
    2.07,
    0.37,
    -1.03,
    1.43,
    -2.14,
    2.06,
    -2.01,
    spokes: 5,
  ), // MITSUBISHI ECLIPSE GSX
  CarDesign(
    3.35,
    1.6,
    1.42,
    2.25,
    0.52,
    -1.1,
    1.48,
    -2.05,
    1.99,
    -1.91,
    spokes: 8,
  ), // BMW M3 E30
  CarDesign(
    3.6,
    1.79,
    1.18,
    1.88,
    0.76,
    -0.87,
    1.73,
    -1.87,
    2.15,
    -2.13,
    spokes: 10,
  ), // AUDI R8 V10
  CarDesign(
    3.65,
    1.83,
    1.26,
    1.95,
    -0.05,
    -1.24,
    1.13,
    -2.07,
    2.18,
    -2.11,
    spokes: 10,
  ), // MERCEDES-AMG GT R
  CarDesign(
    3.54,
    1.81,
    1.2,
    1.9,
    0.25,
    -1.1,
    1.36,
    -2.03,
    2.12,
    -2.07,
    spokes: 10,
  ), // CORVETTE C7 Z06
  CarDesign(
    3.66,
    1.8,
    1.23,
    1.91,
    -0.05,
    -1.17,
    1.15,
    -2.1,
    2.2,
    -2.09,
    spokes: 5,
  ), // DODGE VIPER GTS
  CarDesign(
    3.72,
    1.85,
    1.13,
    1.79,
    0.8,
    -0.77,
    1.8,
    -1.7,
    2.24,
    -2.16,
    spokes: 5,
  ), // FORD GT 2005
  CarDesign(
    3.7,
    1.84,
    1.1,
    1.82,
    0.83,
    -0.69,
    1.87,
    -1.66,
    2.22,
    -2.18,
    spokes: 10,
  ), // MCLAREN 720S
  CarDesign(
    3.74,
    1.88,
    1.12,
    1.81,
    0.93,
    -0.54,
    1.96,
    -1.48,
    2.25,
    -2.18,
    spokes: 5,
  ), // PAGANI ZONDA F
  CarDesign(
    3.57,
    1.64,
    1.36,
    2.12,
    0.38,
    -1.19,
    1.43,
    -2.15,
    2.12,
    -2.03,
    spokes: 7,
    rimColor: 0xffaeb9c2,
  ), // NISSAN SKYLINE GT-R R32
  CarDesign(
    3.72,
    1.69,
    1.38,
    2.19,
    0.43,
    -1.23,
    1.51,
    -2.18,
    2.21,
    -2.1,
    spokes: 9,
    rimColor: 0xffaeb9c2,
  ), // NISSAN SKYLINE GT-R R33
  CarDesign(
    3.42,
    1.58,
    1.32,
    2.03,
    0.39,
    -1.1,
    1.44,
    -2.08,
    2.03,
    -1.98,
    spokes: 5,
    rimColor: 0xffaeb9c2,
  ), // NISSAN SILVIA S13
  CarDesign(
    3.46,
    1.59,
    1.3,
    2.04,
    0.41,
    -1.32,
    1.43,
    -2.49,
    2.04,
    -1.99,
    spokes: 7,
    rimColor: 0xffaeb9c2,
    hatch: true,
  ), // NISSAN 180SX TYPE X
  CarDesign(
    3.5,
    1.76,
    1.24,
    1.94,
    0.59,
    -0.92,
    1.58,
    -2.17,
    2.1,
    -2.04,
    spokes: 9,
    rimColor: 0xffaeb9c2,
  ), // NISSAN 300ZX TWIN TURBO
  CarDesign(
    3.39,
    1.49,
    1.27,
    2.0,
    0.13,
    -1.17,
    1.24,
    -2.4,
    2.02,
    -1.94,
    spokes: 5,
    rimColor: 0xffaeb9c2,
  ), // DATSUN 240Z
  CarDesign(
    3.47,
    1.68,
    1.33,
    2.08,
    0.41,
    -1.09,
    1.48,
    -2.27,
    2.06,
    -1.99,
    spokes: 7,
    rimColor: 0xffaeb9c2,
    hatch: true,
  ), // TOYOTA CELICA GT-FOUR
  CarDesign(
    3.29,
    1.61,
    1.27,
    1.97,
    0.64,
    -0.7,
    1.62,
    -1.8,
    1.99,
    -1.96,
    spokes: 9,
    rimColor: 0xffaeb9c2,
  ), // TOYOTA MR2 GT-S
  CarDesign(
    3.43,
    1.56,
    1.32,
    2.05,
    0.39,
    -1.16,
    1.45,
    -2.37,
    2.06,
    -1.98,
    spokes: 5,
    rimColor: 0xffaeb9c2,
    hatch: true,
  ), // HONDA INTEGRA TYPE R
  CarDesign(
    3.64,
    1.75,
    1.44,
    2.29,
    0.65,
    -1.38,
    1.51,
    -2.51,
    2.16,
    -2.09,
    spokes: 7,
    rimColor: 0xffaeb9c2,
    hatch: true,
  ), // HONDA CIVIC TYPE R FL5
  CarDesign(
    3.52,
    1.66,
    1.44,
    2.28,
    0.59,
    -1.18,
    1.48,
    -2.05,
    2.12,
    -2.01,
    spokes: 9,
    rimColor: 0xffaeb9c2,
    sedan: true,
  ), // SUBARU IMPREZA WRX STI
  CarDesign(
    3.48,
    1.64,
    1.45,
    2.27,
    0.61,
    -1.12,
    1.49,
    -2.0,
    2.08,
    -2.01,
    spokes: 5,
    rimColor: 0xffaeb9c2,
    sedan: true,
  ), // MITSUBISHI LANCER EVOLUTION VI
  CarDesign(
    3.5,
    1.73,
    1.16,
    1.82,
    0.75,
    -0.77,
    1.76,
    -1.89,
    2.08,
    -2.06,
    spokes: 7,
    rimColor: 0xffaeb9c2,
  ), // BMW M1
  CarDesign(
    3.76,
    1.78,
    1.4,
    2.17,
    0.45,
    -1.21,
    1.52,
    -2.24,
    2.22,
    -2.13,
    spokes: 9,
    rimColor: 0xffaeb9c2,
  ), // BMW M4 COMPETITION
  CarDesign(
    3.15,
    1.65,
    1.42,
    2.24,
    0.62,
    -1.1,
    1.44,
    -2.19,
    1.89,
    -1.82,
    spokes: 5,
    rimColor: 0xffaeb9c2,
    hatch: true,
  ), // AUDI SPORT QUATTRO
  CarDesign(
    2.94,
    1.44,
    1.47,
    2.35,
    0.71,
    -1.47,
    1.39,
    -2.28,
    1.78,
    -1.72,
    spokes: 7,
    rimColor: 0xffaeb9c2,
    hatch: true,
  ), // VOLKSWAGEN GOLF GTI MK1
  CarDesign(
    2.6,
    1.4,
    1.46,
    2.32,
    0.73,
    -1.19,
    1.27,
    -1.98,
    1.57,
    -1.54,
    spokes: 9,
    rimColor: 0xffaeb9c2,
    hatch: true,
  ), // MINI COOPER S
  CarDesign(
    3.03,
    1.65,
    1.43,
    2.3,
    0.7,
    -1.21,
    1.44,
    -2.22,
    1.82,
    -1.77,
    spokes: 5,
    rimColor: 0xffaeb9c2,
    hatch: true,
  ), // PEUGEOT 205 TURBO 16
  CarDesign(
    2.9,
    1.66,
    1.46,
    2.34,
    0.65,
    -1.28,
    1.37,
    -2.17,
    1.73,
    -1.69,
    spokes: 7,
    rimColor: 0xffaeb9c2,
    hatch: true,
  ), // RENAULT 5 TURBO
  CarDesign(
    3.21,
    1.65,
    1.48,
    2.36,
    0.67,
    -1.33,
    1.43,
    -2.32,
    1.94,
    -1.84,
    spokes: 9,
    rimColor: 0xffaeb9c2,
    hatch: true,
  ), // LANCIA DELTA HF INTEGRALE
  CarDesign(
    3.0,
    1.72,
    1.21,
    1.88,
    0.72,
    -0.59,
    1.61,
    -1.58,
    1.82,
    -1.76,
    spokes: 5,
    rimColor: 0xffaeb9c2,
  ), // LANCIA STRATOS HF
  CarDesign(
    3.26,
    1.64,
    1.27,
    1.99,
    0.46,
    -0.82,
    1.46,
    -1.93,
    1.98,
    -1.93,
    spokes: 7,
    rimColor: 0xffaeb9c2,
  ), // ALPINE A110
  CarDesign(
    3.55,
    1.86,
    1.08,
    1.69,
    0.88,
    -0.63,
    1.91,
    -1.61,
    2.15,
    -2.1,
    spokes: 9,
    rimColor: 0xffaeb9c2,
  ), // LAMBORGHINI COUNTACH LP5000
  CarDesign(
    3.72,
    1.88,
    1.14,
    1.83,
    0.72,
    -0.8,
    1.8,
    -1.94,
    2.22,
    -2.14,
    spokes: 5,
    rimColor: 0xffaeb9c2,
  ), // FERRARI TESTAROSSA
  CarDesign(
    3.78,
    1.91,
    1.26,
    1.94,
    0.64,
    -0.77,
    1.72,
    -1.86,
    2.26,
    -2.19,
    spokes: 7,
    rimColor: 0xffaeb9c2,
  ), // BUGATTI CHIRON
];

const cars = <CarSpec>[
  CarSpec(
    'rx7',
    'MAZDA RX-7 VEILSIDE',
    'FORTUNE • TRAÇÃO TRASEIRA',
    'FD com carroceria larga Fortune, pintura laranja e detalhes pretos.',
    0xffff761f,
    0xff171c26,
    86,
    35,
    1.10,
    0,
    0,
    requiredStars: 0,
    tier: 'ÍCONES',
  ),
  CarSpec(
    'evo9',
    'LANCER EVOLUTION IX',
    'MITSUBISHI • TRAÇÃO INTEGRAL',
    'Sedã de rali, entradas no capô e aerofólio alto. Mais aderência.',
    0xffd82e3c,
    0xff202834,
    84,
    39,
    1.22,
    1500,
    1,
    drive: DriveType.all,
    requiredStars: 3,
    tier: 'ESPORTIVO',
  ),
  CarSpec(
    'r34',
    'SKYLINE GT-R R34',
    'NISSAN • TRAÇÃO INTEGRAL',
    'Cupê azul, traseira com quatro lanternas redondas e asa elevada.',
    0xff2a67de,
    0xff202c45,
    91,
    36,
    1.12,
    3200,
    2,
    drive: DriveType.all,
    requiredStars: 8,
    tier: 'ÍCONES',
  ),
  CarSpec(
    '350z',
    'NISSAN 350Z',
    'Z33 • TRAÇÃO TRASEIRA',
    'Cupê de teto arqueado, faróis verticais e traseira curta.',
    0xffb6c4d2,
    0xff263348,
    85,
    34,
    1.13,
    950,
    3,
    requiredStars: 0,
    tier: 'ESPORTIVO',
  ),
  CarSpec(
    'supra',
    'TOYOTA SUPRA A80',
    'TURBO • TRAÇÃO TRASEIRA',
    'Capô longo, lanternas circulares e aerofólio curvo.',
    0xfff1ebdf,
    0xff273140,
    96,
    33,
    .98,
    4200,
    4,
    requiredStars: 12,
    tier: 'ÍCONES',
  ),
  CarSpec(
    'nsx',
    'HONDA NSX NA1',
    'MOTOR CENTRAL • TRAÇÃO TRASEIRA',
    'Carroceria baixa, teto preto, faróis escamoteáveis e asa integrada.',
    0xffffc62d,
    0xff172531,
    90,
    36,
    1.25,
    4800,
    5,
    requiredStars: 15,
    tier: 'ÍCONES',
  ),
  CarSpec(
    '22b',
    'SUBARU IMPREZA 22B',
    'STI • TRAÇÃO INTEGRAL',
    'Cupê azul de para-lamas largos, scoop e rodas douradas.',
    0xff2059bb,
    0xffd7af4e,
    86,
    40,
    1.25,
    2900,
    6,
    drive: DriveType.all,
    requiredStars: 8,
    tier: 'ÍCONES',
  ),
  CarSpec(
    'ek9',
    'HONDA CIVIC TYPE R',
    'EK9 • TRAÇÃO DIANTEIRA',
    'Hatch compacto branco, leve e ágil nas curvas fechadas.',
    0xffeeeee3,
    0xffd42e39,
    79,
    38,
    1.34,
    500,
    7,
    drive: DriveType.front,
    requiredStars: 0,
    tier: 'RUA',
  ),
  CarSpec(
    's15',
    'NISSAN SILVIA S15',
    'SPEC-R • TRAÇÃO TRASEIRA',
    'Cupê perolado, faróis afilados, capô longo e asa discreta. Feito para drift.',
    0xffdce9e3,
    0xff253439,
    84,
    37,
    1.25,
    1800,
    8,
    requiredStars: 5,
    tier: 'ESPORTIVO',
  ),
  CarSpec(
    'm3e46',
    'BMW M3 E46',
    'SEIS CILINDROS • TRAÇÃO TRASEIRA',
    'Cupê prata, quatro faróis, grade dupla, saídas laterais e quatro escapes.',
    0xff9baab5,
    0xff183754,
    92,
    38,
    1.18,
    3600,
    9,
    requiredStars: 10,
    tier: 'ÍCONES',
  ),
  CarSpec(
    'gt3rs',
    'PORSCHE 911 GT3 RS',
    '992 • TRAÇÃO TRASEIRA',
    'Carroceria larga, faróis ovais, entradas nos para-lamas e asa de competição.',
    0xffece9de,
    0xff262d32,
    101,
    40,
    1.38,
    8200,
    10,
    requiredStars: 22,
    tier: 'EXÓTICO',
  ),
  CarSpec(
    'huracan',
    'LAMBORGHINI HURACÁN',
    'TECNICA • TRAÇÃO TRASEIRA',
    'Cunha verde, teto baixo, luzes em Y e difusor largo. Coleção de elite.',
    0xff79bd2d,
    0xff192b2a,
    105,
    42,
    1.27,
    11000,
    11,
    requiredStars: 28,
    tier: 'EXÓTICO',
  ),
  CarSpec(
    'mx5',
    'MAZDA MX-5 NA',
    'ROADSTER • TRAÇÃO TRASEIRA',
    'Compacto vermelho, hardtop preto e faróis escamoteáveis. Leve para curvas.',
    0xffdf3336,
    0xff202c34,
    80,
    39,
    1.40,
    750,
    12,
    requiredStars: 0,
    tier: 'RUA',
  ),
  CarSpec(
    'mustang',
    'FORD MUSTANG GT',
    'FASTBACK • TRAÇÃO TRASEIRA',
    'Capô longo, grade larga, duas faixas e três lanternas de cada lado.',
    0xff2473c5,
    0xffe8e9df,
    95,
    38,
    1.08,
    3900,
    13,
    requiredStars: 10,
    tier: 'ÍCONES',
  ),
  CarSpec(
    'r35',
    'NISSAN GT-R R35',
    'BITURBO • TRAÇÃO INTEGRAL',
    'Cupê largo, quatro lanternas redondas e quatro escapes. Forte na saída.',
    0xffaab1b6,
    0xff263039,
    102,
    44,
    1.30,
    7200,
    14,
    drive: DriveType.all,
    requiredStars: 18,
    tier: 'EXÓTICO',
  ),
  CarSpec(
    'f40',
    'FERRARI F40',
    'CLÁSSICO • TRAÇÃO TRASEIRA',
    'Cunha vermelha, tomadas de ar, tampa com aletas e grande asa integrada.',
    0xffe72c2c,
    0xff252a2d,
    108,
    40,
    1.20,
    13500,
    15,
    requiredStars: 32,
    tier: 'EXÓTICO',
  ),
  CarSpec(
    'ae86',
    'TOYOTA AE86 TRUENO',
    'TRAÇÃO TRASEIRA',
    'Hatch panda branco e preto, faróis escamoteáveis.',
    0xffeeebe1,
    0xff202832,
    81,
    37,
    1.4,
    1100,
    16,
    drive: DriveType.rear,
    requiredStars: 2,
    tier: 'RUA',
  ),
  CarSpec(
    'rx8',
    'MAZDA RX-8',
    'TRAÇÃO TRASEIRA',
    'Cupê rotativo vinho, quatro portas e entradas triangulares.',
    0xffab2445,
    0xff26313b,
    88,
    38,
    1.29,
    2600,
    17,
    drive: DriveType.rear,
    requiredStars: 6,
    tier: 'ESPORTIVO',
  ),
  CarSpec(
    's2000',
    'HONDA S2000',
    'TRAÇÃO TRASEIRA',
    'Roadster AP1 amarelo, hardtop e capô comprido.',
    0xfff1c727,
    0xff242c34,
    89,
    39,
    1.42,
    3400,
    18,
    drive: DriveType.rear,
    requiredStars: 9,
    tier: 'ESPORTIVO',
  ),
  CarSpec(
    '370z',
    'NISSAN 370Z',
    'TRAÇÃO TRASEIRA',
    'Z34 de ombros largos e faróis em bumerangue.',
    0xffc57b28,
    0xff263039,
    91,
    39,
    1.3,
    3100,
    19,
    drive: DriveType.rear,
    requiredStars: 7,
    tier: 'ESPORTIVO',
  ),
  CarSpec(
    'a90',
    'TOYOTA GR SUPRA A90',
    'TRAÇÃO TRASEIRA',
    'Cupê vermelho, teto de dupla bolha e cauda elevada.',
    0xffd82c33,
    0xff242c34,
    99,
    42,
    1.31,
    5900,
    20,
    drive: DriveType.rear,
    requiredStars: 16,
    tier: 'ÍCONES',
  ),
  CarSpec(
    'gryaris',
    'TOYOTA GR YARIS',
    'TRAÇÃO INTEGRAL',
    'Hatch branco de rali, teto preto e grade ampla.',
    0xffe7e7df,
    0xff282e33,
    87,
    44,
    1.48,
    4300,
    21,
    drive: DriveType.all,
    requiredStars: 13,
    tier: 'ESPORTIVO',
  ),
  CarSpec(
    'eclipse',
    'MITSUBISHI ECLIPSE GSX',
    'TRAÇÃO INTEGRAL',
    'Cupê 2G verde, teto arqueado e asa curvada.',
    0xff319751,
    0xff29323b,
    90,
    41,
    1.24,
    2800,
    22,
    drive: DriveType.all,
    requiredStars: 8,
    tier: 'ÍCONES',
  ),
  CarSpec(
    'm3e30',
    'BMW M3 E30',
    'TRAÇÃO TRASEIRA',
    'Clássico vermelho, quatro faróis e para-lamas largos.',
    0xffbd3038,
    0xff2b3035,
    86,
    37,
    1.36,
    3200,
    23,
    drive: DriveType.rear,
    requiredStars: 10,
    tier: 'ÍCONES',
  ),
  CarSpec(
    'r8',
    'AUDI R8 V10',
    'TRAÇÃO INTEGRAL',
    'Prata, motor central e painéis laterais pretos.',
    0xffb6c0c7,
    0xff202a31,
    104,
    45,
    1.34,
    9500,
    24,
    drive: DriveType.all,
    requiredStars: 27,
    tier: 'EXÓTICO',
  ),
  CarSpec(
    'amggtr',
    'MERCEDES-AMG GT R',
    'TRAÇÃO TRASEIRA',
    'Verde, capô longo, grade vertical e asa larga.',
    0xff56a43b,
    0xff263332,
    105,
    42,
    1.29,
    10700,
    25,
    drive: DriveType.rear,
    requiredStars: 30,
    tier: 'EXÓTICO',
  ),
  CarSpec(
    'c7z06',
    'CORVETTE C7 Z06',
    'TRAÇÃO TRASEIRA',
    'Amarelo, capô ventilado e quatro escapes centrais.',
    0xffedc22a,
    0xff283034,
    106,
    43,
    1.28,
    10400,
    26,
    drive: DriveType.rear,
    requiredStars: 29,
    tier: 'EXÓTICO',
  ),
  CarSpec(
    'viper_gts',
    'DODGE VIPER GTS',
    'TRAÇÃO TRASEIRA',
    'Azul com faixas brancas e escapamento lateral.',
    0xff2355b7,
    0xffedeee2,
    108,
    41,
    1.18,
    12500,
    27,
    drive: DriveType.rear,
    requiredStars: 34,
    tier: 'EXÓTICO',
  ),
  CarSpec(
    'fordgt',
    'FORD GT 2005',
    'TRAÇÃO TRASEIRA',
    'Azul claro com laranja, cabine baixa e lanternas redondas.',
    0xff77c3d6,
    0xfff47832,
    110,
    43,
    1.3,
    15800,
    28,
    drive: DriveType.rear,
    requiredStars: 40,
    tier: 'EXÓTICO',
  ),
  CarSpec(
    '720s',
    'MCLAREN 720S',
    'TRAÇÃO TRASEIRA',
    'Laranja, faróis em cavidades e traseira com lâminas finas.',
    0xffff8b27,
    0xff253139,
    114,
    46,
    1.36,
    21500,
    29,
    drive: DriveType.rear,
    requiredStars: 52,
    tier: 'ELITE',
  ),
  CarSpec(
    'zonda',
    'PAGANI ZONDA F',
    'TRAÇÃO TRASEIRA',
    'Prata e carbono, asa alta e quatro escapes centrais.',
    0xffb8bfc0,
    0xff252d30,
    116,
    45,
    1.32,
    28000,
    30,
    drive: DriveType.rear,
    requiredStars: 66,
    tier: 'ELITE',
  ),
  CarSpec(
    'r32',
    'NISSAN SKYLINE GT-R R32',
    'GODZILLA',
    'GODZILLA. Miniatura com silhueta própria, faróis e acabamento específicos.',
    0xff9aabb0,
    0xff25343c,
    90,
    39,
    1.18,
    4500,
    31,
    drive: DriveType.all,
    requiredStars: 12,
    tier: 'MUNDO REAL',
  ),
  CarSpec(
    'r33',
    'NISSAN SKYLINE GT-R R33',
    'BCNR33',
    'BCNR33. Miniatura com silhueta própria, faróis e acabamento específicos.',
    0xffb3a0da,
    0xff273242,
    93,
    38,
    1.15,
    6200,
    32,
    drive: DriveType.all,
    requiredStars: 18,
    tier: 'MUNDO REAL',
  ),
  CarSpec(
    's13',
    'NISSAN SILVIA S13',
    'CLUB K’S',
    'CLUB K’S. Miniatura com silhueta própria, faróis e acabamento específicos.',
    0xff7cbbb0,
    0xff29353c,
    83,
    36,
    1.2,
    2600,
    33,
    drive: DriveType.rear,
    requiredStars: 5,
    tier: 'MUNDO REAL',
  ),
  CarSpec(
    '180sx',
    'NISSAN 180SX TYPE X',
    'RPS13',
    'RPS13. Miniatura com silhueta própria, faróis e acabamento específicos.',
    0xffe1e4dc,
    0xff2b303c,
    86,
    37,
    1.17,
    3400,
    34,
    drive: DriveType.rear,
    requiredStars: 8,
    tier: 'MUNDO REAL',
  ),
  CarSpec(
    '300zx',
    'NISSAN 300ZX TWIN TURBO',
    'Z32',
    'Z32. Miniatura com silhueta própria, faróis e acabamento específicos.',
    0xffedc236,
    0xff242733,
    94,
    36,
    1.09,
    6600,
    35,
    drive: DriveType.rear,
    requiredStars: 21,
    tier: 'MUNDO REAL',
  ),
  CarSpec(
    '240z',
    'DATSUN 240Z',
    'S30 CLÁSSICO',
    'S30 CLÁSSICO. Miniatura com silhueta própria, faróis e acabamento específicos.',
    0xffed7639,
    0xff303238,
    81,
    34,
    1.22,
    2400,
    36,
    drive: DriveType.rear,
    requiredStars: 4,
    tier: 'MUNDO REAL',
  ),
  CarSpec(
    'celica_gt4',
    'TOYOTA CELICA GT-FOUR',
    'ST205',
    'ST205. Miniatura com silhueta própria, faróis e acabamento específicos.',
    0xffe3e4df,
    0xffbf3034,
    88,
    40,
    1.23,
    5200,
    37,
    drive: DriveType.all,
    requiredStars: 14,
    tier: 'MUNDO REAL',
  ),
  CarSpec(
    'mr2_sw20',
    'TOYOTA MR2 GT-S',
    'SW20 CENTRAL',
    'SW20 CENTRAL. Miniatura com silhueta própria, faróis e acabamento específicos.',
    0xffd74338,
    0xff273139,
    87,
    38,
    1.2,
    4100,
    38,
    drive: DriveType.rear,
    requiredStars: 10,
    tier: 'MUNDO REAL',
  ),
  CarSpec(
    'integra_dc2',
    'HONDA INTEGRA TYPE R',
    'DC2',
    'DC2. Miniatura com silhueta própria, faróis e acabamento específicos.',
    0xfff0eedc,
    0xffc43c36,
    84,
    39,
    1.28,
    3600,
    39,
    drive: DriveType.front,
    requiredStars: 9,
    tier: 'MUNDO REAL',
  ),
  CarSpec(
    'civic_fl5',
    'HONDA CIVIC TYPE R FL5',
    'TURBO HOT HATCH',
    'TURBO HOT HATCH. Miniatura com silhueta própria, faróis e acabamento específicos.',
    0xffd0d9de,
    0xffc72d34,
    91,
    42,
    1.25,
    6900,
    40,
    drive: DriveType.front,
    requiredStars: 22,
    tier: 'MUNDO REAL',
  ),
  CarSpec(
    'wrx_sti04',
    'SUBARU IMPREZA WRX STI',
    'GD 2004',
    'GD 2004. Miniatura com silhueta própria, faróis e acabamento específicos.',
    0xff2867bf,
    0xffc5a247,
    90,
    42,
    1.25,
    5800,
    41,
    drive: DriveType.all,
    requiredStars: 16,
    tier: 'MUNDO REAL',
  ),
  CarSpec(
    'evo6',
    'MITSUBISHI LANCER EVOLUTION VI',
    'TOMMI MÄKINEN',
    'TOMMI MÄKINEN. Miniatura com silhueta própria, faróis e acabamento específicos.',
    0xffd73736,
    0xffe8e5d6,
    88,
    43,
    1.27,
    5600,
    42,
    drive: DriveType.all,
    requiredStars: 15,
    tier: 'MUNDO REAL',
  ),
  CarSpec(
    'bmw_m1',
    'BMW M1',
    'E26',
    'E26. Miniatura com silhueta própria, faróis e acabamento específicos.',
    0xffef7842,
    0xff202d3a,
    92,
    36,
    1.15,
    7200,
    43,
    drive: DriveType.rear,
    requiredStars: 24,
    tier: 'MUNDO REAL',
  ),
  CarSpec(
    'm4_g82',
    'BMW M4 COMPETITION',
    'G82',
    'G82. Miniatura com silhueta própria, faróis e acabamento específicos.',
    0xff68b56b,
    0xff26323a,
    96,
    42,
    1.14,
    9200,
    44,
    drive: DriveType.rear,
    requiredStars: 30,
    tier: 'MUNDO REAL',
  ),
  CarSpec(
    'quattro',
    'AUDI SPORT QUATTRO',
    'GRUPO B',
    'GRUPO B. Miniatura com silhueta própria, faróis e acabamento específicos.',
    0xffe7ddbe,
    0xffb83f3a,
    86,
    43,
    1.29,
    5900,
    45,
    drive: DriveType.all,
    requiredStars: 17,
    tier: 'MUNDO REAL',
  ),
  CarSpec(
    'golf_gti',
    'VOLKSWAGEN GOLF GTI MK1',
    'HOT HATCH ORIGINAL',
    'HOT HATCH ORIGINAL. Miniatura com silhueta própria, faróis e acabamento específicos.',
    0xffc83334,
    0xff222c32,
    76,
    37,
    1.34,
    1600,
    46,
    drive: DriveType.front,
    requiredStars: 2,
    tier: 'MUNDO REAL',
  ),
  CarSpec(
    'mini_cooper',
    'MINI COOPER S',
    'CLÁSSICO',
    'CLÁSSICO. Miniatura com silhueta própria, faróis e acabamento específicos.',
    0xff3d9078,
    0xffece8d8,
    74,
    38,
    1.38,
    1900,
    47,
    drive: DriveType.front,
    requiredStars: 3,
    tier: 'MUNDO REAL',
  ),
  CarSpec(
    '205_t16',
    'PEUGEOT 205 TURBO 16',
    'GRUPO B CENTRAL',
    'GRUPO B CENTRAL. Miniatura com silhueta própria, faróis e acabamento específicos.',
    0xffe5e0ce,
    0xff3986b0,
    88,
    45,
    1.3,
    6300,
    48,
    drive: DriveType.all,
    requiredStars: 19,
    tier: 'MUNDO REAL',
  ),
  CarSpec(
    'r5_turbo',
    'RENAULT 5 TURBO',
    'MAXI MINIATURA',
    'MAXI MINIATURA. Miniatura com silhueta própria, faróis e acabamento específicos.',
    0xff3f79c7,
    0xffc73839,
    85,
    43,
    1.26,
    4700,
    49,
    drive: DriveType.rear,
    requiredStars: 13,
    tier: 'MUNDO REAL',
  ),
  CarSpec(
    'delta',
    'LANCIA DELTA HF INTEGRALE',
    'EVOLUZIONE',
    'EVOLUZIONE. Miniatura com silhueta própria, faróis e acabamento específicos.',
    0xffd6d9cc,
    0xff378063,
    87,
    44,
    1.31,
    6100,
    50,
    drive: DriveType.all,
    requiredStars: 18,
    tier: 'MUNDO REAL',
  ),
  CarSpec(
    'stratos',
    'LANCIA STRATOS HF',
    'CUNHA DE RALI',
    'CUNHA DE RALI. Miniatura com silhueta própria, faróis e acabamento específicos.',
    0xff78ba54,
    0xffd84b38,
    89,
    42,
    1.24,
    6700,
    51,
    drive: DriveType.rear,
    requiredStars: 20,
    tier: 'MUNDO REAL',
  ),
  CarSpec(
    'alpine_a110',
    'ALPINE A110',
    'BERLINETTE MODERNA',
    'BERLINETTE MODERNA. Miniatura com silhueta própria, faróis e acabamento específicos.',
    0xff347cce,
    0xffd4dce3,
    91,
    41,
    1.28,
    7100,
    52,
    drive: DriveType.rear,
    requiredStars: 23,
    tier: 'MUNDO REAL',
  ),
  CarSpec(
    'countach',
    'LAMBORGHINI COUNTACH LP5000',
    'QUATTROVALVOLE',
    'QUATTROVALVOLE. Miniatura com silhueta própria, faróis e acabamento específicos.',
    0xfff0e9d4,
    0xff26313b,
    99,
    39,
    1.06,
    13000,
    53,
    drive: DriveType.rear,
    requiredStars: 38,
    tier: 'MUNDO REAL',
  ),
  CarSpec(
    'testarossa',
    'FERRARI TESTAROSSA',
    'FLAT-12',
    'FLAT-12. Miniatura com silhueta própria, faróis e acabamento específicos.',
    0xffd93830,
    0xff282f35,
    98,
    38,
    1.08,
    12500,
    54,
    drive: DriveType.rear,
    requiredStars: 36,
    tier: 'MUNDO REAL',
  ),
  CarSpec(
    'chiron',
    'BUGATTI CHIRON',
    'W16',
    'W16. Miniatura com silhueta própria, faróis e acabamento específicos.',
    0xff2f66af,
    0xff15252f,
    108,
    45,
    1.03,
    19500,
    55,
    drive: DriveType.all,
    requiredStars: 55,
    tier: 'MUNDO REAL',
  ),
];

enum RaceMode { quick, championship, timeTrial }

enum ItemType {
  missile,
  shield,
  oil,
  nitro,
  mine,
  emp,
  tesla,
  ice,
  smoke,
  grenade,
  shockwave,
  repair,
  spikes,
}

String itemName(ItemType item) => switch (item) {
  ItemType.missile => 'FOGUETE',
  ItemType.shield => 'ESCUDO',
  ItemType.oil => 'ÓLEO',
  ItemType.nitro => 'CARGA TURBO',
  ItemType.mine => 'MINA',
  ItemType.emp => 'EMP',
  ItemType.tesla => 'TESLA',
  ItemType.ice => 'GELO',
  ItemType.smoke => 'FUMAÇA',
  ItemType.grenade => 'GRANADA',
  ItemType.shockwave => 'IMPACTO',
  ItemType.repair => 'REPARO',
  ItemType.spikes => 'ESPINHOS',
};

class TrackFrame {
  final V3 p, right, up, forward;
  final double s;
  const TrackFrame(this.p, this.right, this.up, this.forward, this.s);
  V3 point(double lateral, [double height = 0]) =>
      p + right * lateral + up * height;
}

class WorldObstacle {
  final V3 center, size;
  final int color;
  final bool visible;
  final V3 right, forward;
  const WorldObstacle(
    this.center,
    this.size, {
    this.color = 0xffe4b145,
    this.visible = true,
    this.right = const V3(1, 0, 0),
    this.forward = const V3(0, 0, 1),
  });
}

class WorldRamp {
  final TrackFrame frame;
  final double length, width, height;
  const WorldRamp(
    this.frame, {
    this.length = 16,
    this.width = 12,
    this.height = 3,
  });
}

class TrackProjection {
  final TrackFrame frame;
  final double lateral, height, squaredDistance;
  const TrackProjection(
    this.frame,
    this.lateral,
    this.height,
    this.squaredDistance,
  );
}

class TrackSpec {
  final bool openArena;
  final String id, name, subtitle, room;
  final int accent, floor, wall;
  final double width;
  final List<V3> controls;
  final (int, int)? loopControls;
  final List<LoopSection> loopSections;
  final List<TrackLoop> loops = [];
  TrackLoop? loopAt(double distance, {double before = 0, double after = 0}) {
    final s = wrap(distance, length);
    for (final loop in loops) {
      if (s >= loop.start - before && s <= loop.end + after) return loop;
    }
    return null;
  }

  final List<TrackFrame> frames = [];
  late final RoadCollisionMesh roadCollision = RoadCollisionMesh(this);
  final List<WorldObstacle> obstacles = [];
  // Only the 25 expansion race circuits opt in; legacy maps/arenas stay intact.
  final List<ExpansionTrackObstacle> themedObstacles = [];
  final List<WorldObstacle> scenery = [];
  final List<WorldRamp> ramps = [];
  final List<RoomProp> details = [];
  final List<ShortcutSpec> shortcuts = [];
  final List<CourseBarrier> barriers = [];
  final Map<(int, int), List<WorldObstacle>> barrierGrid = {};
  Iterable<WorldObstacle> nearbyObstacles(V3 p) sync* {
    yield* obstacles;
    final x = (p.x / 64).floor(), z = (p.z / 64).floor();
    for (var i = x - 1; i <= x + 1; i++)
      for (var j = z - 1; j <= z + 1; j++)
        yield* barrierGrid[(i, j)] ?? const <WorldObstacle>[];
  }

  int get requiredStars => circuitStars[id] ?? expansionCircuitStars[id] ?? 0;
  final Map<(int, int), Set<int>> _grid = {};
  // The route is immutable after construction. Reuse the same ordered segment
  // candidates instead of allocating/merging nine sets for every tire contact.
  final Map<(int, int), List<int>> _projectionCells = {};
  final Map<V3, TrackProjection> _projectionPoints = Map.identity();
  late final List<int> _projectionFallback = [
    for (var i = 0; i < frames.length; i += 4) i,
  ];
  bool get outdoor => expansionBiomes.containsKey(room);
  bool get night => room == 'ARCADE';
  bool get tiled => room == 'BANHEIRO' || room == 'COZINHA';
  double get floorGrip => switch (room) {
    'BANHEIRO' => .78,
    'COZINHA' => .90,
    'SALA' => 1.08,
    'FLORESTA' => .98,
    'PRÉ-HISTÓRIA' => .96,
    'DESERTO' => .92,
    'NEVE' => .84,
    'LITORAL' => 1.02,
    _ => 1.0,
  };
  double length = 0;
  double? loopStart, loopEnd;
  static const roomHalf = 870.0;
  static const floorHeight = .16;
  static const checkpointCount = 32;
  TrackSpec(
    this.id,
    this.name,
    this.subtitle,
    this.room,
    this.accent,
    this.floor,
    this.wall,
    this.controls, {
    this.width = 46,
    this.loopControls,
    this.loopSections = const [],
    this.openArena = false,
  }) {
    _build();
  }
  void _build() {
    final sections = [
      if (loopControls != null)
        LoopSection(loopControls!.$1, loopControls!.$2, const V3(1, 0, 0)),
      ...loopSections,
    ];
    final points = <V3>[];
    for (var i = 0; i < controls.length; i++) {
      for (var j = 0; j < 24; j++) {
        points.add(
          roadSpline(
            controls[(i - 1) % controls.length],
            controls[i],
            controls[(i + 1) % controls.length],
            controls[(i + 2) % controls.length],
            j / 24,
          ),
        );
      }
    }
    for (var i = 0; i < points.length; i++) {
      final tangent =
          (points[(i + 1) % points.length] - points[(i - 1) % points.length])
              .unit;
      LoopSection? section;
      for (final c in sections) {
        if (i >= c.first * 24 && i <= c.last * 24) {
          section = c;
          break;
        }
      }
      // Flat/elevated roads are explicitly upright. Loop transport is local;
      // it cannot distribute a residual roll over the rest of the circuit.
      final right = section != null
          ? (section.right - tangent * tangent.dot(section.right)).unit
          : const V3(0, 1, 0).cross(tangent).unit;
      if (i > 0) length += (points[i] - points[i - 1]).length;
      frames.add(
        TrackFrame(
          points[i],
          right,
          tangent.cross(right).unit,
          tangent,
          length,
        ),
      );
    }
    length += (points.first - points.last).length;
    for (final section in sections) {
      loops.add(
        TrackLoop(frames[section.first * 24].s, frames[section.last * 24].s),
      );
    }
    if (loops.isNotEmpty) {
      loopStart = loops.first.start;
      loopEnd = loops.first.end;
    }
    for (var i = 0; i < frames.length; i++) {
      final p = frames[i].p;
      _grid
          .putIfAbsent(((p.x / 64).floor(), (p.z / 64).floor()), () => {})
          .add(i);
    }
    // Real solid slalom props placed in floor sectors, leaving a route past them.
    for (final fraction in [.39, .45, .56, .68, .78, .88]) {
      final f = at(length * fraction);
      if (!isFloor(f.s)) continue;
      final p = f.point((obstacles.length.isEven ? 1 : -1) * 16);
      obstacles.add(
        WorldObstacle(
          V3(p.x, 2.6, p.z),
          const V3(9, 5.2, 13),
          color: obstacles.length.isEven ? 0xffdb503b : 0xff4482c9,
        ),
      );
    }
    // Every circuit has at least four slalom obstacles on actual open-floor sectors.
    for (final f in frames.where((f) => isFloor(f.s))) {
      if (obstacles.where((o) => o.visible).length >= 4) break;
      if (obstacles.any((o) => (o.center - f.p).length < 90)) continue;
      final p = f.point(obstacles.length.isEven ? 18 : -18);
      obstacles.add(
        WorldObstacle(
          V3(p.x, 2.6, p.z),
          const V3(9, 5.2, 13),
          color: obstacles.length.isEven ? 0xffb96141 : 0xff658a99,
        ),
      );
    }
    for (final fraction in [.48, .54, .63]) {
      final f = at(length * fraction);
      if (isFloor(f.s)) {
        ramps.add(WorldRamp(f));
        break;
      }
    }
    for (var i = 0; i < (outdoor ? 0 : 26); i++) {
      final a = i * 2.38;
      final p = V3(
        math.cos(a) * (690 + i % 3 * 16),
        7 + i % 4 * 2.0,
        math.sin(a) * (680 + i % 4 * 14),
      );
      final nearest = project(p);
      if (nearest.squaredDistance <
          math.pow(widthAt(nearest.frame.s) / 2 + 22, 2))
        continue;
      final block = WorldObstacle(
        p,
        V3(16 + i % 3 * 5.0, 14 + i % 4 * 4.0, 19),
        color: [0xffe0b240, 0xff4279ae, 0xffbb4c46, 0xff4e927d][i % 4],
      );
      scenery.add(block);
      obstacles.add(WorldObstacle(block.center, block.size, visible: false));
    }
    if (!tiled && !outdoor) {
      obstacles.add(
        const WorldObstacle(V3(790, 55, 380), V3(70, 110, 130), visible: false),
      );
    }
    if (room == 'BANHEIRO') {
      obstacles.addAll(const [
        WorldObstacle(V3(100, 36, 590), V3(460, 72, 190), visible: false),
        WorldObstacle(V3(710, 50, 20), V3(150, 100, 170), visible: false),
        WorldObstacle(V3(-710, 43, 220), V3(110, 86, 90), visible: false),
      ]);
    }
    if (room == 'COZINHA') {
      obstacles.addAll(const [
        WorldObstacle(V3(50, 60, 620), V3(640, 120, 170), visible: false),
        WorldObstacle(V3(735, 135, 30), V3(140, 270, 160), visible: false),
        WorldObstacle(V3(-735, 55, 50), V3(150, 110, 220), visible: false),
      ]);
    }
    if (room == 'SALA') {
      obstacles.addAll(const [
        WorldObstacle(V3(60, 50, 630), V3(500, 100, 160), visible: false),
        WorldObstacle(V3(740, 50, 20), V3(120, 100, 320), visible: false),
      ]);
      for (final x in [-465.0, -295.0]) {
        for (final z in [-5.0, 85.0]) {
          obstacles.add(
            WorldObstacle(V3(x, 32, z), const V3(7, 64, 7), visible: false),
          );
        }
      }
    }
    if (room == 'GARAGEM') {
      obstacles.add(
        const WorldObstacle(V3(-30, 46, 560), V3(211, 92, 71), visible: false),
      );
      obstacles.add(
        const WorldObstacle(V3(-720, 40, 380), V3(76, 80, 76), visible: false),
      );
      obstacles.add(
        const WorldObstacle(V3(730, 60, -50), V3(52, 120, 100), visible: false),
      );
    }
    if (room == 'ARCADE') {
      for (var i = 0; i < 5; i++) {
        obstacles.add(
          WorldObstacle(
            V3(-230 + i * 110.0, 63, 630),
            const V3(72, 126, 64),
            visible: false,
          ),
        );
      }
    }
    if (room == 'QUARTO') {
      obstacles.add(
        const WorldObstacle(
          V3(180, 75, 600),
          V3(500, 150, 210),
          visible: false,
        ),
      );
      for (final x in [-750.0, -550.0]) {
        for (final z in [490.0, 610.0]) {
          obstacles.add(
            WorldObstacle(V3(x, 55, z), const V3(6, 110, 6), visible: false),
          );
        }
      }

      obstacles.add(
        const WorldObstacle(V3(96, 28, 245), V3(178, 56, 103), visible: false),
      );
      obstacles.add(
        const WorldObstacle(V3(-238, 20, -100), V3(66, 40, 52), visible: false),
      );
      for (final x in [-150.0, -30.0]) {
        for (final z in [241.0, 290.0]) {
          obstacles.add(
            WorldObstacle(V3(x, 48, z), const V3(4, 96, 4), visible: false),
          );
        }
      }
    }
    populateRoom(this);
    if (!openArena) {
      buildRaceCourse(this);
      populateTrackside(this);
    }
  }

  TrackFrame at(double distance) {
    final s = wrap(distance, length);
    var low = 0, high = frames.length - 1;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (frames[mid].s <= s) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    final a = frames[low], b = frames[(low + 1) % frames.length];
    final span = (low + 1 == frames.length ? length : b.s) - a.s;
    final t = span < .00001 ? 0.0 : (s - a.s) / span;
    final f = a.forward.lerp(b.forward, t).unit;
    final r0 = a.right.lerp(b.right, t);
    final r = (r0 - f * r0.dot(f)).unit;
    return TrackFrame(a.p.lerp(b.p, t), r, f.cross(r).unit, f, s);
  }

  TrackProjection project(V3 p) {
    // Collision solver passes often query the exact same immutable position.
    // This cache is identity based, bounded and never rounds world coordinates.
    final previous = _projectionPoints[p];
    if (previous != null) return previous;
    final cx = (p.x / 64).floor(), cz = (p.z / 64).floor();
    final key = (cx, cz);
    var candidates = _projectionCells[key];
    if (candidates == null) {
      final ordered = <int>{};
      for (var x = cx - 1; x <= cx + 1; x++) {
        for (var z = cz - 1; z <= cz + 1; z++) {
          for (final i in _grid[(x, z)] ?? const <int>{}) {
            ordered.add(i);
            ordered.add((i - 1) % frames.length);
          }
        }
      }
      candidates = ordered.isEmpty ? _projectionFallback : ordered.toList();
      if (_projectionCells.length >= 256) {
        _projectionCells.remove(_projectionCells.keys.first);
      }
      _projectionCells[key] = candidates;
    }
    var best = double.infinity, bestS = 0.0;
    for (final i in candidates) {
      final a = frames[i], b = frames[(i + 1) % frames.length];
      final vx = b.p.x - a.p.x, vy = b.p.y - a.p.y, vz = b.p.z - a.p.z;
      final t =
          (((p.x - a.p.x) * vx + (p.y - a.p.y) * vy + (p.z - a.p.z) * vz) /
                  math.max(.000001, vx * vx + vy * vy + vz * vz))
              .clamp(0.0, 1.0);
      final dx = p.x - (a.p.x + vx * t),
          dy = p.y - (a.p.y + vy * t),
          dz = p.z - (a.p.z + vz * t);
      final ds = dx * dx + dy * dy + dz * dz;
      if (ds < best) {
        best = ds;
        bestS = a.s + t * ((i + 1 == frames.length ? length : b.s) - a.s);
      }
    }
    final f = at(bestS), delta = p - f.p;
    final result = TrackProjection(
      f,
      delta.dot(f.right),
      delta.dot(f.up),
      best,
    );
    if (_projectionPoints.length >= 128) {
      _projectionPoints.remove(_projectionPoints.keys.first);
    }
    return _projectionPoints[p] = result;
  }

  double floorRampHeight(V3 position) {
    for (final r in ramps) {
      final d = position - r.frame.p,
          z = d.dot(r.frame.forward),
          x = d.dot(r.frame.right);
      if (z >= -r.length / 2 && z <= r.length / 2 && x.abs() < r.width / 2)
        return (z / r.length + .5) * r.height;
    }
    return 0;
  }

  bool isFloor(double distance) => at(distance).p.y < .38;
  double widthAt(double distance) {
    // Expansion races use the original 46-unit toy ribbon on the floor too.
    // Do not inflate their floor corridors to 96 units on straight sectors.
    // Legacy room tracks and all battle arenas keep their original behavior.
    if (outdoor && !openArena) return width;
    if (!isFloor(distance)) return width;
    final curvature =
        (at(distance + 3).forward - at(distance - 3).forward).length / 6;
    return math.min(96.0, math.max(46.0, 1.65 / math.max(.0001, curvature)));
  }

  TrackFrame checkpoint(int index) => at(index / checkpointCount * length);
  bool isBoost(double distance, double lane) {
    if (lane.abs() >= .75) return false;
    final s = wrap(distance, length);
    return [.14, .34, .73].any((f) => wrap(s / length - f, 1) < .012) ||
        loops.any((loop) => s > loop.start - 82 && s < loop.start - 62);
  }

  bool isShortcut(double distance, double lane) => false;
  double get rampLine => length * .73;
  bool isRamp(double distance) => false;
  double rampHeight(double distance) => 0;
}

List<TrackSpec> createTracks() {
  final bedroom = <V3>[
    const V3(-620, 6, -580),
    const V3(-620, 6, -440),
    const V3(-620, 6, -280),
  ];
  for (var i = 1; i <= 24; i++) {
    final t = i / 24, a = t * math.pi * 2;
    bedroom.add(
      V3(
        -620 + 70 * t * t * (3 - 2 * t),
        6 + 62 * (1 - math.cos(a)),
        -280 + 62 * math.sin(a),
      ),
    );
  }
  bedroom.addAll(const [
    V3(-550, 6, -170),
    V3(-540, 3, -70),
    V3(-520, .16, 40),
    V3(-430, .16, 240),
    V3(-240, .16, 330),
    V3(-60, .16, 300),
    V3(-80, .16, 160),
    V3(-240, .16, 80),
    V3(-210, .16, -90),
    V3(0, .16, -130),
    V3(150, .16, -40),
    V3(220, .16, 130),
    V3(190, .16, 290),
    V3(330, .16, 400),
    V3(540, .16, 360),
    V3(600, 18, 160),
    V3(580, 30, -60),
    V3(440, 24, -250),
    V3(240, 6, -280),
    V3(180, .16, -450),
    V3(60, .16, -620),
    V3(-160, .16, -650),
    V3(-400, 3, -650),
    V3(-580, 6, -640),
  ]);
  return [
    TrackSpec(
      'bedroom',
      'QUARTO EM CHAMAS',
      'Loop, curvas e corrida livre pelo chão do quarto.',
      'QUARTO',
      0xffff7238,
      0xff645042,
      0xff374257,
      bedroom,
      loopControls: (2, 26),
    ),
    TrackSpec(
      'garage',
      'GARAGEM ELÉTRICA',
      'Chicanes, blocos e pontes entre ferramentas.',
      'GARAGEM',
      0xff37d8c3,
      0xff37414b,
      0xff253244,
      circuitRoute('garage'),
    ),
    TrackSpec(
      'arcade',
      'ARCADE NOTURNO',
      'Curvas técnicas e slalom no salão neon.',
      'ARCADE',
      0xffb48aff,
      0xff171d35,
      0xff161c30,
      circuitRoute('arcade'),
    ),
    TrackSpec(
      'bedroom_sprint',
      'ENTRE A CAMA E A MESA',
      'Sprint pelo chão, cotovelos e uma ponte longa.',
      'QUARTO',
      0xffffa34a,
      0xff89684d,
      0xff485b75,
      circuitRoute('bedroom_sprint'),
    ),
    TrackSpec(
      'garage_drift',
      'OFICINA DO DRIFT',
      'Curvas encadeadas e slalom entre as ferramentas.',
      'GARAGEM',
      0xff48d6b9,
      0xff6d737b,
      0xff364357,
      circuitRoute('garage_drift'),
    ),
    TrackSpec(
      'arcade_neon',
      'NEON EM ALTA',
      'Pontes iluminadas e um miolo de curvas técnicas.',
      'ARCADE',
      0xffe071d4,
      0xff262945,
      0xff1d2844,
      circuitRoute('arcade_neon'),
    ),
    TrackSpec(
      'bathroom',
      'MARÉ DE AZULEJOS',
      'Banheira gigante, piso liso e curvas de precisão.',
      'BANHEIRO',
      0xff64dce3,
      0xffa8d2d5,
      0xff86b3c6,
      circuitRoute('bathroom'),
    ),
    TrackSpec(
      'bathroom_hairpin',
      'CURVA DO RALO',
      'Retornos fechados no chão do banheiro.',
      'BANHEIRO',
      0xff90eee9,
      0xffc8ded8,
      0xff83a7b6,
      circuitRoute('bathroom_hairpin'),
    ),
    TrackSpec(
      'kitchen',
      'COZINHA A TODO VAPOR',
      'Corra entre a geladeira, o balcão e as rampas.',
      'COZINHA',
      0xffffc45d,
      0xffd2c7a6,
      0xffa4b7bd,
      circuitRoute('kitchen'),
    ),
    TrackSpec(
      'kitchen_chicane',
      'RECEITA DE VELOCIDADE',
      'Chicanes pelo piso e travessias em pista laranja.',
      'COZINHA',
      0xffff8662,
      0xffcbbf9b,
      0xff9db9bd,
      circuitRoute('kitchen_chicane'),
    ),
    TrackSpec(
      'living',
      'RALI DA SALA',
      'Passe sob a mesa e contorne o sofá.',
      'SALA',
      0xffe6bf7b,
      0xff8e6d4f,
      0xff768a9d,
      circuitRoute('living'),
    ),
    TrackSpec(
      'living_grand',
      'GRANDE PRÊMIO DO SOFÁ',
      'Uma volta longa pela sala, com freadas fortes.',
      'SALA',
      0xffffae6a,
      0xff93704d,
      0xff8293a0,
      circuitRoute('living_grand'),
    ),
    TrackSpec(
      'bedroom_library',
      'CÂNION DOS LIVROS',
      'Ponte diagonal, corredores de livros e retornos entre brinquedos.',
      'QUARTO',
      0xfff3a847,
      0xff81644c,
      0xff48536c,
      circuitRoute('bedroom_library'),
    ),
    TrackSpec(
      'garage_switchyard',
      'PÁTIO DAS FERRAMENTAS',
      'Cotovelos, uma passagem elevada e disputa no piso da oficina.',
      'GARAGEM',
      0xff55dac4,
      0xff5a6470,
      0xff29394d,
      circuitRoute('garage_switchyard'),
    ),
    TrackSpec(
      'bathroom_aqueduct',
      'AQUEDUTO DE ESPUMA',
      'Cruzamento em ponte, curvas largas e freadas sobre os azulejos.',
      'BANHEIRO',
      0xff83e6f1,
      0xffbedbdd,
      0xff91b5c7,
      circuitRoute('bathroom_aqueduct'),
    ),
    TrackSpec(
      'kitchen_island',
      'VOLTA DA ILHA',
      'Um miolo em espiral e uma travessia alta entre as bancadas.',
      'COZINHA',
      0xffffcf69,
      0xffd7c8a5,
      0xff9db3bd,
      circuitRoute('kitchen_island'),
    ),
    TrackSpec(
      'living_slalom',
      'ZIGUE-ZAGUE DAS ALMOFADAS',
      'Curvas alternadas pelo chão e uma reta de retorno elevada.',
      'SALA',
      0xffe4ab76,
      0xff957357,
      0xff788ca1,
      circuitRoute('living_slalom'),
    ),
    TrackSpec(
      'arcade_technical',
      'VÓRTICE DOS FLIPERAMAS',
      'Ponte central e uma sequência de mudanças de direção no neon.',
      'ARCADE',
      0xffda89ed,
      0xff20243d,
      0xff19203c,
      circuitRoute('arcade_technical'),
    ),
    ...createLoopTracks(),
    ...createExpansionTracks(),
  ];
}
