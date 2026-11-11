import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'audio_engine.dart';

/// The opening video on Windows — the counterpart of the Android
/// `IntroScreen`: same black backdrop, spinner, error/retry and
/// paused/continue states, rendered with media_kit instead of a native
/// texture. Music stays gated until the video completes, exactly like
/// the native intro gate.
class DesktopIntroScreen extends StatefulWidget {
  final VoidCallback onCompleted;
  const DesktopIntroScreen({super.key, required this.onCompleted});

  @override
  State<DesktopIntroScreen> createState() => _DesktopIntroScreenState();
}

class _DesktopIntroScreenState extends State<DesktopIntroScreen>
    with WidgetsBindingObserver {
  late final Player _player;
  late final VideoController _video;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _watchdog;
  String _status = 'loading';
  double _width = 1280, _height = 720;
  bool _foreground = true, _delivered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    DesktopAudio.instance.beginIntro();
    _player = Player();
    _video = VideoController(_player);
    _subscriptions.add(
      _player.stream.playing.listen((playing) {
        if (!mounted || _delivered) return;
        if (playing && _status == 'loading') {
          setState(() => _status = 'playing');
        }
      }),
    );
    _subscriptions.add(
      _player.stream.width.listen((width) {
        if (width != null && width > 0) setState(() => _width = width.toDouble());
      }),
    );
    _subscriptions.add(
      _player.stream.height.listen((height) {
        if (height != null && height > 0) {
          setState(() => _height = height.toDouble());
        }
      }),
    );
    _subscriptions.add(
      _player.stream.error.listen((_) {
        if (mounted && !_delivered) setState(() => _status = 'error');
      }),
    );
    _subscriptions.add(
      _player.stream.completed.listen((completed) {
        if (completed) _complete();
      }),
    );
    _subscriptions.add(
      _player.stream.position.listen((position) {
        // Insurance: some mpv builds report the final position a beat
        // before (or instead of) the completed flag.
        final duration = _player.state.duration;
        if (duration > Duration.zero &&
            position >= duration - const Duration(milliseconds: 60)) {
          _complete();
        }
      }),
    );
    // Watchdog: poll the player state directly, so completion can never
    // depend on a single stream event surviving the trip.
    _watchdog = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_delivered) return;
      final state = _player.state;
      if (state.completed ||
          (state.duration > Duration.zero &&
              state.position >=
                  state.duration - const Duration(milliseconds: 120))) {
        _complete();
      }
    });
    unawaited(_open());
  }

  Future<void> _open() async {
    setState(() => _status = 'loading');
    try {
      await _player.open(Media('asset:///assets/video/carwece_intro.mp4'));
    } catch (_) {
      if (mounted && !_delivered) setState(() => _status = 'error');
    }
  }

  void _complete() {
    // Deliver as soon as the video ends. An earlier version also required
    // the window to be "foreground" (copied from the Android screen), but
    // on desktop a stray lifecycle event at the final second dropped the
    // delivery and left the app frozen on the last frame until the next
    // focus change.
    if (_delivered) return;
    _delivered = true;
    _watchdog?.cancel();
    DesktopAudio.instance.endIntro();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onCompleted();
    });
  }

  void _resume() {
    unawaited(_player.play());
    if (_status == 'paused') setState(() => _status = 'playing');
    // A completion that arrived while backgrounded is delivered now.
    if (_player.state.completed) _complete();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    // Desktop only delivers the intro: transient inactive states are
    // normal while a Windows window starts up, and pausing on them left
    // the video frozen on its last frame until the user clicked back.
    // The intro is never paused from lifecycle events here.
    if (_foreground) _resume();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watchdog?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_player.dispose());
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
          Center(
            child: AspectRatio(
              aspectRatio: _width / _height,
              child: Video(controller: _video, controls: NoVideoControls),
            ),
          ),
          if (_status == 'loading')
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
          if (_status == 'error' || _status == 'paused')
            ColoredBox(
              color: const Color(0xb3000000),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _status == 'error'
                          ? 'Não foi possível reproduzir a abertura.'
                          : 'Abertura pausada',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        if (_status == 'error') {
                          unawaited(_open());
                        } else {
                          _resume();
                        }
                      },
                      child: Text(
                        _status == 'error'
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
