import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../game/content.dart';
import '../game/engine.dart';
import '../game/renderer.dart';
import '../platform.dart';
import '../desktop/key_bindings.dart';
import '../desktop/platform_kind.dart';
import '../hud_layout.dart';
import 'widgets.dart';
import 'gpu_view.dart';
import 'music_sheet.dart';
import 'battle_widgets.dart';

class RaceScreen extends StatefulWidget {
  final RaceEngine race;
  final GameStore store;
  final ValueChanged<RaceResult> onFinish;
  final VoidCallback onExit;
  final bool hudEditorOnly;
  const RaceScreen({
    super.key,
    required this.race,
    required this.store,
    required this.onFinish,
    required this.onExit,
    this.hudEditorOnly = false,
  });
  @override
  State<RaceScreen> createState() => _RaceScreenState();
}

class _RaceScreenState extends State<RaceScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker ticker;
  late final TrackScene scene = TrackScene(race.track);
  final frame = ValueNotifier<int>(0);
  final hudFrame = ValueNotifier<int>(0);
  double hudClock = 0;
  Duration? previous;
  double audioClock = 0, fps = 60;
  double? gpuFps;
  String? gpuDeviceInfo;
  bool gpuReady = false;
  bool sentResult = false, musicSheetOpen = false;
  final Set<String> held = {};
  final FocusNode keysFocus = FocusNode();
  int controlsEpoch = 0;
  bool editingHud = false, savingHud = false, toolsCollapsed = false;
  HudLayout? draftHud;
  String selectedHud = 'gas';
  Offset? toolsOffset;
  final Map<int, String> touchActions = {};
  RaceEngine get race => widget.race;
  GameStore get store => widget.store;
  BattleEngine? get battle =>
      race is BattleEngine ? race as BattleEngine : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(keyEvent);
    ticker = createTicker(tick);
    if (widget.hudEditorOnly) {
      editingHud = true;
      draftHud = store.settings.hud.copy();
      race.setPaused(true);
    } else {
      unawaited(store.audio(scene: battle != null ? 'battle' : 'race'));
      ticker.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(keyEvent);
    keysFocus.dispose();
    ticker.dispose();
    frame.dispose();
    hudFrame.dispose();
    unawaited(store.audio());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Windows reports transient non-resumed states while the window starts
    // and around focus changes; pausing on them left the race frozen with
    // dead controls until the player clicked back. Only Android pauses
    // from lifecycle events.
    if (isWindowsDesktop) return;
    if (state != AppLifecycleState.resumed && !race.paused && !race.finished)
      pause(true);
  }

  void tick(Duration elapsed) {
    if (!gpuReady) {
      previous = null;
      return;
    }
    final dt = previous == null
        ? 0.0
        : (elapsed - previous!).inMicroseconds / 1000000;
    previous = elapsed;
    if (dt > 0) fps = fps * .95 + (1 / dt).clamp(0, 120) * .05;
    race.update(dt);
    frame.value++;
    // Input listeners stay live at display cadence. Rebuild labels, map and
    // decoration at 30 Hz instead of rebuilding the entire HUD at 60/120 Hz.
    hudClock += dt;
    if (hudClock >= 1 / 30) {
      hudClock %= 1 / 30;
      hudFrame.value++;
    }
    audioClock += dt;
    String? event;
    if (race.events.isNotEmpty) {
      event = race.events.last;
      if (race.events.any((e) => ['bump', 'land', 'hit'].contains(e)))
        store.haptic();
      race.events.clear();
    }
    if (audioClock > .12 || event != null) {
      audioClock = 0;
      unawaited(
        store.audio(
          speed: race.player.speed / race.car.speed,
          racing: race.countdown <= 0 && !race.paused && !race.finished,
          scene: battle != null ? 'battle' : 'race',
          turbo: race.nitroActive,
          event: event,
        ),
      );
    }
    if (race.finished && !sentResult) {
      sentResult = true;
      ticker.stop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFinish(race.result!);
      });
    }
  }

  void pause(bool value) {
    held.clear();
    touchActions.clear();
    controlsEpoch++;
    race.setPaused(value);
    previous = null;
    if (value) {
      ticker.stop();
      unawaited(
        store.audio(
          scene: widget.hudEditorOnly
              ? 'menu'
              : (battle != null ? 'battle' : 'race'),
        ),
      );
    } else if (!ticker.isActive) {
      if (isWindowsDesktop) keysFocus.requestFocus();
      unawaited(
        store.audio(
          scene: battle != null ? 'battle' : 'race',
          racing: race.countdown <= 0,
        ),
      );
      ticker.start();
    }
    if (mounted) setState(() {});
  }

  Future<void> showMusic() async {
    if (musicSheetOpen || widget.hudEditorOnly) return;
    pause(true);
    musicSheetOpen = true;
    unawaited(store.soundtrack.refresh());
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: ink,
        constraints: const BoxConstraints(maxWidth: 760),
        builder: (_) => MusicSheet(store: store),
      );
    } finally {
      musicSheetOpen = false;
    }
  }

  Future<void> showArsenal() async {
    if (musicSheetOpen || battle == null) return;
    pause(true);
    musicSheetOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: ink,
        constraints: const BoxConstraints(maxWidth: 780),
        builder: (context) => SizedBox(
          height: math.min(610, MediaQuery.sizeOf(context).height * .94),
          child: BattleArmory(battle: battle, onSelected: () => frame.value++),
        ),
      );
    } finally {
      musicSheetOpen = false;
      if (mounted) setState(() {});
    }
  }

  bool keyEvent(KeyEvent event) {
    if (musicSheetOpen) return false;
    final settings = store.settings;
    bool bound(String action) => event.logicalKey == settings.keyFor(action);
    if (bound('pause') && event is KeyDownEvent) {
      if (editingHud) {
        finishHudEdit(false);
      } else {
        pause(!race.paused);
      }
      return true;
    }
    if (race.paused) return false;
    if (battle != null) {
      if (bound('item')) {
        input('item', event is! KeyUpEvent, source: 'key');
        if (event is KeyDownEvent) battle!.useItem();
        return true;
      }
      if (event is KeyDownEvent) {
        if (bound('weapon')) {
          battle!.cycleWeapon();
          return true;
        }
        if (bound('target')) {
          battle!.cycleTarget();
          return true;
        }
        if (bound('arsenal')) {
          unawaited(showArsenal());
          return true;
        }
      }
    } else {
      if (bound('item') && event is KeyDownEvent) {
        race.useItem();
        return true;
      }
      if (bound('super') && event is KeyDownEvent) {
        race.superchargeItem();
        return true;
      }
    }
    if (bound('reset') && event is KeyDownEvent) {
      held.clear();
      touchActions.clear();
      controlsEpoch++;
      race.resetPlayer();
      frame.value++;
      return true;
    }
    final name = bound('left')
        ? 'left'
        : bound('right')
        ? 'right'
        : bound('gas')
        ? 'gas'
        : bound('brake')
        ? 'brake'
        : bound('drift')
        ? 'drift'
        : bound('boost')
        ? 'boost'
        : '';
    if (name.isEmpty) return false;
    input(name, event is! KeyUpEvent, source: 'key${event.logicalKey.keyId}');
    return true;
  }

  void input(String name, bool down, {String source = 'touch'}) {
    if (race.paused || race.finished) return;
    final token = '$source:$name';
    if (down) {
      held.add(token);
    } else {
      held.remove(token);
    }
    bool pressed(String action) => held.any((key) => key.endsWith(':$action'));
    race.steering =
        (pressed('right') ? 1.0 : 0.0) - (pressed('left') ? 1.0 : 0.0);
    race.brake = pressed('brake');
    race.accelerating = pressed('gas');
    race.boosting = pressed('boost');
    race.driftPressed = pressed('drift');
    if (battle != null) battle!.triggerHeld = pressed('item');
    race.remoteAction?.call('controls');
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) {
        if (editingHud) {
          finishHudEdit(false);
        } else {
          pause(!race.paused);
        }
      }
    },
    child: KeyboardListener(
      focusNode: keysFocus,
      autofocus: isWindowsDesktop,
      onKeyEvent: (event) => keyEvent(event),
      child: Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: GpuRaceView(
                race: race,
                fallbackScene: () => scene,
                quality: store.settings.quality,
                cameraDistance: store.settings.cameraDistance,
                repaint: frame,
                onFps: (value) => gpuFps = value,
                onDeviceInfo: (value) => gpuDeviceInfo = value,
                onReady: () {
                  gpuReady = true;
                  previous = null;
                  frame.value++;
                },
                onUnavailable: () {
                  gpuReady = false;
                  previous = null;
                  frame.value++;
                },
              ),
            ),
          ),
          Positioned.fill(
            child: ValueListenableBuilder<int>(
              valueListenable: frame,
              builder: (context, value, child) {
                final density = race.player.smokeExposure.clamp(0.0, 1.0);
                if (density <= 0) return const SizedBox.shrink();
                return IgnorePointer(
                  key: const ValueKey('smoke-veil'),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          const Color(
                            0xff8e989e,
                          ).withValues(alpha: .62 * density),
                          const Color(
                            0xff46525e,
                          ).withValues(alpha: .46 * density),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = math
                      .min(
                        constraints.maxHeight / 470,
                        constraints.maxWidth / 940,
                      )
                      .clamp(.62, 1.5);
                  return ValueListenableBuilder(
                    valueListenable: hudFrame,
                    builder: (context, value, _) => hud(
                      scale,
                      Size(constraints.maxWidth, constraints.maxHeight),
                    ),
                  );
                },
              ),
            ),
          ),
          if (editingHud)
            Positioned.fill(
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, c) =>
                      editorTools(Size(c.maxWidth, c.maxHeight)),
                ),
              ),
            ),
          if (race.paused && !editingHud)
            Positioned.fill(
              child: Container(
                color: const Color(0xd10a1021),
                child: Center(
                  child: SingleChildScrollView(
                    child: SizedBox(
                      width: 330,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const RushBadge(
                            'RESPIRA. A PISTA ESPERA.',
                            color: cyan,
                          ),
                          const SizedBox(height: 18),
                          Text('PAUSADO', style: display(62)),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: 280,
                            child: RushButton(
                              'CONTINUAR',
                              primary: true,
                              icon: Icons.play_arrow,
                              onTap: () => pause(false),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: 280,
                            child: RushButton(
                              'EDITAR HUD',
                              compact: true,
                              icon: Icons.tune_rounded,
                              onTap: beginHudEdit,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: 280,
                            child: RushButton(
                              'MÚSICAS',
                              compact: true,
                              icon: Icons.queue_music_rounded,
                              onTap: showMusic,
                            ),
                          ),
                          if (battle != null) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: 280,
                              child: RushButton(
                                'ARSENAL',
                                compact: true,
                                icon: Icons.inventory_2_outlined,
                                onTap: showArsenal,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          SizedBox(
                            width: 280,
                            child: RushButton(
                              'VOLTAR AO MENU',
                              compact: true,
                              icon: Icons.home_outlined,
                              onTap: confirmExit,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'A corrida só avança quando você voltar.',
                            style: body(11, color: muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
    ),
  );

  Future<void> confirmExit() async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          battle == null ? 'Abandonar corrida?' : 'Sair da arena?',
          style: display(30),
        ),
        content: Text(
          battle == null
              ? 'A corrida atual não renderá moedas ou recordes.'
              : 'A sessão atual não renderá recompensa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CONTINUAR AQUI'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('MENU PRINCIPAL'),
          ),
        ],
      ),
    );
    if (exit == true && mounted) widget.onExit();
  }

  void beginHudEdit() {
    pause(true);
    setState(() {
      editingHud = true;
      draftHud = store.settings.hud.copy();
      selectedHud = 'gas';
      toolsOffset = null;
    });
  }

  Future<void> finishHudEdit(bool save) async {
    if (savingHud) return;
    if (save) {
      setState(() => savingHud = true);
      final previousLayout = store.settings.hud;
      store.settings.hud = draftHud!.copy();
      await store.save();
      if (!mounted) return;
      if (store.saveError != null) {
        store.settings.hud = previousLayout;
        setState(() => savingHud = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível salvar o HUD. Tente novamente.'),
          ),
        );
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      editingHud = false;
      savingHud = false;
      draftHud = null;
    });
    if (widget.hudEditorOnly) widget.onExit();
  }

  void touchAction(int pointer, String id, bool down) {
    final source = 'finger$pointer';
    switch (id) {
      case 'gas':
        input('gas', down, source: source);
      case 'drift':
        input('gas', down, source: source);
        input('drift', down, source: source);
      case 'left':
        input('left', down, source: source);
      case 'right':
        input('right', down, source: source);
      case 'brake':
        input('brake', down, source: source);
      case 'boost':
        input('boost', down, source: source);
      case 'item':
        if (battle != null) {
          input('item', down, source: source);
          if (down) battle!.useItem();
        }
    }
  }

  void routeTouch(
    PointerEvent event,
    Map<String, Rect> rects, {
    bool start = false,
    bool end = false,
  }) {
    // On Windows the touch buttons are hidden and every command is on the
    // keyboard; mouse clicks must not drive the car through invisible
    // button rects.
    if (isWindowsDesktop && !editingHud) return;
    if (editingHud || race.paused || race.finished) return;
    final old = touchActions[event.pointer];
    if (end) {
      if (old != null) touchAction(event.pointer, old, false);
      touchActions.remove(event.pointer);
    } else {
      if (!start && old == null) return;
      final id =
          [
                'left',
                'right',
                'brake',
                'gas',
                'drift',
                'boost',
                if (battle != null) 'item',
              ]
              .where((id) => rects[id]!.contains(event.localPosition))
              .lastOrNull ??
          '';
      if (start && id.isEmpty) return;
      if (id != old) {
        if (old != null) touchAction(event.pointer, old, false);
        if (id.isNotEmpty) touchAction(event.pointer, id, true);
      }
      touchActions[event.pointer] = id;
    }
    frame.value++;
  }

  Widget editorTools(Size screen) {
    final width = math.min(430.0, screen.width * .48),
        height = toolsCollapsed ? 104.0 : 216.0;
    final original =
        toolsOffset ??
        Offset((screen.width - width) / 2, (screen.height - height) / 2);
    final offset = Offset(
      original.dx.clamp(0, math.max(0, screen.width - width)),
      original.dy.clamp(0, math.max(0, screen.height - height)),
    );
    final scale = math
        .min(screen.height / 470, screen.width / 940)
        .clamp(.62, 1.5);
    final zoom = draftHud!.items[selectedHud]?.scale ?? 1;
    return Stack(
      children: [
        Positioned(
          left: offset.dx,
          top: offset.dy,
          width: width,
          child: Material(
            key: const ValueKey('hud-editor-tools'),
            elevation: 8,
            color: const Color(0xf2142238),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    dragStartBehavior: DragStartBehavior.down,
                    onPanUpdate: (e) =>
                        setState(() => toolsOffset = offset + e.delta),
                    child: Row(
                      children: [
                        const Icon(Icons.drag_indicator, size: 19, color: cyan),
                        Text('EDITOR HUD', style: display(22, color: cyan)),
                        const Spacer(),
                        IconButton(
                          tooltip: toolsCollapsed
                              ? 'Expandir painel'
                              : 'Minimizar painel',
                          onPressed: () =>
                              setState(() => toolsCollapsed = !toolsCollapsed),
                          icon: Icon(
                            toolsCollapsed
                                ? Icons.expand_more
                                : Icons.expand_less,
                            size: 21,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!toolsCollapsed) ...[
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButton<String>(
                            key: const ValueKey('hud-element-picker'),
                            value: selectedHud,
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: [
                              for (final e in hudLabels.entries)
                                DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value, style: body(13)),
                                ),
                            ],
                            onChanged: (id) {
                              if (id != null) setState(() => selectedHud = id);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(zoom * 100).round()}%',
                          style: body(14, color: cyan),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 30,
                      child: Slider(
                        key: const ValueKey('hud-size-slider'),
                        value: zoom,
                        min: .65,
                        max: 1.8,
                        onChanged: (v) => setState(
                          () => draftHud!.resize(selectedHud, v, screen, scale),
                        ),
                      ),
                    ),
                    Text(
                      'Arraste os elementos para mover. O título acima também move este painel.',
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: body(10, color: muted),
                    ),
                    const SizedBox(height: 5),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: savingHud
                            ? null
                            : () => setState(() => draftHud = HudLayout()),
                        child: const Text('PADRÃO'),
                      ),
                      TextButton(
                        onPressed: savingHud
                            ? null
                            : () => finishHudEdit(false),
                        child: const Text('CANCELAR'),
                      ),
                      FilledButton(
                        onPressed: savingHud ? null : () => finishHudEdit(true),
                        child: Text(savingHud ? 'SALVANDO' : 'SALVAR'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget hud(double s, Size screen) {
    final layout = editingHud ? draftHud! : store.settings.hud;
    final rects = {
      for (final id in hudLabels.keys) id: layout.rect(id, screen, s),
    };
    final pose = race.driverFrame(race.player);
    final to = race.navigationFrame(race.player).p - pose.p;
    final angle = math.atan2(to.dot(pose.right), to.dot(pose.forward));
    bool pressed(String action) => held.any((key) => key.endsWith(':$action'));
    Widget slot(String id, Widget child) {
      final base = HudLayout.defaultRect(id, screen, s), rect = rects[id]!;
      Widget result = SizedBox(
        width: rect.width,
        height: rect.height,
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(width: base.width, height: base.height, child: child),
        ),
      );
      if (editingHud)
        result = GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onTap: () => setState(() => selectedHud = id),
          onPanStart: (_) => setState(() => selectedHud = id),
          onPanUpdate: (event) =>
              setState(() => draftHud!.move(id, event.delta, screen, s)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selectedHud == id
                  ? const Color(0x1537d8c3)
                  : Colors.transparent,
              border: Border.all(
                color: selectedHud == id ? cyan : const Color(0x99687b94),
                width: selectedHud == id ? 2 : 1,
              ),
            ),
            child: IgnorePointer(child: result),
          ),
        );
      return Positioned.fromRect(
        rect: rect,
        child: SizedBox(
          key: ValueKey('hud-$id'),
          width: rect.width,
          height: rect.height,
          child: result,
        ),
      );
    }

    Widget tag(String label, String value) => Container(
      padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 9 * s),
      decoration: BoxDecoration(
        color: const Color(0xc90c1629),
        borderRadius: BorderRadius.circular(9 * s),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: body(9 * s, color: muted, spacing: 1.8)),
          Text(value, style: display(27 * s)),
        ],
      ),
    );
    Widget control(String id, String label, IconData icon, Color color) {
      final base = HudLayout.defaultRect(id, screen, s);
      return IgnorePointer(
        child: HoldControl(
          key: ValueKey('control-$label'),
          label: label,
          icon: icon,
          width: base.width,
          height: base.height,
          color: color,
          resetToken: controlsEpoch,
          activeOverride: pressed(
            id == 'boost'
                ? 'boost'
                : id == 'gas'
                ? 'gas'
                : id,
          ),
          onChanged: (_) {},
        ),
      );
    }

    final parts = <Widget>[
      if (race.player.hitFlash > 0)
        Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(
              color: Color.fromRGBO(255, 70, 30, race.player.hitFlash * .15),
            ),
          ),
        ),
      slot(
        'position',
        Container(
          padding: EdgeInsets.all(7 * s),
          decoration: BoxDecoration(
            color: const Color(0xe1152035),
            borderRadius: BorderRadius.circular(10 * s),
            border: Border.all(color: const Color(0xff52617a)),
          ),
          child: FittedBox(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${battle?.human.kills ?? race.position}',
                  style: display(51 * s, color: orange),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 3 * s, bottom: 5 * s),
                  child: Text(
                    battle == null ? '/ ${race.bots.length + 1}' : 'ELIM.',
                    style: body(17 * s, color: muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      slot(
        'lap',
        tag(
          battle == null ? 'VOLTA' : 'VIVOS',
          battle == null
              ? '${race.lap} / ${race.laps}'
              : '${battle!.living.length} / ${race.drivers.length}',
        ),
      ),
      slot(
        'clock',
        tag(
          battle == null
              ? 'TEMPO'
              : battle!.freeRoam
              ? 'EXPLORAR'
              : 'RESTANTE',
          formatTime(
            battle == null || battle!.freeRoam ? race.time : battle!.remaining,
          ),
        ),
      ),
      if (!isWindowsDesktop || editingHud)
        slot(
          'pause',
        Semantics(
          label: 'Pausar corrida',
          button: true,
          child: Material(
            color: const Color(0xe11a2943),
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              onTap: () => pause(true),
              borderRadius: BorderRadius.circular(9),
              child: Icon(Icons.pause_rounded, color: cream, size: 28 * s),
            ),
          ),
        ),
      ),
      slot(
        'title',
        IgnorePointer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                battle == null
                    ? race.track.room
                    : '${battle!.freeRoam ? "EXPLORAR" : "BATALHA"} • VIDA ${battle!.human.health.ceil()} / 100',
                style: body(10 * s, color: cyan, spacing: 2.4),
              ),
              SizedBox(height: 5 * s),
              Text(
                race.track.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: display(17 * s),
              ),
              SizedBox(height: 8 * s),
              LinearProgressIndicator(
                key: battle == null
                    ? null
                    : const ValueKey('battle-player-health'),
                value: battle == null
                    ? (race.player.routeS / race.track.length).clamp(0, 1)
                    : battle!.human.health / 100,
                minHeight: (battle == null ? 3 : 6) * s,
                color: battle == null
                    ? Color(race.track.accent)
                    : battle!.human.health > 35
                    ? const Color(0xff8de39c)
                    : orange,
                backgroundColor: const Color(0x9020324b),
              ),
            ],
          ),
        ),
      ),
      slot(
        'map',
        Container(
          padding: EdgeInsets.all(6 * s),
          decoration: BoxDecoration(
            color: const Color(0x80101b2d),
            borderRadius: BorderRadius.circular(10),
          ),
          child: CustomPaint(
            painter: battle != null
                ? BattleMapPainter(battle!.arena, battle: battle)
                : TrackMapPainter(
                    race.track,
                    race: race,
                    color: const Color(0xfff7ac73),
                  ),
          ),
        ),
      ),
      slot(
        'guide',
        battle != null
            ? BattleRivals(
                battle: battle!,
                scale: s,
                onTarget: () => frame.value++,
                onReset: () {
                  held.clear();
                  touchActions.clear();
                  controlsEpoch++;
                  race.resetPlayer();
                  setState(() {});
                },
              )
            : Column(
                key: const ValueKey('checkpoint-guide'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CHECKPOINT ${race.player.nextCheckpoint == 0 ? TrackSpec.checkpointCount : race.player.nextCheckpoint} / ${TrackSpec.checkpointCount}',
                    style: body(10 * s, color: cyan),
                  ),
                  SizedBox(height: 4 * s),
                  Row(
                    children: [
                      Transform.rotate(
                        angle: angle,
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          color: cyan,
                          size: 24 * s,
                        ),
                      ),
                      SizedBox(width: 5 * s),
                      Text(
                        race.track.isFloor(race.player.routeS)
                            ? 'TRECHO NO CHÃO'
                            : 'PISTA',
                        style: body(10 * s, color: cream),
                      ),
                    ],
                  ),
                  if (!isWindowsDesktop)
                    TextButton.icon(
                      onPressed: () {
                        held.clear();
                        touchActions.clear();
                        controlsEpoch++;
                        race.resetPlayer();
                        setState(() {});
                      },
                    icon: Icon(Icons.replay_rounded, size: 17 * s),
                    label: Text(
                      'REPOR CARRO',
                      style: body(10 * s, color: cream),
                    ),
                  ),
                ],
              ),
      ),
      if (!isWindowsDesktop || editingHud)
        slot(
          'left',
          control('left', 'ESQUERDA', Icons.arrow_back_rounded, cream),
        ),
      if (!isWindowsDesktop || editingHud)
        slot(
          'right',
          control('right', 'DIREITA', Icons.arrow_forward_rounded, cream),
        ),
      if (!isWindowsDesktop || editingHud)
        slot(
          'brake',
          control(
            'brake',
            'FREIO',
            Icons.blur_circular_rounded,
            const Color(0xffe6a17d),
          ),
        ),
      if (!isWindowsDesktop || editingHud)
        slot(
          'gas',
          control(
            'gas',
            'ACELERAR',
            Icons.keyboard_double_arrow_up_rounded,
            const Color(0xffa3e983),
          ),
        ),
      if (!isWindowsDesktop || editingHud)
        slot('drift', control('drift', 'DRIFT', Icons.gesture_rounded, orange)),
      if (!isWindowsDesktop || editingHud)
        slot('boost', control('boost', 'TURBO', Icons.bolt_rounded, cyan)),
      if ((battle != null || editingHud) && (!isWindowsDesktop || editingHud))
        slot(
          'target',
          Semantics(
            label: 'Trocar mira para outro carro',
            button: true,
            child: GestureDetector(
              key: const ValueKey('battle-cycle-target'),
              onTap: () {
                battle?.cycleTarget();
                hudFrame.value++;
              },
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xd01a3042),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: const Color(0xff42ff67),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.my_location,
                      size: 21 * s,
                      color: const Color(0xff42ff67),
                    ),
                    Text(
                      'TROCAR MIRA',
                      style: body(7 * s, color: const Color(0xff42ff67)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      if ((battle != null ||
              editingHud ||
              (race.item != null && !race.itemEnhanced)) &&
          (!isWindowsDesktop || editingHud))
        slot(
          'super',
          GestureDetector(
            onTap: battle != null ? battle!.cycleWeapon : race.superchargeItem,
            onLongPress: battle != null ? showArsenal : null,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xc91a3042),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: race.nitro >= 100 ? cyan : muted),
              ),
              child: Text(
                battle != null ? 'TROCAR ARMA' : 'SUPER 100%',
                style: body(8 * s, color: race.nitro >= 100 ? cyan : muted),
              ),
            ),
          ),
        ),
      if (!isWindowsDesktop || editingHud)
        slot(
          'item',
          battle != null
            ? IgnorePointer(
                child: Container(
                  key: const ValueKey('battle-fire'),
                  decoration: BoxDecoration(
                    color: !battle!.human.armed
                        ? const Color(0xa91a2335)
                        : battle!.triggerHeld
                        ? const Color(0xffbf6a3e)
                        : const Color(0xff23495a),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: battle!.human.armed ? orange : muted,
                      width: 1.8,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.gps_fixed_rounded, color: cream, size: 22 * s),
                      Text('ATIRAR', style: body(9 * s)),
                      Text(
                        battle!.selectedWeapon == null
                            ? 'SEM PODER\nCOLETE NO MAPA'
                            : '${battle!.selectedWeapon!.name}\n×${battle!.selectedAmmo}',
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        style: body(6.7 * s, color: cyan),
                      ),
                    ],
                  ),
                ),
              )
            : Semantics(
                label: race.item == null
                    ? 'Sem item'
                    : 'Usar ${itemName(race.item!)}',
                button: true,
                child: GestureDetector(
                  onTap: race.useItem,
                  onLongPress: race.superchargeItem,
                  child: Container(
                    decoration: BoxDecoration(
                      color: race.item == null
                          ? const Color(0xa91a2335)
                          : const Color(0xc3237589),
                      borderRadius: BorderRadius.circular(16 * s),
                      border: Border.all(
                        color: race.item == null
                            ? const Color(0xff647189)
                            : cyan,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          switch (race.item) {
                            ItemType.missile => Icons.rocket_launch_rounded,
                            ItemType.shield => Icons.shield_outlined,
                            ItemType.oil => Icons.water_drop_rounded,
                            ItemType.nitro => Icons.bolt_rounded,
                            ItemType.mine => Icons.trip_origin_rounded,
                            ItemType.emp => Icons.radar_rounded,
                            ItemType.tesla => Icons.electric_bolt_rounded,
                            ItemType.ice => Icons.ac_unit_rounded,
                            ItemType.smoke => Icons.cloud_rounded,
                            ItemType.grenade => Icons.sports_baseball_rounded,
                            ItemType.shockwave => Icons.waves_rounded,
                            ItemType.repair => Icons.build_rounded,
                            ItemType.spikes => Icons.warning_amber_rounded,
                            ItemType.salvo => Icons.burst_mode_rounded,
                            ItemType.dreno => Icons.swap_horiz_rounded,
                            ItemType.fantasma => Icons.visibility_off_rounded,
                            null => Icons.inventory_2_outlined,
                          },
                          color: race.item == null ? muted : cream,
                          size: 29 * s,
                        ),
                        SizedBox(height: 3 * s),
                        Text(
                          race.item == null
                              ? 'ITEM'
                              : '${race.itemEnhanced ? 'SUPER ' : ''}${itemName(race.item!)} ×${race.itemCharges}',
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          style: body(
                            8 * s,
                            color: race.item == null ? muted : cream,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
      slot(
        'speed',
        IgnorePointer(
          child: CustomPaint(
            painter: SpeedGauge(race.speedKmh / 320, race.drifting),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${race.speedKmh.round()}', style: display(47 * s)),
                    Padding(
                      padding: EdgeInsets.only(bottom: 6 * s, left: 5 * s),
                      child: Text('km/h', style: body(10 * s, color: cream)),
                    ),
                  ],
                ),
                SizedBox(height: 5 * s),
                LinearProgressIndicator(
                  value: race.nitro / 100,
                  minHeight: 7 * s,
                  color: race.nitroActive ? cream : cyan,
                  backgroundColor: const Color(0xb91b2a41),
                ),
                SizedBox(height: 5 * s),
                Text(
                  race.player.stun > 0
                      ? 'ATINGIDO • RECUPERANDO'
                      : race.player.shield > 0
                      ? 'ESCUDO ${race.player.shield.ceil()}s'
                      : race.drifting
                      ? 'DRIFT • +TURBO'
                      : race.player.freezeTime > 0
                      ? 'CONGELADO'
                      : race.player.electricTime > 0
                      ? 'PANE ELÉTRICA'
                      : race.player.weaponLock > 0
                      ? 'EMP • ARMA BLOQUEADA'
                      : race.player.punctureTime > 0
                      ? 'PNEUS FURADOS ${race.player.punctureTime.ceil()}s'
                      : race.player.repairGlow > 0
                      ? 'CARRO REPARADO'
                      : race.drafting
                      ? 'VÁCUO • +TURBO'
                      : 'TURBO ${race.nitro.round()}%',
                  maxLines: 1,
                  style: body(9 * s, color: cyan),
                ),
              ],
            ),
          ),
        ),
      ),
      if (store.settings.showFps && !editingHud)
        Positioned(
          left: 18 * s,
          top: 310 * s,
          child: Text(
            gpuFps == null
                ? '${fps.round()} FPS UI'
                : '${gpuFps!.round()} FPS 3D${gpuDeviceInfo == null ? '' : ' • $gpuDeviceInfo'}',
            style: body(10 * s, color: cyan),
          ),
        ),
      if (race.messageLife > 0 && race.countdown <= 0 && !editingHud)
        Positioned(
          top: 95 * s,
          left: 140 * s,
          right: 140 * s,
          child: IgnorePointer(
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 20 * s,
                  vertical: 9 * s,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xc7152035),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(race.message, style: display(21 * s, color: cyan)),
              ),
            ),
          ),
        ),
      if (gpuReady && race.countdown > 0 && !editingHud)
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(race.track.name, style: display(26 * s)),
                  SizedBox(height: 5 * s),
                  Text(
                    '${race.countdown.ceil().clamp(1, 3)}',
                    style: display(120 * s, color: orange),
                  ),
                  Text(
                    'PREPARE-SE PARA ACELERAR',
                    style: body(12 * s, spacing: 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      if (race.time < 9 && race.countdown <= 0 && !editingHud)
        Positioned(
          left: 0,
          right: 0,
          bottom: 126 * s,
          child: IgnorePointer(
            child: Center(
              child: Text(
                isWindowsDesktop
                    ? battle != null
                          ? '${prettyKeyLabel(store.settings.keyFor('item'))} ATIRAR • ${prettyKeyLabel(store.settings.keyFor('weapon'))} TROCAR ARMA • ${prettyKeyLabel(store.settings.keyFor('target'))} TROCAR MIRA'
                          : '${prettyKeyLabel(store.settings.keyFor('gas'))} ACELERA • ${prettyKeyLabel(store.settings.keyFor('left'))}/${prettyKeyLabel(store.settings.keyFor('right'))} VIRA • ${prettyKeyLabel(store.settings.keyFor('drift'))} DRIFT • ${prettyKeyLabel(store.settings.keyFor('boost'))} TURBO'
                    : battle != null
                    ? 'SEGURE ATIRAR • TROCAR MIRA ALTERNA O ALVO • MIRA VERDE NO CARRO'
                    : race.autoAccelerate
                    ? '←  VIRE  →     •     ACELERAÇÃO AUTOMÁTICA ATIVA'
                    : 'ACELERE  •  VIRE NAS SETAS  •  DESLIZE PARA DRIFT',
                style: body(11 * s, color: cream, spacing: 1),
              ),
            ),
          ),
        ),
    ];
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) => routeTouch(e, rects, start: true),
      onPointerMove: (e) => routeTouch(e, rects),
      onPointerUp: (e) => routeTouch(e, rects, end: true),
      onPointerCancel: (e) => routeTouch(e, rects, end: true),
      child: Stack(children: parts),
    );
  }
}

