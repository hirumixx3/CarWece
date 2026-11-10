import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'game/content.dart';
import 'desktop/intro_screen_desktop.dart';
import 'desktop/platform_kind.dart';
import 'game/engine.dart';
import 'game/renderer.dart';
import 'platform.dart';
import 'ui/race_screen.dart';
import 'ui/widgets.dart';
import 'ui/gpu_view.dart';
import 'ui/battle_menu.dart';
import 'ui/intro_screen.dart';
import 'ui/online_screen.dart';

const carWeceVersion = String.fromEnvironment(
  'CARWECE_VERSION_NAME',
  defaultValue: '1.2.0',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (isWindowsDesktop) MediaKit.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const CarWeceApp());
}

class CarWeceApp extends StatelessWidget {
  final GameStore? store;
  final bool showIntro;
  const CarWeceApp({super.key, this.store, this.showIntro = true});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CarWece',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: ink,
      colorScheme: const ColorScheme.dark(
        primary: orange,
        secondary: cyan,
        surface: panel,
      ),
      textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'RushBody'),
      sliderTheme: const SliderThemeData(
        activeTrackColor: orange,
        thumbColor: orange,
        inactiveTrackColor: Color(0xff34435c),
        trackHeight: 4,
      ),
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 500),
      ),
    ),
    home: showIntro ? _LaunchFlow(store: store) : RushShell(store: store),
  );
}

class _LaunchFlow extends StatefulWidget {
  final GameStore? store;
  const _LaunchFlow({this.store});
  @override
  State<_LaunchFlow> createState() => _LaunchFlowState();
}

class _LaunchFlowState extends State<_LaunchFlow> {
  bool completed = false;
  @override
  Widget build(BuildContext context) => completed
      ? RushShell(store: widget.store)
      : isWindowsDesktop
      ? DesktopIntroScreen(onCompleted: () => setState(() => completed = true))
      : IntroScreen(onCompleted: () => setState(() => completed = true));
}

class RushShell extends StatefulWidget {
  final GameStore? store;
  const RushShell({super.key, this.store});
  @override
  State<RushShell> createState() => _RushShellState();
}

