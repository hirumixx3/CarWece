#!/usr/bin/env python3
"""Verify release identity, ABIs, signing, alignment and compiled icon pixels.

Usage: python3 tools/verify_apk.py path/to.apk --sdk ANDROID_SDK --java JAVA
Requires Pillow and numpy for the source/compiled PNG comparison.
"""
import argparse
import base64
import hashlib
import io
import json
import os
import re
import subprocess
import zipfile
from pathlib import Path

import numpy as np
from PIL import Image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path)
    parser.add_argument('--sdk', type=Path, default=os.environ.get('ANDROID_HOME'))
    parser.add_argument('--java', default='java')
    parser.add_argument('--version-name', default='1.0.0')
    parser.add_argument('--version-code', type=int, default=1)
    args = parser.parse_args()
    if args.sdk is None:
        parser.error('--sdk or ANDROID_HOME is required')
    root = Path(__file__).resolve().parent.parent
    out = root / 'verification'
    out.mkdir(exist_ok=True)
    apk = args.apk.resolve()
    build_tools = args.sdk.resolve() / 'build-tools/35.0.0'

    def run(name, command):
        result = subprocess.run(command, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, check=True)
        (out / name).write_text(result.stdout)
        return result.stdout

    badging = run('manifest.txt', [str(build_tools / 'aapt'), 'dump', 'badging', str(apk)])
    for expected in ["name='com.hirumisu.carwece'", f"versionCode='{args.version_code}'",
                     f"versionName='{args.version_name}'", "application-label:'CarWece'",
                     "sdkVersion:'24'", "targetSdkVersion:'36'",
                     "name='com.hirumisu.carwece.MainActivity'"]:
        assert expected in badging, expected
    run('manifest_tree.txt', [str(build_tools / 'aapt'), 'dump', 'xmltree',
                               str(apk), 'AndroidManifest.xml'])
    resources = run('resource_values.txt', [str(build_tools / 'aapt'), 'dump',
                                             '--values', 'resources', str(apk)])
    signature = run('signature.txt', [args.java, '-jar',
                                      str(build_tools / 'lib/apksigner.jar'),
                                      'verify', '--verbose', '--print-certs', str(apk)])
    public_pem = (root / 'android/hirumi-upload-certificate.pem').read_text()
    certificate = hashlib.sha256(base64.b64decode(''.join(
        line for line in public_pem.splitlines() if not line.startswith('-----')
    ))).hexdigest()
    assert certificate in signature.lower()
    assert 'Verified using v2 scheme (APK Signature Scheme v2): true' in signature
    run('alignment.txt', [str(build_tools / 'zipalign'), '-c', '-v', '-P', '16', '4', str(apk)])

    rows, config, pending = [], None, None
    for line in resources.splitlines():
        m = re.match(r'\s+config ([^:]+):', line)
        if m:
            config = m.group(1)
        m = re.match(r'\s+resource (0x[0-9a-f]+) [^:]+:mipmap/(ic_launcher\w*):', line)
        if m:
            pending = (m.group(1), m.group(2), config)
        elif re.match(r'\s+resource ', line):
            pending = None
        m = re.search(r'\(string8\) "(res/[^"]+)"', line)
        if pending and m:
            rows.append((*pending, m.group(1)))
            pending = None
    assert len(rows) == 22, len(rows)
    resource_ids = {name: rid for rid, name, _, _ in rows}
    icon_results, adaptive = [], []

    def visible_rgba(image):
        a = np.array(image.convert('RGBA'))
        a[a[:, :, 3] == 0, :3] = 0
        return a

    channels = [b'com.hirumisu.carwece/native', b'com.hirumisu.carwece/graphics', b'com.hirumisu.carwece/music', b'com.hirumisu.carwece/host']
    with zipfile.ZipFile(apk) as archive:
        assert archive.testzip() is None
        names = archive.namelist()
        abis = ['armeabi-v7a', 'arm64-v8a', 'x86_64']
        for abi in abis:
            assert f'lib/{abi}/libflutter.so' in names
            app = archive.read(f'lib/{abi}/libapp.so')
            assert all(channel in app for channel in channels), abi
        assert {n for n in names if n.startswith('lib/')} == {
            f'lib/{abi}/{library}' for abi in abis
            for library in ['libapp.so', 'libflutter.so']
        }
        dex = b''.join(archive.read(n) for n in names if re.fullmatch(r'classes\d*\.dex', n))
        assert b'Lcom/hirumisu/carwece/MainActivity;' in dex
        assert all(channel in dex for channel in channels)
        music_catalog = json.loads((root / 'assets/music/catalog.json').read_text())
        assert archive.read('assets/flutter_assets/assets/shaders/scene.frag') == (root / 'assets/shaders/scene.frag').read_bytes()
        assert b'vMaterial==18' in archive.read('assets/flutter_assets/assets/shaders/scene.frag')
        intro_path = 'assets/flutter_assets/assets/video/carwece_intro.mp4'
        intro_source = root / 'assets/video/carwece_intro.mp4'
        intro = archive.read(intro_path)
        assert intro == intro_source.read_bytes()
        assert hashlib.sha256(intro).hexdigest() == '4e5395f7cbe6db3e29f1081c1bdc56a6c40adaf077c8a70fb9f795528fdcf204'
        assert archive.getinfo(intro_path).compress_type == zipfile.ZIP_STORED
        battle_catalog = json.loads((root / 'verification/battle_catalog_v012.json').read_text())
        assert len(battle_catalog['arenas']) == 6 and len(battle_catalog['weapons']) == 44
        assert all(weapon['ammo'] > 0 for weapon in battle_catalog['weapons'])
        for abi in abis:
            compiled = archive.read(f'lib/{abi}/libapp.so')
            for weapon in battle_catalog['weapons']:
                assert weapon['id'].encode() in compiled, (abi, weapon['id'])
        assert json.loads(archive.read('assets/flutter_assets/assets/music/catalog.json')) == music_catalog
        assert music_catalog['menuId'] == 'legends_never_die'
        assert len(music_catalog['tracks']) == 20 and len(music_catalog['raceIds']) == 19
        assert music_catalog['menuId'] not in music_catalog['raceIds']
        music_prefix = 'assets/flutter_assets/assets/music/'
        expected_music = {music_prefix + song['file'] for song in music_catalog['tracks']}
        expected_music.add(music_prefix + 'catalog.json')
        assert {n for n in names if n.startswith(music_prefix)} == expected_music
        audio_assets = []
        for song in music_catalog['tracks']:
            name = 'assets/flutter_assets/assets/music/' + song['file']
            data = archive.read(name)
            assert len(data) == song['bytes']
            assert hashlib.sha256(data).hexdigest() == song['sha256'], name
            assert data == (root / 'assets/music' / song['file']).read_bytes(), name
            assert archive.getinfo(name).compress_type == zipfile.ZIP_STORED, name
            uploaded = root.parents[1] / 'upload' / song['sourceName']
            if uploaded.is_file(): assert hashlib.sha256(uploaded.read_bytes()).hexdigest() == song['originalSha256'], song['sourceName']
            audio_assets.append({'id': song['id'], 'bytes': len(data), 'sha256': song['sha256'], 'uncompressedAsset': True})
        (out / 'audio_assets_v0142.json').write_text(json.dumps(audio_assets, indent=2))
        assert b'Landroid/media/MediaPlayer;' in dex
        assert b'flutter_assets/assets/music/catalog.json' in dex
        assert b'prepareAsync' in dex
        assert b'com.hirumisu.carwece/intro' in dex
        assert b'flutter_assets/assets/video/carwece_intro.mp4' in dex
        mapping_path = root / 'build/app/outputs/mapping/release/mapping.txt'
        mapping_text = mapping_path.read_text() if mapping_path.is_file() else ''
        music_symbols = {}
        for original in ['com.hirumisu.carwece.RushMusic', 'com.hirumisu.carwece.MusicDirector', 'com.hirumisu.carwece.AndroidMusicBackend']:
            mapped = re.search(r'^' + re.escape(original) + r' -> ([^:]+):$', mapping_text, re.M)
            name = mapped.group(1) if mapped else original
            descriptor = ('L' + name.replace('.', '/') + ';').encode()
            assert descriptor in dex, original
            music_symbols[original] = name
        (out / 'r8_music_v0142.json').write_text(json.dumps(music_symbols, indent=2))
        for rid, name, config, compiled in rows:
            if compiled.endswith('.png'):
                source = root / f'android/app/src/main/res/mipmap-{config}/{name}.png'
                with Image.open(source) as original, Image.open(io.BytesIO(archive.read(compiled))) as built:
                    assert np.array_equal(visible_rgba(original), visible_rgba(built)), str(source)
                icon_results.append({'name': name, 'density': config, 'compiled': compiled,
                                     'pixels_match': True})
            else:
                xml = run(f'adaptive_{name}.txt', [str(build_tools / 'aapt'), 'dump',
                                                   'xmltree', str(apk), compiled])
                assert 'E: adaptive-icon' in xml
                for layer in ['background', 'foreground']:
                    pattern = rf'E: {layer}[^\n]*\n[^\n]*=@{resource_ids["ic_launcher_" + layer]}'
                    assert re.search(pattern, xml), (name, layer)
                adaptive.append({'name': name, 'compiled': compiled, 'layers_match': True})
    assert len(icon_results) == 20
    assert len(adaptive) == 2
    masters = {
        'foreground': 'b0b907e02dcdf2583c386de028567d718346adb98970016bd1b852c9f68013bf',
        'background': '706f05bd154a5cee7792bbfe49cd54f88f6171a7eb8c75686fb2c0da14deff91',
    }
    for layer, expected in masters.items():
        assert hashlib.sha256((root / f'branding/ic_launcher_{layer}.png').read_bytes()).hexdigest() == expected
    (out / 'icons_v0142.json').write_text(json.dumps({'masters': masters, 'png': icon_results,
                                                  'adaptive': adaptive}, indent=2))
    metadata = {'file': apk.name, 'size_bytes': apk.stat().st_size,
                'sha256': hashlib.sha256(apk.read_bytes()).hexdigest(),
                'package': 'com.hirumisu.carwece', 'label': 'CarWece',
                'version': re.search(r"versionName='([^']+)'", badging).group(1),
                'code': int(re.search(r"versionCode='([0-9]+)'", badging).group(1)),
                'abis': abis,
                'verified_png_resources': 20, 'verified_adaptive_icons': 2,
                'certificate_sha256': certificate}
    (out / 'apk_meta.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print(json.dumps(metadata, indent=2))


if __name__ == '__main__':
    main()