class HoldControl extends StatefulWidget {
  final String label;
  final IconData icon;
  final double width, height;
  final Color color;
  final int resetToken;
  final bool? activeOverride;
  final ValueChanged<bool> onChanged;
  const HoldControl({
    super.key,
    required this.label,
    required this.icon,
    required this.width,
    required this.height,
    required this.onChanged,
    this.color = cream,
    this.resetToken = 0,
    this.activeOverride,
  });
  @override
  State<HoldControl> createState() => _HoldControlState();
}

class _HoldControlState extends State<HoldControl> {
  final Set<int> pointers = {};
  @override
  void didUpdateWidget(covariant HoldControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetToken != widget.resetToken) pointers.clear();
  }

  void press(int pointer, bool down) {
    final wasDown = pointers.isNotEmpty;
    setState(() {
      if (down) {
        pointers.add(pointer);
      } else {
        pointers.remove(pointer);
      }
    });
    if (down || wasDown != pointers.isNotEmpty)
      widget.onChanged(pointers.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.activeOverride ?? pointers.isNotEmpty;
    return Semantics(
      button: true,
      label: widget.label,
      child: Listener(
        onPointerDown: (e) => press(e.pointer, true),
        onPointerMove: (e) {
          if (pointers.contains(e.pointer)) widget.onChanged(true);
        },
        onPointerUp: (e) => press(e.pointer, false),
        onPointerCancel: (e) => press(e.pointer, false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: active
                ? widget.color.withValues(alpha: .35)
                : const Color(0xb00c192e),
            border: Border.all(
              color: active ? widget.color : widget.color.withValues(alpha: .7),
              width: active ? 2.2 : 1.3,
            ),
            borderRadius: BorderRadius.circular(widget.height * .2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: widget.height * .42, color: widget.color),
              SizedBox(height: widget.height * .045),
              Text(
                widget.label,
                style: body(
                  widget.height * .12,
                  color: widget.color,
                  spacing: .6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SpeedGauge extends CustomPainter {
  final double value;
  final bool drift;
  SpeedGauge(this.value, this.drift);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      size.width * .035,
      0,
      size.width * .93,
      size.height * .86,
    );
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x60475b75);
    canvas.drawArc(rect, math.pi * 1.08, math.pi * .84, false, base);
    canvas.drawArc(
      rect,
      math.pi * 1.08,
      math.pi * .84 * value.clamp(0, 1),
      false,
      base..color = drift ? orange : cyan,
    );
  }

  @override
  bool shouldRepaint(covariant SpeedGauge old) =>
      old.value != value || old.drift != drift;
}