class _RushShellState extends State<RushShell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final GameStore store;
  late final List<TrackSpec> tracks;
  late final Ticker ticker;
  double phase = 0;
  String page = 'home', returnPage = 'home';
  int trackIndex = 0, garageIndex = 0, round = 0;
  String selectedRoom = 'TODOS';
  String garageClass = 'TODAS', garageCategory = 'TODOS';
  bool garageBrazilOnly = false;
  List<int> get visibleGarageCars =>
      filterCarCollection(
        performanceClass: garageClass,
        category: garageCategory,
        brazilOnly: garageBrazilOnly,
      )..sort((a, b) {
        final ca = cars[a], cb = cars[b];
        final byClass = carPerformanceClasses
            .indexOf(ca.performanceClass)
            .compareTo(carPerformanceClasses.indexOf(cb.performanceClass));
        if (byClass != 0) return byClass;
        final byCategory = ca.modelCategory.compareTo(cb.modelCategory);
        return byCategory != 0 ? byCategory : ca.name.compareTo(cb.name);
      });
  void changeGarageFilter(VoidCallback update) {
    store.tap();
    setState(() {
      update();
      final visible = visibleGarageCars;
      if (visible.isNotEmpty && !visible.contains(garageIndex))
        garageIndex = visible.first;
    });
  }

  List<int> cupRoute = [0, 1, 2];
  List<int> get visibleTracks => [
    for (var i = 0; i < tracks.length; i++)
      if (selectedRoom == 'TODOS' || tracks[i].room == selectedRoom) i,
  ];
  List<int> get selectedCup => <int>{
    trackIndex,
    ...visibleTracks,
    ...List.generate(tracks.length, (i) => i),
  }.where((i) => store.trackUnlocked(tracks[i])).take(3).toList();
  RaceMode mode = RaceMode.quick;
  List<ArenaSpec>? _arenas;
  List<ArenaSpec> get arenas => _arenas ??= createBattleArenas();
  int arenaIndex = 0;
  bool freeRoam = false;
  RaceEngine? race;
  RaceResult? result;
  final Map<String, int> cupPoints = {};
  bool quitting = false;
  Duration _lastAudio = Duration.zero;
  Duration _lastMenuFrame = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store = widget.store ?? GameStore();
    tracks = createTracks();
    store.addListener(_onStore);
    if (!store.ready) unawaited(store.load());
    ticker = createTicker((elapsed) {
      if (!mounted || page == 'race' || page == 'online') return;
      if (elapsed - _lastMenuFrame < const Duration(microseconds: 33333))
        return;
      _lastMenuFrame = elapsed;
      setState(() {
        phase = elapsed.inMilliseconds / 1000;
      });
      if (elapsed - _lastAudio > const Duration(seconds: 1)) {
        _lastAudio = elapsed;
        unawaited(store.audio());
      }
    })..start();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ticker.dispose();
    store.removeListener(_onStore);
    WidgetsBinding.instance.removeObserver(this);
    if (widget.store == null) store.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!ticker.isActive) {
        _lastMenuFrame = Duration.zero;
        _lastAudio = Duration.zero;
        ticker.start();
      }
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
      );
    } else {
      ticker.stop();
      unawaited(store.save());
    }
  }

  void go(String target) {
    if (target == 'home' && page != 'home') {
      // A real navigation event: redraw once, not on menu animation/audio ticks.
      unawaited(store.audio(event: 'tap', enterMenu: true));
    } else {
      store.tap();
    }
    setState(() {
      page = target;
      if (target == 'garage') {
        garageIndex = store.selectedCar;
        final visible = visibleGarageCars;
        if (visible.isNotEmpty && !visible.contains(garageIndex))
          garageIndex = visible.first;
      }
    });
  }

  void settings() {
    returnPage = page;
    go('settings');
  }

  void start({bool nextRound = false}) {
    if ((!nextRound && !store.trackUnlocked(tracks[trackIndex])) ||
        (mode == RaceMode.championship && selectedCup.length < 3))
      return;
    if (!nextRound) {
      round = 0;
      cupPoints.clear();
      cupRoute = selectedCup;
    }
    final t = mode == RaceMode.championship
        ? tracks[cupRoute[round]]
        : tracks[trackIndex];
    race = RaceEngine(
      track: t,
      car: cars[store.selectedCar],
      mode: mode,
      difficulty: store.settings.difficulty,
      seed: DateTime.now().millisecondsSinceEpoch,
      previousChampionshipOrder: nextRound && mode == RaceMode.championship
          ? result?.standings.map((s) => s.name).toList()
          : null,
    );
    race!.autoAccelerate = store.settings.autoAccelerate;
    race!.sensitivity = store.settings.sensitivity;
    result = null;
    store.tap();
    setState(() => page = 'race');
  }

  void finish(RaceResult value) {
    if (race is BattleEngine) {
      store.recordBattle(race! as BattleEngine);
      setState(() {
        result = value;
        page = 'battleResult';
      });
      return;
    }
    store.record(race!.track, value, mode);
    if (mode == RaceMode.championship) {
      const scores = [10, 7, 5, 3, 2, 1];
      final order = value.standings;
      for (var i = 0; i < order.length; i++) {
        cupPoints[order[i].name] = (cupPoints[order[i].name] ?? 0) + scores[i];
      }
    }
    setState(() {
      result = value;
      page = 'result';
    });
  }

  void startBattle() {
    race = BattleEngine(
      arena: arenas[arenaIndex],
      car: cars[store.selectedCar],
      difficulty: store.settings.battleDifficulty,
      freeRoam: freeRoam,
      seed: DateTime.now().millisecondsSinceEpoch,
    );
    race!.sensitivity = store.settings.sensitivity;
    // Combat and exploration always require the accelerator.
    race!.autoAccelerate = false;
    result = null;
    store.tap();
    setState(() => page = 'race');
  }

  Future<void> back() async {
    if (page == 'home') {
      final answer = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Encerrar por hoje?', style: display(30)),
          content: const Text('Seu progresso já está salvo.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('VOLTAR'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('SAIR'),
            ),
          ],
        ),
      );
      if (answer == true) {
        await store.save();
        await SystemNavigator.pop();
      }
    } else if (page != 'race') {
      go(page == 'settings' ? returnPage : 'home');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (page == 'online')
      return OnlineScreen(
        store: store,
        tracks: tracks,
        arenas: arenas,
        onBack: () => go('home'),
      );
    if (page == 'race')
      return RaceScreen(
        key: ValueKey(race),
        race: race!,
        store: store,
        onFinish: finish,
        onExit: () => go('home'),
      );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(back());
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: TechBackground(phase))),
            SafeArea(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: 1000,
                    height: 540,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(35, 24, 35, 18),
                      child: switch (page) {
                        'battleSelect' => BattleSelection(
                          arenas: arenas,
                          selected: arenaIndex,
                          freeRoam: freeRoam,
                          car: cars[store.selectedCar],
                          difficulty: store.settings.battleDifficulty,
                          onDifficulty: (value) {
                            store.settings.battleDifficulty = value;
                            store.changed();
                          },
                          victories: store.battleWins,
                          onSelect: (v) => setState(() => arenaIndex = v),
                          onMode: (v) => setState(() => freeRoam = v),
                          onBack: () => go('home'),
                          onStart: startBattle,
                        ),
                        'battleResult' => BattleResults(
                          battle: race! as BattleEngine,
                          onAgain: startBattle,
                          onArenas: () => go('battleSelect'),
                          onHome: () => go('home'),
                        ),
                        'select' => selection(),
                        'garage' => garage(),
                        'settings' => settingsPage(),
                        'help' => help(),
                        'credits' => credits(),
                        'records' => records(),
                        'result' => results(),
                        _ => home(),
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget coinRushBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xff202b40),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xff43516a)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.toll_rounded, color: Color(0xffffc568), size: 18),
        const SizedBox(width: 7),
        Text('${store.coins}', style: body(15)),
        const SizedBox(width: 14),
        const Icon(Icons.star_rounded, color: orange, size: 18),
        Text('${store.stars}/${tracks.length * 3}', style: body(13)),
      ],
    ),
  );

  Widget home() => Column(
    children: [
      Row(
        children: [
          const RushBadge('VERSÃO $carWeceVersion • 3D', color: orange),
          const Spacer(),
          Text('PILOTO 01', style: body(11, color: muted, spacing: 2)),
          const SizedBox(width: 18),
          coinRushBadge(),
          const SizedBox(width: 12),
          IconButton(
            onPressed: settings,
            tooltip: 'Configurações',
            icon: const Icon(Icons.settings_outlined, color: cream, size: 26),
          ),
        ],
      ),
      Expanded(
        child: Row(
          children: [
            SizedBox(
              width: 375,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'PEQUENA ESCALA. GRANDES CORRIDAS.',
                    style: body(10, color: muted, spacing: 2.2),
                  ),
                  const SizedBox(height: 13),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('CarWece', style: display(88, color: orange)),
                  ),
                  const SizedBox(height: 17),
                  SizedBox(
                    width: 300,
                    child: RushButton(
                      'CORRER',
                      icon: Icons.sports_motorsports_rounded,
                      primary: true,
                      onTap: () => go('select'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 300,
                    child: RushButton(
                      'JOGAR ONLINE',
                      key: const ValueKey('enter-online'),
                      icon: Icons.wifi_rounded,
                      primary: true,
                      color: cyan,
                      onTap: () => go('online'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 300,
                    child: RushButton(
                      'BATALHA / MUNDO ABERTO',
                      compact: true,
                      icon: Icons.local_fire_department_rounded,
                      onTap: () => go('battleSelect'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      RushButton(
                        'GARAGEM',
                        compact: true,
                        icon: Icons.garage_outlined,
                        onTap: () => go('garage'),
                      ),
                      const SizedBox(width: 10),
                      RushButton(
                        'RECORDES',
                        compact: true,
                        icon: Icons.emoji_events_outlined,
                        onTap: () => go('records'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Container(width: 28, height: 2, color: orange),
                      const SizedBox(width: 10),
                      Text(
                        'SUA PRÓXIMA CORRIDA COMEÇA AQUI',
                        style: body(10, color: muted, spacing: 1.7),
                      ),
                    ],
                  ),
                  Expanded(
                    child: GpuGarageView(
                      car: cars[store.selectedCar],
                      angle: -.65 + math.sin(phase * .3) * .12,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cars[store.selectedCar].tag,
                              style: body(10, color: cyan, spacing: 2),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              cars[store.selectedCar].name,
                              style: display(40),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${(store.selectedCar + 1).toString().padLeft(2, '0')} / ${cars.length.toString().padLeft(2, '0')}',
                        style: display(25, color: muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(height: 1, color: const Color(0xff344158)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.bolt, color: orange, size: 20),
                      const SizedBox(width: 7),
                      Text('${tracks.length} CIRCUITOS', style: body(11)),
                      const SizedBox(width: 26),
                      const Icon(Icons.loop_rounded, color: cyan, size: 20),
                      const SizedBox(width: 7),
                      Text('LOOP VERTICAL', style: body(11)),
                    ],
                  ),
                  const SizedBox(height: 25),
                ],
              ),
            ),
          ],
        ),
      ),
      Row(
        children: [
          Text('HIRUMISU', style: body(10, color: muted, spacing: 2.5)),
          const SizedBox(width: 12),
          Text(
            'MINIATURAS. VELOCIDADE. CAOS.',
            style: body(9, color: const Color(0xff73829c), spacing: 1),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => go('help'),
            child: Text('COMO JOGAR', style: body(11)),
          ),
          TextButton(
            onPressed: () => go('credits'),
            child: Text('CRÉDITOS', style: body(11)),
          ),
          IconButton(
            onPressed: () => unawaited(back()),
            tooltip: 'Sair',
            icon: const Icon(Icons.power_settings_new, color: muted, size: 20),
          ),
        ],
      ),
    ],
  );

  Widget selection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeader(
        'ENCONTRE A SUA LINHA',
        'ESCOLHA A CORRIDA',
        () => go('home'),
        trailing: coinRushBadge(),
      ),
      Row(
        children: [
          for (final m in RaceMode.values) ...[
            Expanded(
              child: RushButton(
                switch (m) {
                  RaceMode.quick => 'CORRIDA RÁPIDA',
                  RaceMode.championship => 'CAMPEONATO',
                  RaceMode.timeTrial => 'CONTRARRELÓGIO',
                },
                compact: true,
                primary: mode == m,
                onTap: () {
                  store.tap();
                  setState(() => mode = m);
                },
              ),
            ),
            if (m != RaceMode.values.last) const SizedBox(width: 10),
          ],
        ],
      ),
      const SizedBox(height: 10),
      Text(
        mode == RaceMode.championship
            ? 'Copa: ${selectedCup.map((i) => tracks[i].room).join(' → ')}. Três etapas com pontos por posição.'
            : mode == RaceMode.timeTrial
            ? 'Só você e o relógio. Três voltas para estabelecer um novo recorde.'
            : 'Seis carros. Três voltas. Use o turbo e os itens para chegar na frente.',
        style: body(12, color: muted),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 37,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final room in [
              'TODOS',
              'QUARTO',
              'GARAGEM',
              'BANHEIRO',
              'COZINHA',
              'SALA',
              'ARCADE',
              ...expansionBiomes.keys,
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: ValueKey('room-$room'),
                  label: Text(
                    room,
                    style: body(11, color: selectedRoom == room ? ink : cream),
                  ),
                  selected: selectedRoom == room,
                  selectedColor: cyan,
                  backgroundColor: panel,
                  showCheckmark: false,
                  onSelected: (_) {
                    store.tap();
                    setState(() {
                      selectedRoom = room;
                      if (!visibleTracks.contains(trackIndex))
                        trackIndex = visibleTracks.first;
                    });
                  },
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 9),
      Expanded(
        child: LayoutBuilder(
          builder: (context, bounds) => ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: visibleTracks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 13),
            itemBuilder: (context, index) => SizedBox(
              width: visibleTracks.length <= 2
                  ? (bounds.maxWidth - 13) / 2
                  : (bounds.maxWidth - 26) / 3,
              child: trackCard(visibleTracks[index]),
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          IconButton(
            onPressed: () => cycleCar(-1),
            tooltip: 'Carro anterior',
            icon: const Icon(Icons.chevron_left, color: cream),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SEU CARRO', style: body(9, color: muted, spacing: 1.5)),
              Text(cars[store.selectedCar].name, style: display(22)),
            ],
          ),
          IconButton(
            onPressed: () => cycleCar(1),
            tooltip: 'Próximo carro',
            icon: const Icon(Icons.chevron_right, color: cream),
          ),
          const Spacer(),
          RushButton(
            'GARAGEM',
            compact: true,
            onTap: () {
              returnPage = 'select';
              go('garage');
            },
          ),
          const SizedBox(width: 12),
          RushButton(
            store.trackUnlocked(tracks[trackIndex])
                ? 'VAMOS CORRER'
                : 'REQUER ${tracks[trackIndex].requiredStars} ★',
            primary: true,
            icon: Icons.arrow_forward_rounded,
            onTap: store.trackUnlocked(tracks[trackIndex]) ? start : null,
          ),
        ],
      ),
    ],
  );
  void cycleCar(int delta) {
    var i = store.selectedCar;
    do {
      i = (i + delta) % cars.length;
    } while (!store.ownedCars.contains(cars[i].id));
    store.selectedCar = i;
    store.changed();
    store.tap();
  }

  Widget trackCard(int i) {
    final t = tracks[i],
        selected = mode == RaceMode.championship
            ? selectedCup.contains(i)
            : trackIndex == i;
    final unlocked = store.trackUnlocked(t);
    return Material(
      color: selected ? const Color(0xff283045) : const Color(0xff141f34),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          store.tap();
          setState(() => trackIndex = i);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? Color(t.accent) : const Color(0xff33415a),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  RushBadge(
                    mode == RaceMode.championship && selectedCup.contains(i)
                        ? '${t.room} • ETAPA ${selectedCup.indexOf(i) + 1}'
                        : t.room,
                    color: Color(t.accent),
                  ),
                  const Spacer(),
                  if (!unlocked)
                    const Icon(Icons.lock_rounded, size: 18, color: muted)
                  else if (selected)
                    Icon(Icons.check_circle, size: 18, color: Color(t.accent)),
                ],
              ),
              Expanded(
                child: Center(
                  child: CustomPaint(
                    size: const Size(180, 126),
                    painter: TrackMapPainter(t, color: Color(t.accent)),
                  ),
                ),
              ),
              Text(t.name, style: display(25)),
              const SizedBox(height: 5),
              Text(
                unlocked ? t.subtitle : store.trackRequirement(t),
                maxLines: 2,
                style: body(11, color: unlocked ? muted : orange),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '${(t.length).round()} m • 3 VOLTAS',
                    style: body(10, color: Color(t.accent)),
                  ),
                  const Spacer(),
                  for (var j = 0; j < (store.medals[t.id] ?? 0); j++)
                    const Icon(Icons.star_rounded, size: 14, color: orange),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget garage() {
    final visible = visibleGarageCars;
    final car = cars[garageIndex],
        owned = store.ownedCars.contains(car.id),
        chosen = garageIndex == store.selectedCar;
    return Column(
      children: [
        SectionHeader(
          'ENCONTRE SEU ESTILO',
          'GARAGEM',
          () => go(returnPage == 'select' ? 'select' : 'home'),
          trailing: coinRushBadge(),
        ),
        SizedBox(
          height: 44,
          child: Row(
            children: [
              Text('CLASSE', style: body(10, color: muted)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                key: const ValueKey('garage-class-filter'),
                value: garageClass,
                menuMaxHeight: 240,
                dropdownColor: panel,
                style: body(11),
                underline: const SizedBox.shrink(),
                items: [
                  for (final value in ['TODAS', ...carPerformanceClasses])
                    DropdownMenuItem(
                      value: value,
                      child: Text(value == 'TODAS' ? 'TODAS' : 'CLASSE $value'),
                    ),
                ],
                onChanged: (value) {
                  if (value != null)
                    changeGarageFilter(() => garageClass = value);
                },
              ),
              const SizedBox(width: 20),
              Text('MODELO', style: body(10, color: muted)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                key: const ValueKey('garage-category-filter'),
                value: garageCategory,
                menuMaxHeight: 240,
                dropdownColor: panel,
                style: body(11),
                underline: const SizedBox.shrink(),
                items: [
                  for (final value in ['TODOS', ...carModelCategories])
                    DropdownMenuItem(value: value, child: Text(value)),
                ],
                onChanged: (value) {
                  if (value != null)
                    changeGarageFilter(() => garageCategory = value);
                },
              ),
              const SizedBox(width: 14),
              FilterChip(
                key: const ValueKey('garage-brazil-filter'),
                label: Text('BRASILEIROS', style: body(10)),
                selected: garageBrazilOnly,
                onSelected: (value) =>
                    changeGarageFilter(() => garageBrazilOnly = value),
              ),
              const Spacer(),
              Text(
                '${visible.length} / ${cars.length} CARROS',
                style: body(10, color: muted),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Limpar filtros',
                icon: const Icon(Icons.filter_alt_off_outlined, size: 19),
                onPressed: () => changeGarageFilter(() {
                  garageClass = 'TODAS';
                  garageCategory = 'TODOS';
                  garageBrazilOnly = false;
                }),
              ),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Text(
                    'NENHUM CARRO NESTA COMBINAÇÃO',
                    style: display(24),
                  ),
                )
              : Row(
                  children: [
                    SizedBox(
                      width: 210,
                      child: ListView(
                        key: const ValueKey('garage-car-list'),
                        children: [
                          for (final i in visible) ...[
                            if (i == visible.first ||
                                cars[visible[visible.indexOf(i) - 1]]
                                        .performanceClass !=
                                    cars[i].performanceClass ||
                                cars[visible[visible.indexOf(i) - 1]]
                                        .modelCategory !=
                                    cars[i].modelCategory)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(3, 12, 0, 8),
                                child: Text(
                                  'CLASSE ${cars[i].performanceClass} • ${cars[i].modelCategory}',
                                  style: body(10, color: cyan),
                                ),
                              ),
                            SizedBox(
                              height: 96,
                              child: Material(
                                color: garageIndex == i
                                    ? const Color(0xff2b3b56)
                                    : panel,
                                borderRadius: BorderRadius.circular(9),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(9),
                                  onTap: () {
                                    store.tap();
                                    setState(() => garageIndex = i);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color: Color(cars[i].color),
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                cars[i].name,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: display(20),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                store.ownedCars.contains(
                                                      cars[i].id,
                                                    )
                                                    ? 'NA SUA COLEÇÃO'
                                                    : '${cars[i].cost} MOEDAS',
                                                style: body(9, color: muted),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (i == store.selectedCar)
                                          const Icon(
                                            Icons.check_circle,
                                            size: 16,
                                            color: cyan,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (i != cars.length - 1) const SizedBox(height: 9),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: GpuGarageView(
                              car: car,
                              angle: -.7 + math.sin(phase * .3) * .24,
                            ),
                          ),
                          RushBadge(car.tag, color: Color(car.color)),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 250,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              key: const ValueKey('garage-car-details'),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${(garageIndex + 1).toString().padLeft(2, '0')} / COLEÇÃO • CLASSE ${car.performanceClass}',
                                    style: body(10, color: muted, spacing: 1.7),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(car.name, style: display(38)),
                                  const SizedBox(height: 12),
                                  Text(
                                    '${car.modelCategory} • ${car.description}',
                                    style: body(13, color: muted),
                                  ),
                                  const SizedBox(height: 14),
                                  StatBar(
                                    'VELOCIDADE',
                                    car.speed / 105,
                                    color: Color(car.color),
                                  ),
                                  StatBar(
                                    'ACELERAÇÃO',
                                    car.acceleration / 43,
                                    color: Color(car.color),
                                  ),
                                  StatBar(
                                    'DIREÇÃO',
                                    car.handling / 1.45,
                                    color: Color(car.color),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    owned
                                        ? '${car.tier} • NA SUA COLEÇÃO'
                                        : store.carRequirement(car),
                                    maxLines: 2,
                                    style: body(
                                      11,
                                      color: store.carEligible(car)
                                          ? cyan
                                          : orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: RushButton(
                              chosen
                                  ? 'SELECIONADO'
                                  : owned
                                  ? 'SELECIONAR'
                                  : store.carEligible(car)
                                  ? 'COMPRAR • ${car.cost}'
                                  : 'REQUER ${car.requiredStars} ★',
                              primary: !chosen,
                              compact: true,
                              icon: owned ? Icons.check : Icons.lock_open,
                              onTap:
                                  chosen || (!owned && !store.carEligible(car))
                                  ? null
                                  : () {
                                      if (!store.buyCar(car)) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Ganhe moedas completando corridas.',
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      store.selectedCar = garageIndex;
                                      store.changed();
                                      store.tap();
                                    },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pódio: 1º = 3 ★ • 2º = 2 ★ • 3º = 1 ★ por pista. Ganhe estrelas e moedas para ampliar a coleção.',
          style: body(11, color: muted),
        ),
      ],
    );
  }

  Widget settingsPage() {
    final s = store.settings;
    Widget tile(String title, Widget control, {String? note}) => Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: body(13)),
          if (note != null) Text(note, style: body(10, color: muted)),
          control,
        ],
      ),
    );
    Widget range(
      double value,
      double min,
      double max,
      ValueChanged<double> onChanged,
    ) => SizedBox(
      height: 37,
      child: Slider(
        value: value,
        min: min,
        max: max,
        onChanged: (v) {
          onChanged(v);
          store.changed();
          unawaited(store.audio());
        },
      ),
    );
    Widget toggle(String title, bool value, ValueChanged<bool> onChanged) =>
        Row(
          children: [
            Expanded(child: Text(title, style: body(13))),
            Switch(
              value: value,
              activeThumbColor: orange,
              onChanged: (v) {
                onChanged(v);
                store.changed();
              },
            ),
          ],
        );
    Widget chips(
      List<String> values,
      List<String> labels,
      String value,
      ValueChanged<String> change,
    ) => Row(
      children: [
        for (var i = 0; i < values.length; i++) ...[
          Expanded(
            child: RushButton(
              labels[i],
              compact: true,
              primary: value == values[i],
              onTap: () {
                change(values[i]);
                store.changed();
                store.tap();
              },
            ),
          ),
          if (i < values.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
    return Column(
      children: [
        SectionHeader('DO SEU JEITO', 'CONFIGURAÇÕES', () => go(returnPage)),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(23),
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView(
                    children: [
                      Text(
                        'ÁUDIO & CONTROLES',
                        style: display(26, color: orange),
                      ),
                      const SizedBox(height: 18),
                      tile(
                        'Música • ${(s.music * 100).round()}%',
                        range(s.music, 0, 1, (v) => s.music = v),
                      ),
                      tile(
                        'Efeitos & motor • ${(s.effects * 100).round()}%',
                        range(s.effects, 0, 1, (v) => s.effects = v),
                      ),
                      toggle(
                        'Aceleração automática',
                        s.autoAccelerate,
                        (v) => s.autoAccelerate = v,
                      ),
                      toggle('Vibração', s.vibration, (v) => s.vibration = v),
                      const SizedBox(height: 8),
                      tile(
                        'Sensibilidade • ${s.sensitivity.toStringAsFixed(1)}×',
                        range(s.sensitivity, .5, 1.6, (v) => s.sensitivity = v),
                      ),
                      RushButton(
                        'EDITOR DE HUD',
                        compact: true,
                        icon: Icons.tune_rounded,
                        onTap: () {
                          final preview = RaceEngine(
                            track: tracks[trackIndex],
                            car: cars[store.selectedCar],
                            mode: RaceMode.timeTrial,
                          )..countdown = 0;
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (editorContext) => RaceScreen(
                                race: preview,
                                store: store,
                                hudEditorOnly: true,
                                onFinish: (_) =>
                                    Navigator.of(editorContext).pop(),
                                onExit: () => Navigator.of(editorContext).pop(),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Mova cada botão, mapa e indicador. Ajuste os tamanhos e salve seu layout.',
                        style: body(10, color: muted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(23),
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView(
                    children: [
                      Text('CORRIDA & VÍDEO', style: display(26, color: cyan)),
                      const SizedBox(height: 18),
                      tile(
                        'Dificuldade',
                        chips(
                          ['easy', 'normal', 'hard'],
                          ['FÁCIL', 'NORMAL', 'DIFÍCIL'],
                          s.difficulty,
                          (v) => s.difficulty = v,
                        ),
                        note: OpponentTuning.forDifficulty(
                          s.difficulty,
                        ).description,
                      ),
                      tile(
                        'Qualidade gráfica',
                        chips(
                          ['auto', 'low', 'medium', 'high'],
                          ['AUTO', 'BAIXA', 'MÉDIA', 'ALTA'],
                          s.quality,
                          (v) => s.quality = v,
                        ),
                        note:
                            'AUTO ajusta a resolução durante a corrida para priorizar a fluidez. Os modelos e a física são preservados.',
                      ),
                      tile(
                        'Distância da câmera',
                        range(
                          s.cameraDistance,
                          .8,
                          1.4,
                          (v) => s.cameraDistance = v,
                        ),
                      ),
                      toggle('Mostrar FPS', s.showFps, (v) => s.showFps = v),
                      const SizedBox(height: 10),
                      Text(
                        'As alterações são salvas automaticamente.',
                        style: body(11, color: muted),
                      ),
                      if (store.saveError != null)
                        Text(store.saveError!, style: body(11, color: orange)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget help() => Column(
    children: [
      SectionHeader('PRIMEIRA VEZ NA PISTA?', 'COMO JOGAR', () => go('home')),
      Expanded(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(25),
                color: panel,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    hint(
                      Icons.swap_horiz_rounded,
                      'ACELERADOR / DIREÇÃO',
                      'Segure ACELERAR e faça as curvas em ← ou →. Deslize o dedo entre as setas. Você dirige livremente e pode errar a curva.',
                    ),
                    hint(
                      Icons.bolt_rounded,
                      'TURBO',
                      'Segure TURBO para gastar a carga azul. Ela recarrega com o tempo.',
                    ),
                    hint(
                      Icons.blur_circular_rounded,
                      'DRIFT INDEPENDENTE',
                      'Segure DRIFT e vire. Deslize o dedo entre ACELERAR e DRIFT sem soltar; o pedal mantém a aceleração. Solte para recuperar a aderência.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(25),
                color: panel,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    hint(
                      Icons.inventory_2_outlined,
                      '13 PODERES',
                      'Cubos dão armas. Granada quica, IMPACTO empurra, ESPINHOS afetam os pneus e REPARO remove danos. SUPER exige turbo cheio; mísseis abrem portões.',
                    ),
                    hint(
                      Icons.alt_route_rounded,
                      'CHÃO DO QUARTO',
                      'Siga o traçado e passe pelos checkpoints. Use FREIO nas curvas fechadas e entre no loop com velocidade.',
                    ),
                    hint(
                      Icons.sports_score_rounded,
                      'CHEGADA',
                      'Complete 3 voltas. Ganhe moedas, libere carros e tente vencer as três etapas do campeonato.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 15),
      Text(
        'Aceleração manual vem ativada. A assistência automática é opcional nas configurações.',
        style: body(13, color: muted),
      ),
    ],
  );
  Widget hint(IconData icon, String title, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: orange, size: 30),
      const SizedBox(width: 15),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: display(23)),
            const SizedBox(height: 6),
            Text(text, style: body(13, color: muted)),
          ],
        ),
      ),
    ],
  );

  Widget credits() => Column(
    children: [
      SectionHeader('FEITO PARA ACELERAR', 'CRÉDITOS', () => go('home')),
      Expanded(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('CarWece', style: display(77, color: orange)),
                const SizedBox(height: 12),
                Text('por hirumisu', style: display(35)),
                const SizedBox(height: 12),
                Text(
                  'Marcos Nascimento (Sage Corp.)',
                  style: display(25, color: cyan),
                ),
                const SizedBox(height: 25),
                Text(
                  'Versão $carWeceVersion • ${cars.length} carros • ${tracks.length} pistas • Android',
                  style: body(16),
                ),
                const SizedBox(height: 10),
                Text(
                  'Modelagem própria de carros reais. Flutter + OpenGL ES 3.0.',
                  style: body(13, color: muted),
                ),
                const SizedBox(height: 6),
                Text(
                  'Fontes Barlow e Barlow Condensed • SIL Open Font License',
                  style: body(12, color: muted),
                ),
                const SizedBox(height: 25),
                const RushBadge('OFFLINE + ONLINE • SEM ANÚNCIOS'),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Widget records() => Column(
    children: [
      SectionHeader(
        'CADA CENTÉSIMO CONTA',
        'SEUS RECORDES',
        () => go('home'),
        trailing: coinRushBadge(),
      ),
      Row(
        children: [
          recordStat('${store.races}', 'CORRIDAS'),
          const SizedBox(width: 15),
          recordStat('${store.wins}', 'VITÓRIAS'),
          const SizedBox(width: 15),
          recordStat(
            '${cars.where((c) => store.ownedCars.contains(c.id)).length}/${cars.length}',
            'CARROS',
          ),
        ],
      ),
      const SizedBox(height: 18),
      Expanded(
        child: ListView(
          children: [
            for (final t in tracks)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 220,
                      child: Text(t.name, style: display(25)),
                    ),
                    for (final m in RaceMode.values)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(switch (m) {
                              RaceMode.quick => 'CORRIDA',
                              RaceMode.championship => 'CAMPEONATO',
                              RaceMode.timeTrial => 'CONTRARRELÓGIO',
                            }, style: body(9, color: muted)),
                            const SizedBox(height: 6),
                            Text(
                              store.records.containsKey(store.recordKey(t, m))
                                  ? formatTime(
                                      store.records[store.recordKey(t, m)]!,
                                    )
                                  : '—',
                              style: display(27, color: cyan),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ],
  );
  Widget recordStat(String value, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(value, style: display(45, color: orange)),
          const SizedBox(width: 15),
          Text(label, style: body(12, color: muted, spacing: 1.5)),
        ],
      ),
    ),
  );

  Widget results() {
    final r = result!, cupDone = mode == RaceMode.championship && round == 2;
    final cup = cupPoints.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final win = cupDone ? cup.first.key == 'VOCÊ' : r.position == 1;
    final order = r.standings;
    final winnerName = cupDone ? cup.first.key : order.first.name;
    final winnerCar = order.firstWhere((e) => e.name == winnerName).car;
    final podiumNames = cupDone
        ? cup.map((e) => e.key).toList()
        : order.map((e) => e.name).toList();
    return Column(
      children: [
        SectionHeader(
          cupDone ? 'TRÊS ETAPAS. UM CAMPEÃO.' : race!.track.name,
          cupDone
              ? 'CAMPEONATO CONCLUÍDO'
              : win
              ? 'VITÓRIA!'
              : 'CORRIDA CONCLUÍDA',
          () => go('home'),
          trailing: coinRushBadge(),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          cupDone
                              ? '${cup.indexWhere((e) => e.key == 'VOCÊ') + 1}º'
                              : '${r.position}º',
                          style: display(80, color: orange),
                        ),
                        const SizedBox(width: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SUA POSIÇÃO NA CHEGADA.', style: display(24)),
                            Text(
                              'Vencedor: $winnerName',
                              style: body(12, color: muted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Expanded(
                      child: GpuGarageView(
                        car: winnerCar,
                        angle: -.6 + math.sin(phase * .3) * .1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          for (
                            var i = 0;
                            i < math.min(3, podiumNames.length);
                            i++
                          )
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                color: podiumNames[i] == 'VOCÊ'
                                    ? orange.withValues(alpha: .22)
                                    : panel,
                                child: Text(
                                  '${i + 1}º  ${podiumNames[i]}',
                                  textAlign: TextAlign.center,
                                  style: display(
                                    19,
                                    color: i == 0 ? orange : cream,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        resultTile('TEMPO TOTAL', formatTime(r.time)),
                        resultTile('MELHOR VOLTA', formatTime(r.bestLap)),
                        resultTile('MOEDAS', '+${r.coins}'),
                        resultTile('CARREIRA', '+${store.lastStarsEarned} ★'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 26),
              SizedBox(
                width: 285,
                child: Container(
                  padding: const EdgeInsets.all(19),
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mode == RaceMode.championship
                            ? 'PONTUAÇÃO DA COPA'
                            : 'CLASSIFICAÇÃO',
                        style: display(25),
                      ),
                      const SizedBox(height: 15),
                      Expanded(
                        child: ListView(
                          children: [
                            if (mode == RaceMode.championship)
                              for (var i = 0; i < cup.length; i++)
                                rankingRow(
                                  i + 1,
                                  cup[i].key,
                                  '${cup[i].value} pts',
                                )
                            else
                              for (var i = 0; i < order.length; i++)
                                rankingRow(
                                  i + 1,
                                  order[i].name,
                                  order[i].finishTime != null
                                      ? formatTime(order[i].finishTime!)
                                      : '${order[i].remaining.round()} m restantes',
                                ),
                          ],
                        ),
                      ),
                      Text(
                        '${r.hits} ACERTOS  /  ${r.boosts} IMPULSOS',
                        style: body(10, color: muted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            RushButton(
              'MENU PRINCIPAL',
              compact: true,
              onTap: () => go('home'),
            ),
            const SizedBox(width: 12),
            if (mode == RaceMode.championship && round < 2)
              RushButton(
                'PRÓXIMA ETAPA',
                primary: true,
                icon: Icons.arrow_forward,
                onTap: () {
                  round++;
                  start(nextRound: true);
                },
              )
            else
              RushButton(
                'CORRER DE NOVO',
                primary: true,
                icon: Icons.replay,
                onTap: start,
              ),
          ],
        ),
      ],
    );
  }

  Widget rankingRow(int position, String name, String value) => Container(
    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
    decoration: BoxDecoration(
      color: name == 'VOCÊ' ? const Color(0xff3b3b3a) : Colors.transparent,
      borderRadius: BorderRadius.circular(5),
    ),
    child: Row(
      children: [
        Text('$position', style: display(22, color: orange)),
        const SizedBox(width: 13),
        Expanded(child: Text(name, style: body(13))),
        Text(value, style: body(11, color: muted)),
      ],
    ),
  );
  Widget resultTile(String name, String value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: body(9, color: muted, spacing: 1)),
        const SizedBox(height: 5),
        Text(value, style: display(32, color: cyan)),
      ],
    ),
  );
}
