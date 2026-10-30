import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/gpu_ready.dart';
import 'package:carwece/game/content.dart';
import 'package:carwece/game/engine.dart';
import 'package:carwece/music.dart';
import 'package:carwece/platform.dart';
import 'package:carwece/ui/race_screen.dart';
import 'package:carwece/ui/music_sheet.dart';
import 'package:carwece/ui/widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final binding =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final audioCalls = <Map>[], musicCalls = <MethodCall>[];
  late Map<String, dynamic> state;
  const graphics = MethodChannel('com.hirumisu.carwece/graphics');
  setUp(() {
    audioCalls.clear();
    musicCalls.clear();
    state = {
      'trackId': menuSongId,
      'scene': 'menu',
      'status': 'playing',
      'shuffle': true,
      'userPaused': false,
    };
    binding.setMockMethodCallHandler(GameStore.channel, (call) async {
      if (call.method == 'audio') {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        audioCalls.add(args);
        if (state['scene'] != args['scene']) {
          state['scene'] = args['scene'];
          state['trackId'] = args['scene'] == 'battle' ? battleSongs.first.id : args['scene'] == 'race' ? raceSongs.first.id : menuSongId;
          state['status'] = 'playing';
          state['userPaused'] = false;
        }
      }
      if (call.method == 'save') return true;
      return null;
    });
    binding.setMockMethodCallHandler(SoundtrackController.channel, (
      call,
    ) async {
      musicCalls.add(call);
      final args = call.arguments as Map? ?? const {};
      switch (call.method) {
        case 'select':
          state['scene'] = 'race';
          state['trackId'] = args['id'];
          state['status'] = 'playing';
          state['userPaused'] = false;
        case 'next':
          state['trackId'] =
              (state['scene'] == 'battle' ? battleSongs : raceSongs)[((state['scene'] == 'battle' ? battleSongs : raceSongs).indexWhere((s) => s.id == state['trackId']) + 1) % (state['scene'] == 'battle' ? battleSongs : raceSongs).length]
                  .id;
        case 'play':
          state['status'] = 'playing';
          state['userPaused'] = false;
        case 'pause':
          state['status'] = 'paused';
          state['userPaused'] = true;
        case 'shuffle':
          state['shuffle'] = args['enabled'];
      }
      return Map<String, dynamic>.from(state);
    });
    binding.setMockMethodCallHandler(
      graphics,
      (call) async => call.method == 'create' ? 401 : null,
    );
  });
  tearDown(() {
    binding.setMockMethodCallHandler(GameStore.channel, null);
    binding.setMockMethodCallHandler(SoundtrackController.channel, null);
    binding.setMockMethodCallHandler(graphics, null);
    SoundtrackController.channel.setMethodCallHandler(null);
  });
  setUpAll(() async {
    for (final pair in [
      ['RushDisplay', 'Display.ttf'],
      ['RushBody', 'Body.ttf'],
    ]) {
      await (FontLoader(
        pair[0],
      )..addFont(rootBundle.load('assets/fonts/${pair[1]}'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  test(
    'Twenty-five new tracks and platform catalogs agree across three scenes',
    () {
      final catalog =
          jsonDecode(File('assets/music/catalog.json').readAsStringSync())
              as Map;
      expect(songs.length, 25);
      expect(songs.map((s) => s.id).toSet().length, 25);
      expect(raceSongs.length, 15);
      expect(raceSongs.any((s) => s.id == menuSongId), isFalse);
      expect(catalog['menuId'], menuSongId);
      expect(catalog['menuIds'], menuSongs.map((s) => s.id).toList());
      expect(catalog['battleIds'], battleSongs.map((s) => s.id).toList());
      expect(menuSongs.length, 5);
      expect(battleSongs.length, 5);
      expect(catalog['raceIds'], raceSongs.map((s) => s.id).toList());
      for (final raw in catalog['tracks'] as List) {
        final song = songById(raw['id'] as String)!;
        expect(song.title, raw['title']);
        expect(song.artist, raw['artist']);
        expect(song.durationMs, raw['durationMs']);
        expect(File('assets/music/${raw['file']}').lengthSync(), raw['bytes']);
        expect((raw['file'] as String).endsWith('.m4a'), isTrue);
        expect((raw['encoding'] as Map)['codec'], 'AAC-LC');
        expect((raw['encoding'] as Map)['channels'], 2);
        expect(raw['bytes'], lessThan(raw['originalBytes']));
        expect(song.durationMs, greaterThan(30000));
        expect(song.durationLabel, matches(RegExp(r'^\d+:\d\d$')));
      }
      expect(songById(menuSongId)!.title, 'Burned Track');
    },
  );
  test(
    'Existing saves default to shuffle and music preferences retain HUD and progress',
    () {
      final old = GameSettings()
        ..restore({
          'music': .27,
          'hud': {'items': {}},
        });
      expect(old.musicShuffle, isTrue);
      old.musicShuffle = false;
      final restored = GameSettings()
        ..restore(jsonDecode(jsonEncode(old.toJson())) as Map<String, dynamic>);
      expect(restored.musicShuffle, isFalse);
      expect(restored.music, .27);
      expect(restored.hud.toJson(), old.hud.toJson());
    },
  );
  test(
    'Controller accepts native automatic track changes and ignores unknown track requests',
    () async {
      final player = SoundtrackController();
      await player.refresh();
      expect(player.current!.id, menuSongId);
      await player.select('race_02');
      expect(player.current!.title, 'Hot Track');
      final count = musicCalls.length;
      await player.select(menuSongId);
      await player.select('bogus');
      expect(musicCalls.length, count);
      await binding.handlePlatformMessage(
        SoundtrackController.channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('state', {
            'trackId': 'race_04',
            'scene': 'race',
            'status': 'playing',
            'shuffle': true,
            'userPaused': false,
          }),
        ),
        null,
      );
      expect(player.current!.title, 'High Speed');
      await player.toggle();
      expect(musicCalls.last.method, 'pause');
      expect(player.playing, isFalse);
      await player.toggle();
      expect(musicCalls.last.method, 'play');
      expect(player.playing, isTrue);
      player.dispose();
    },
  );
  test(
    'Audio transport distinguishes a paused race from the menu and keeps volume independent',
    () async {
      final store = GameStore();
      store.settings.music = .2;
      store.settings.effects = .8;
      store.settings.musicShuffle = false;
      await store.audio(scene: 'race', racing: false);
      expect(audioCalls.last['scene'], 'race');
      expect(audioCalls.last['racing'], isFalse);
      expect(audioCalls.last['music'], .2);
      expect(audioCalls.last['effects'], .8);
      expect(audioCalls.last['shuffle'], isFalse);
      await store.audio();
      expect(audioCalls.last['scene'], 'menu');
      expect(audioCalls.last['racing'], isFalse);
      store.dispose();
    },
  );
  test('Menu entry is explicit and is not repeated by normal audio ticks', () async {
    final store = GameStore();
    await store.audio(enterMenu: true, event: 'tap');
    expect(audioCalls.last['scene'], 'menu');
    expect(audioCalls.last['enterMenu'], isTrue);
    await store.audio();
    expect(audioCalls.last.containsKey('enterMenu'), isFalse);
    store.dispose();
  });

  test('Button effects keep the current race or battle playlist', () async {
    final store = GameStore();
    for (final scene in ['race', 'battle']) {
      await store.audio(scene: scene);
      store.tap();
      await Future<void>.delayed(Duration.zero);
      expect(audioCalls.last['scene'], scene);
      expect(audioCalls.last['event'], 'tap');
      expect(audioCalls.last.containsKey('enterMenu'), isFalse);
    }
    store.dispose();
  });

  test('Shuffle control preserves the active battle scene', () async {
    state['scene'] = 'battle';
    state['trackId'] = battleSongs.first.id;
    final player = SoundtrackController();
    await player.refresh();
    await player.setShuffle(false);
    expect(musicCalls.last.method, 'shuffle');
    expect(musicCalls.last.arguments, {'enabled': false, 'scene': 'battle'});
    player.dispose();
  });

  for (final size in [const Size(1280, 720), const Size(800, 360)]) {
    testWidgets(
      'Pause music selection, skip, volume and close keep physics paused at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = GameStore()
          ..ready = true
          ..coins = 777;
        final race = RaceEngine(track: createTracks().first, car: cars.first)
          ..countdown = 0;
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData.dark(useMaterial3: true).copyWith(
                scaffoldBackgroundColor: ink,
                colorScheme: const ColorScheme.dark(
                  primary: orange,
                  secondary: cyan,
                  surface: panel,
                ),
                textTheme: ThemeData.dark().textTheme.apply(
                  fontFamily: 'RushBody',
                ),
              ),
              home: RaceScreen(
                race: race,
                store: store,
                onFinish: (_) {},
                onExit: () {},
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 180));
        await tester.pump();
        await waitForGpu(tester);
        await tester.tap(find.byIcon(Icons.pause_rounded));
        await tester.pump();
        expect(race.paused, isTrue);
        await tester.ensureVisible(find.text('MÚSICAS'));
        await tester.tap(find.text('MÚSICAS'));
        await tester.pumpAndSettle();
        expect(find.byType(MusicSheet), findsOneWidget);
        expect(race.paused, isTrue);
        expect(state['scene'], 'race');
        expect(find.text('Burned Track'), findsNothing);
        final time = race.time, position = race.player.position!;
        await tester.tap(find.byKey(const ValueKey('song-race_02')));
        await tester.pump();
        expect(store.soundtrack.trackId, 'race_02');
        expect(musicCalls.where((c) => c.method == 'select').last.arguments, {
          'id': 'race_02',
          'scene': 'race',
        });
        if (const bool.fromEnvironment('EXPORT_MUSIC_PREVIEW')) {
          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final im = await render.toImage(pixelRatio: 1);
            final data = await im.toByteData(format: ui.ImageByteFormat.png);
            final out = File(
              'previews/music_v0101/playlist_${size.width.toInt()}.png',
            );
            out.parent.createSync(recursive: true);
            await out.writeAsBytes(data!.buffer.asUint8List());
            im.dispose();
          });
        }
        await tester.tap(find.byKey(const ValueKey('music-next')));
        await tester.pump();
        expect(musicCalls.last.method, 'next');
        expect(store.soundtrack.trackId, isNot('race_02'));
        await tester.tap(find.byKey(const ValueKey('music-shuffle')));
        await tester.pump();
        expect(store.settings.musicShuffle, isFalse);
        expect(store.soundtrack.shuffle, isFalse);
        final rect = tester.getRect(find.byKey(const ValueKey('music-volume')));
        await tester.tapAt(
          Offset(rect.left + rect.width * .85, rect.center.dy),
        );
        await tester.pump();
        expect(store.settings.music, greaterThan(.6));
        expect(audioCalls.last['scene'], 'race');
        expect(audioCalls.last['racing'], isFalse);
        await tester.tap(find.byKey(const ValueKey('music-play-pause')));
        await tester.pump();
        expect(store.soundtrack.userPaused, isTrue);
        await tester.tap(find.byKey(const ValueKey('music-play-pause')));
        await tester.pump();
        expect(store.soundtrack.playing, isTrue);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('song-race_15')),
          100,
          scrollable: find.descendant(
            of: find.byKey(const ValueKey('race-music-list')),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('song-race_15')));
        await tester.pump();
        expect(store.soundtrack.trackId, 'race_15');
        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump(const Duration(seconds: 1));
        expect(race.accelerating, isFalse);
        expect(race.paused, isTrue);
        expect(race.time, time);
        expect((race.player.position! - position).length, 0);
        await tester.tap(find.byTooltip('Fechar músicas'));
        await tester.pumpAndSettle();
        expect(find.byType(MusicSheet), findsNothing);
        expect(race.paused, isTrue);
        await tester.ensureVisible(find.text('CONTINUAR'));
        await tester.tap(find.text('CONTINUAR'));
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump(const Duration(milliseconds: 150));
        expect(race.paused, isFalse);
        expect(audioCalls.last['scene'], 'race');
        expect(store.coins, 777);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(audioCalls.last['scene'], 'menu');
        await store.save();
        store.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
}
