import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../game/content.dart';
import '../game/engine.dart';
import '../game/gpu_frame.dart';
import '../game/renderer.dart';
import 'widgets.dart';

class GpuRaceView extends StatelessWidget {
  final RaceEngine race;
  final TrackScene Function() fallbackScene;
  final Listenable repaint;
  final String quality;
  final double cameraDistance;
  final ValueChanged<double>? onFps;
  final VoidCallback? onReady;
  final VoidCallback? onUnavailable;
  const GpuRaceView({
    super.key,
    required this.race,
    required this.fallbackScene,
    required this.repaint,
    required this.quality,
    required this.cameraDistance,
    this.onFps,
    this.onReady,
    this.onUnavailable,
  });
  @override
  Widget build(BuildContext context) => GpuSurface(
    key: ObjectKey(race),
    bodies: {for (final d in race.drivers) d.car.body},
    prepare: () => GpuResources.prepare(
      track: race.track,
      bodies: {for (final d in race.drivers) d.car.body},
      battle: race is BattleEngine,
    ),
    world: () => GpuResources.world(race.track),
    frame: () => raceGpuFrame(race, cameraDistance: cameraDistance),
    repaint: repaint,
    quality: quality,
    onFps: onFps,
    onReady: onReady,
    onUnavailable: onUnavailable,
    night: race.track.night,
    fallback: Builder(
      builder: (_) => CustomPaint(
        painter: RacePainter(
          race,
          fallbackScene(),
          quality: quality,
          cameraDistance: cameraDistance,
          repaint: repaint,
        ),
      ),
    ),
  );
}

class GpuGarageView extends StatelessWidget {
  final CarSpec car;
  final double angle;
  const GpuGarageView({super.key, required this.car, required this.angle});
  @override
  Widget build(BuildContext context) => ShaderMask(
    shaderCallback: (bounds) => const RadialGradient(
      colors: [Colors.white, Colors.white, Colors.transparent],
      stops: [0, .67, 1.0],
      radius: .77,
    ).createShader(bounds),
    blendMode: BlendMode.dstIn,
    child: GpuSurface(
      key: ValueKey('garage-${car.id}'),
      bodies: {car.body},
      world: () => GpuResources.showroom,
      prepare: () => GpuResources.prepare(bodies: {car.body}),
      frame: () => garageGpuFrame(car, angle),
      showroom: true,
      quality: 'medium',
      fallback: CustomPaint(
        painter: GaragePainter(car, angle),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class GpuSurface extends StatefulWidget {
  final ValueChanged<double>? onFps;
  final VoidCallback? onReady;
  final VoidCallback? onUnavailable;
  final Future<(Float32List, List<Float32List>)> Function()? prepare;
  final List<Float32List>? extraObjects;
  final Set<int>? bodies;
  final Float32List Function() world;
  final Float32List Function() frame;
  final Listenable? repaint;
  final String quality;
  final bool showroom, night;
  final Widget fallback;
  const GpuSurface({
    super.key,
    required this.world,
    required this.frame,
    required this.fallback,
    this.onFps,
    this.onReady,
    this.onUnavailable,
    this.prepare,
    this.repaint,
    this.bodies,
    this.extraObjects,
    this.quality = 'medium',
    this.showroom = false,
    this.night = false,
  });
  @override
  State<GpuSurface> createState() => _GpuSurfaceState();
}

class _GpuSurfaceState extends State<GpuSurface> {
  static const channel = MethodChannel('com.hirumisu.carwece/graphics');
  static List<String>? _shaders;
  int? textureId;
  bool started = false, sending = false, compatibility = false;
  bool creating = false, retrying = false;
  final _frameClock = Stopwatch()..start();
  int _lastFrameUs = -1000000;
  // Minimum interval between GPU frames, matched to the display: the old
  // fixed 16 ms throttle capped 90/120 Hz phones at ~60 fps.
  int _minFrameUs = 16000;
  int _lastFpsUs = 0;
  String? error;
  @override
  void initState() {
    super.initState();
    widget.repaint?.addListener(sendFrame);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      compatibility = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onReady?.call();
      });
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(create());
    });
  }

