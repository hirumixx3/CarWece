#!/usr/bin/env python3
"""Validate real AAB manifests, signatures, game assets and 16 KB support."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import xml.etree.ElementTree as ET
import zipfile


def certificate_hash(pem):
    match = re.search(r'-----BEGIN CERTIFICATE-----(.*?)-----END CERTIFICATE-----',
                      pem, re.S)
    if not match:
        raise ValueError('Certificado PEM ausente.')
    return hashlib.sha256(base64.b64decode(match[1])).hexdigest()


def elf_alignment(data):
    if data[:6] != b'\x7fELF\x02\x01':
        raise ValueError('ELF de 64 bits little-endian inválido.')
    offset = struct.unpack_from('<Q', data, 32)[0]
    entry_size, count = struct.unpack_from('<HH', data, 54)
    alignments = []
    for i in range(count):
        kind, flags, file_offset, address, _, _, _, alignment = struct.unpack_from(
            '<IIQQQQQQ', data, offset + i * entry_size)
        if kind == 1:
            if alignment < 16384 or file_offset % 16384 != address % 16384:
                raise ValueError('Biblioteca sem alinhamento ELF de 16 KB.')
            alignments.append(alignment)
    if not alignments:
        raise ValueError('ELF sem segmentos LOAD.')
    return min(alignments)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', required=True, type=Path)
    parser.add_argument('--bundletool', required=True, type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    expected_certificate = certificate_hash(
        (root / 'android/hirumi-upload-certificate.pem').read_text())
    manifest_rows = json.loads((args.directory / 'release-manifest.json').read_text())
    # Compare the assets actually declared to Flutter. Font-license documents
    # in the source tree are not automatically separate packaged font assets.
    declared_assets = set()
    pubspec = (root / 'pubspec.yaml').read_text()
    for relative in re.findall(r'^\s*-\s*(?:asset:\s*)?(assets/[\w./-]+)\s*$', pubspec, re.M):
        source = root / relative
        if source.is_dir():
            declared_assets.update(str(p.relative_to(root)) for p in source.iterdir() if p.is_file())
        else:
            assert source.is_file(), relative
            declared_assets.add(relative)
    assert declared_assets
    outputs = []
    ns = '{http://schemas.android.com/apk/res/android}'
    for row in manifest_rows:
        bundle = (args.directory / row['file']).resolve()
        def bundletool(*commands):
            result = subprocess.run(['java', '-jar', str(args.bundletool.resolve()),
                                     *commands, '--bundle=' + str(bundle)],
                                    check=True, text=True, stdout=subprocess.PIPE,
                                    stderr=subprocess.PIPE)
            return result.stdout
        bundletool('validate')
        xml = bundletool('dump', 'manifest')
        config = bundletool('dump', 'config')
        manifest = ET.fromstring(xml)
        sdk = manifest.find('uses-sdk')
        assert manifest.get('package') == 'com.hirumisu.carwece'
        assert manifest.get(ns + 'versionName') == row['versionName']
        assert int(manifest.get(ns + 'versionCode')) == row['versionCode']
        assert sdk is not None and int(sdk.get(ns + 'targetSdkVersion')) == 36
        assert int(sdk.get(ns + 'minSdkVersion')) == 24
        application = manifest.find('application')
        assert application is not None and application.get(ns + 'debuggable') != 'true'
        assert application.get(ns + 'testOnly') != 'true'
        assert 'PAGE_ALIGNMENT_16K' in config or 'PAGE_ALIGNMENT_64K' in config
        verified = subprocess.run(['jarsigner', '-verify', str(bundle)], check=True,
                                  text=True, stdout=subprocess.PIPE,
                                  stderr=subprocess.STDOUT).stdout
        assert 'jar verified.' in verified and 'jar is unsigned' not in verified
        public_cert = subprocess.run(['keytool', '-printcert', '-rfc', '-jarfile',
                                      str(bundle)], check=True, text=True,
                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout
        assert certificate_hash(public_cert) == expected_certificate
        alignments = {}
        with zipfile.ZipFile(bundle) as archive:
            assert archive.testzip() is None
            assert 'base/dex/classes.dex' in archive.namelist()
            assert not any(name.endswith(('.jks', '.keystore', '.b64', '/key.properties'))
                           for name in archive.namelist())
            for abi in ['armeabi-v7a', 'arm64-v8a', 'x86_64']:
                for library in ['libapp.so', 'libflutter.so']:
                    data = archive.read(f'base/lib/{abi}/{library}')
                    if abi != 'armeabi-v7a':
                        alignments[abi + '/' + library] = elf_alignment(data)
                app = archive.read(f'base/lib/{abi}/libapp.so')
                assert b'JOGAR ONLINE' in app
                assert ('VERSÃO ' + row['versionName'] + ' • 3D').encode('utf-16-le') in app
            assets = 0
            for rel in sorted(declared_assets):
                assert archive.read('base/assets/flutter_assets/' + rel) == (root / rel).read_bytes(), rel
                assets += 1
        digest = hashlib.sha256(bundle.read_bytes()).hexdigest()
        assert digest == row['sha256']
        output = {**row, 'package': manifest.get('package'), 'targetSdk': 36,
                  'minSdk': 24, 'bundletoolValid': True, 'signatureValid': True,
                  'privateKeyAbsent': True, 'sourceAssetsMatch': assets,
                  'pageAlignment': '16 KB compatible', 'elfLoadAlignments': alignments}
        outputs.append(output)
        print(f"Validado: {bundle.name} — código {row['versionCode']}, API 36, chave hirumi, 16 KB", flush=True)
    assert len({r['versionCode'] for r in outputs}) == len(outputs)
    (args.directory / 'validation.json').write_text(json.dumps(outputs, indent=2) + '\n')


if __name__ == '__main__':
    main()
