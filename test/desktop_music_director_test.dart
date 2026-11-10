import 'dart:math' as math;

import 'package:carwece/desktop/music_director.dart';
import 'package:carwece/music.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeBackend implements MusicBackend {
  final List<String> loaded = [];
  void Function()? _completed, _failed;
  bool playing = false;
  double level = 0;

  @override
  void load(
    Song track, {
    required int startMs,
    required void Function() ready,
    required void Function() completed,
    required void Function() failed,
  }) {
    loaded.add(track.id);
    _completed = completed;
    _failed = failed;
    ready();
  }

  @override
  void play() => playing = true;

  @override
  void pause() => playing = false;

  @override
  void volume(double value) => level = value;

  @override
  int position() => 0;

  @override
  void release() => playing = false;

  void complete() => _completed!();
  void fail() => _failed!();
}

const _tracks = <Song>[
  Song('m1', 'M1', 'A', 1000),
  Song('m2', 'M2', 'A', 1000),
  Song('m3', 'M3', 'A', 1000),
  Song('r1', 'R1', 'A', 1000),
  Song('r2', 'R2', 'A', 1000),
  Song('b1', 'B1', 'A', 1000),
];

MusicDirector _director(FakeBackend backend) => MusicDirector(
  tracks: _tracks,
  menuIds: const ['m1', 'm2', 'm3'],
  raceIds: const ['r1', 'r2'],
  battleIds: const ['b1'],
  backend: backend,
  random: math.Random(7),
);

void main() {
  test('só toca ativo e em foco; completa avança a faixa', () {
    final backend = FakeBackend();
    final director = _director(backend);
    expect(director.state()['status'], 'waiting');

    director.setActive(true);
    expect(backend.loaded, hasLength(1));
    // Active but not focused yet: still waiting, like the Android states.
    expect(director.state()['status'], 'waiting');
    expect(backend.playing, isFalse);

    director.setFocus(true);
    expect(backend.playing, isTrue);
    expect(director.state()['status'], 'playing');

    final first = director.currentId;
    backend.complete();
    expect(director.currentId, isNot(first));
    expect(backend.playing, isTrue);
  });

  test('modo sequencial percorre a playlist de corrida em ordem', () {
    final backend = FakeBackend();
    final director = _director(backend);
    director.setShuffle(false);
    director.setActive(true);
    director.setFocus(true);
    director.setScene('race');
    expect(director.currentId, 'r1');
    backend.complete();
    expect(director.currentId, 'r2');
    backend.complete();
    expect(director.currentId, 'r1');
  });

  test('shuffle esgota a bolsa antes de repetir', () {
    final backend = FakeBackend();
    final director = _director(backend);
    director.setActive(true);
    director.setFocus(true);
    final seen = <String?>{director.currentId};
    backend.complete();
    seen.add(director.currentId);
    backend.complete();
    seen.add(director.currentId);
    expect(seen, {'m1', 'm2', 'm3'});
  });

  test('select toca a faixa pedida e next limpa pausa do usuário', () {
    final backend = FakeBackend();
    final director = _director(backend);
    director.setActive(true);
    director.setFocus(true);
    director.setScene('race');
    director.select('r2');
    expect(director.currentId, 'r2');
    director.setUserPaused(true);
    expect(backend.playing, isFalse);
    director.next();
    expect(director.userPaused, isFalse);
    expect(backend.playing, isTrue);
  });

  test('falha pula a faixa; falhando tudo, vira erro recuperável', () {
    final backend = FakeBackend();
    final director = _director(backend);
    director.setActive(true);
    director.setFocus(true);
    final first = director.currentId;
    backend.fail();
    expect(director.currentId, isNot(first));
    backend.fail();
    backend.fail();
    expect(director.state()['status'], 'error');
    expect(director.state()['error'], contains('PULAR FAIXA'));
    // Play de novo limpa o erro e tenta outra faixa.
    director.setUserPaused(false);
    expect(director.state()['status'], isNot('error'));
  });

  test('enterMenu volta pra cena de menu sorteando outra faixa', () {
    final backend = FakeBackend();
    final director = _director(backend);
    director.setActive(true);
    director.setFocus(true);
    director.setScene('battle');
    expect(director.scene, 'battle');
    expect(director.currentId, 'b1');
    director.enterMenu();
    expect(director.scene, 'menu');
    expect(['m1', 'm2', 'm3'], contains(director.currentId));
  });
}
