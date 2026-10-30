import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The native decoder signals completion; no duration-based navigation exists.
class IntroController extends ChangeNotifier {
  static const channel = MethodChannel('com.hirumisu.carwece/intro');
  String status = 'loading';
  int? textureId;
  double width = 1280, height = 720;
  bool _closed = false;
  IntroController() {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'state') _apply(call.arguments);
    });
  }
  void _apply(dynamic value) {
    if (_closed || value is! Map) return;
    if (status == 'completed') return;
    status = value['status'] as String? ?? status;
    textureId = (value['textureId'] as num?)?.toInt() ?? textureId;
    final w = (value['width'] as num?)?.toDouble(),
        h = (value['height'] as num?)?.toDouble();
    if (w != null && w > 0 && w.isFinite) width = w;
    if (h != null && h > 0 && h.isFinite) height = h;
    notifyListeners();
  }

  Future<void> _command(String command) async {
    if (_closed) return;
    try {
      _apply(await channel.invokeMethod<dynamic>(command));
    } catch (_) {
      if (!_closed && status != 'completed') {
        status = 'error';
        notifyListeners();
      }
    }
  }

  Future<void> open() => _command('open');
  Future<void> resume() => _command('resume');
  Future<void> pause() => _command('pause');
  @override
  void dispose() {
    _closed = true;
    channel.setMethodCallHandler(null);
    unawaited(channel.invokeMethod<void>('dispose').catchError((_) {}));
    super.dispose();
  }
}

class IntroScreen extends StatefulWidget {
  final VoidCallback onCompleted;
  const IntroScreen({super.key, required this.onCompleted});
  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> with WidgetsBindingObserver {
  late final IntroController controller;
  bool foreground = true, delivered = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    controller = IntroController()..addListener(changed);
    unawaited(controller.open());
  }

  void changed() {
    if (!mounted) return;
    if (controller.status == 'completed' && foreground && !delivered) {
      delivered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onCompleted();
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) {
      unawaited(controller.resume());
      changed();
    } else {
      unawaited(controller.pause());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(changed);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      key: const ValueKey('intro-screen'),
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (controller.textureId != null)
            Center(
              child: AspectRatio(
                aspectRatio: controller.width / controller.height,
                child: Texture(textureId: controller.textureId!),
              ),
            ),
          if (controller.status == 'loading')
            const Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  color: Color(0xff74dbe0),
                  strokeWidth: 2,
                ),
              ),
            ),
          if (controller.status == 'error' || controller.status == 'paused')
            ColoredBox(
              color: const Color(0xb3000000),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      controller.status == 'error'
                          ? 'Não foi possível reproduzir a abertura.'
                          : 'Abertura pausada',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        unawaited(
                          controller.status == 'error'
                              ? controller.open()
                              : controller.resume(),
                        );
                      },
                      child: Text(
                        controller.status == 'error'
                            ? 'TENTAR NOVAMENTE'
                            : 'CONTINUAR ABERTURA',
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