  Future<void> create() async {
    if (creating || !mounted) return;
    creating = true;
    final render = context.findRenderObject();
    final size = render is RenderBox && render.hasSize
        ? render.size
        : MediaQuery.sizeOf(context);
    final refreshRate = View.of(context).display.refreshRate;
    if (refreshRate > 65) {
      _minFrameUs = (1000000 / refreshRate).round() - 400;
    }
    // Entry-level hardware (Galaxy A05s class) is detected here for the
    // render-width ceiling below. Frame submission follows the panel on
    // every device: an in-between cap quantizes badly (a 16 ms gate on
    // a 90 Hz panel lets a frame through only every other tick, which
    // pins the game at 45 fps), and the native renderer draws only the
    // latest frame, so the GPU sets its own pace.
    var lowEnd = false;
    try {
      final profile = await channel.invokeMethod<Map<dynamic, dynamic>>(
        'profile',
      );
      lowEnd = profile?['lowEnd'] == true;
    } catch (_) {}
    final width = widget.showroom
        ? 960
        : widget.quality == 'high'
        ? 1440
        : widget.quality == 'low'
        ? 960
        : 1280;
    // Weak hardware keeps the full HIGH width: the renderer's dynamic
    // scale floor protects the frame rate instead of a narrower buffer.
    final renderWidth =
        lowEnd && !widget.showroom && widget.quality == 'high' && width > 1440
        ? 1440
        : width;
    final height = (renderWidth * size.height / size.width).round().clamp(
      180,
      1200,
    );
    try {
      final shaders = _shaders ??= await Future.wait(
        [
          'scene.vert',
          'scene.frag',
          'depth.vert',
          'depth.frag',
        ].map((s) => rootBundle.loadString('assets/shaders/$s')),
      );
      final prepared = await widget.prepare?.call();
      if (!mounted) return;
      final id = await channel.invokeMethod<int>('create', {
        'width': renderWidth,
        'height': height,
        'world': prepared?.$1 ?? widget.world(),
        'objects':
            prepared?.$2 ??
            [
              ...(widget.bodies == null
                  ? GpuResources.objects
                  : GpuResources.objectsFor(widget.bodies!)),
              ...?widget.extraObjects,
            ],
        'shaders': shaders,
        'frame': widget.frame(),
        'showroom': widget.showroom,
        'night': widget.night,
        'quality': widget.quality,
      });
      if (!mounted) {
        if (id != null) await channel.invokeMethod('dispose', {'id': id});
        return;
      }
      if (id == null) throw StateError('Superfície gráfica não criada');
      setState(() => textureId = id);
      widget.onReady?.call();
      sendFrame();
    } catch (e) {
      if (mounted) {
        setState(() {
          compatibility = true;
          error = '${e.runtimeType}: ${e is PlatformException ? e.message : e}';
        });
        widget.onUnavailable?.call();
      }
    } finally {
      creating = false;
    }
  }

  void sendFrame() {
    final id = textureId;
    if (id == null || sending || !mounted || error != null) return;
    final now = _frameClock.elapsedMicroseconds;
    if (now - _lastFrameUs < _minFrameUs) return;
    _lastFrameUs = now;
    sending = true;
    channel
        .invokeMethod<String>('frame', {'id': id, 'data': widget.frame()})
        .then((message) {
          if (message != null && mounted) {
            setState(() {
              error = message;
              compatibility = true;
            });
            widget.onUnavailable?.call();
          }
        })
        .catchError((Object e) {
          if (mounted) {
            setState(() {
              error = '$e';
              compatibility = true;
            });
            widget.onUnavailable?.call();
          }
        })
        .whenComplete(() => sending = false);
    if (widget.onFps != null && now - _lastFpsUs >= 1000000) {
      _lastFpsUs = now;
      unawaited(
        channel
            .invokeMethod<num>('fps', {'id': id})
            .then((value) {
              if (mounted && value != null && value > 0)
                widget.onFps?.call(value.toDouble());
            })
            .catchError((Object _) {}),
      );
    }
  }

  @override
  void didUpdateWidget(covariant GpuSurface old) {
    super.didUpdateWidget(old);
    if (old.repaint != widget.repaint) {
      old.repaint?.removeListener(sendFrame);
      widget.repaint?.addListener(sendFrame);
    }
    sendFrame();
  }

  Future<void> retry() async {
    if (creating || retrying || !mounted) return;
    retrying = true;
    try {
      final previousId = textureId;
      setState(() {
        textureId = null;
        compatibility = false;
        error = null;
      });
      if (previousId != null) {
        try {
          await channel.invokeMethod('dispose', {'id': previousId});
        } catch (_) {}
      }
      if (mounted) await create();
    } finally {
      retrying = false;
    }
  }

  @override
  void dispose() {
    widget.repaint?.removeListener(sendFrame);
    if (textureId != null)
      unawaited(
        channel
            .invokeMethod('dispose', {'id': textureId})
            .catchError((Object _) {}),
      );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return ColoredBox(
        color: ink,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.sports_motorsports_outlined,
                    color: orange,
                    size: 36,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'NÃO FOI POSSÍVEL INICIAR O 3D',
                    textAlign: TextAlign.center,
                    style: display(27, color: cream),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: body(12, color: muted),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('TENTAR NOVAMENTE'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (compatibility) return widget.fallback;
    if (textureId != null)
      return Texture(
        textureId: textureId!,
        filterQuality: FilterQuality.medium,
      );
    return Container(
      color: ink,
      child: const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2, color: orange),
        ),
      ),
    );
  }
}
