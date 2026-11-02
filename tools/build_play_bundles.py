#!/usr/bin/env python3
"""Build signed Play bundles with distinct version codes using the Flutter CLI."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--version-name', default='1.2.0')
    parser.add_argument('--first-code', type=int, default=7)
    parser.add_argument('--count', type=int, default=6)
    parser.add_argument('--output', type=Path, default=Path('dist'))
    args = parser.parse_args()
    if not re.fullmatch(r'\d+\.\d+\.\d+(?:[.-][A-Za-z0-9.-]+)?', args.version_name):
        parser.error('Use uma versão como 1.0.0.')
    if not 1 <= args.count <= 6 or not 1 <= args.first_code <= 2100000000:
        parser.error('Informe de 1 a 6 bundles e um versionCode positivo.')
    if args.first_code + args.count - 1 > 2100000000:
        parser.error('versionCode acima do limite permitido.')
    required = ['ANDROID_KEYSTORE_PATH', 'ANDROID_KEYSTORE_PASSWORD',
                'ANDROID_KEY_PASSWORD', 'ANDROID_KEY_ALIAS']
    missing = [name for name in required if not os.environ.get(name)]
    if missing:
        raise SystemExit('Configure a assinatura: ' + ', '.join(missing))
    if not Path(os.environ['ANDROID_KEYSTORE_PATH']).is_file():
        raise SystemExit('O arquivo informado em ANDROID_KEYSTORE_PATH não existe.')
    flutter = os.environ.get('CARWECE_FLUTTER_BIN') or shutil.which('flutter')
    if not flutter:
        raise SystemExit('Flutter não encontrado no PATH.')
    root = Path(__file__).resolve().parent.parent
    expected_pem = (root / 'android/hirumi-upload-certificate.pem').read_text()
    expected_certificate = hashlib.sha256(base64.b64decode(
        ''.join(line for line in expected_pem.splitlines() if not line.startswith('-----'))
    )).hexdigest()
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    reports = []
    for code in range(args.first_code, args.first_code + args.count):
        print(f'Compilando CarWece {args.version_name}, versionCode {code}…', flush=True)
        subprocess.run([
            flutter, 'build', 'appbundle', '--release', '--no-pub',
            '--target-platform=android-arm,android-arm64,android-x64',
            '--build-name=' + args.version_name, '--build-number=' + str(code),
            '--dart-define=CARWECE_VERSION_NAME=' + args.version_name,
        ], cwd=root, check=True)
        built = root / 'build/app/outputs/bundle/release/app-release.aab'
        target = args.output / f'CarWece_{args.version_name}_vc{code}.aab'
        shutil.copy2(built, target)
        result = subprocess.run(['jarsigner', '-verify', str(target)],
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, check=True)
        if 'jar verified.' not in result.stdout or 'jar is unsigned' in result.stdout:
            raise SystemExit('Assinatura do bundle não foi validada: ' + target.name)
        certificate = subprocess.run(['keytool', '-printcert', '-jarfile',
                                      str(target), '-rfc'], check=True,
                                     stdout=subprocess.PIPE, text=True).stdout
        pem_match = re.search(r'-----BEGIN CERTIFICATE-----(.*?)-----END CERTIFICATE-----',
                              certificate, re.S)
        if not pem_match or hashlib.sha256(base64.b64decode(pem_match[1])).hexdigest() != expected_certificate:
            raise SystemExit('O bundle foi assinado com uma chave diferente da chave hirumi deste projeto.')
        reports.append({'file': target.name, 'versionName': args.version_name,
                        'versionCode': code, 'bytes': target.stat().st_size,
                        'signingCertificateSha256': expected_certificate,
                        'sha256': hashlib.sha256(target.read_bytes()).hexdigest()})
    (args.output / 'release-manifest.json').write_text(
        json.dumps(reports, indent=2) + '\n', encoding='utf-8')
    (args.output / 'SHA256SUMS.txt').write_text(
        ''.join(row['sha256'] + '  ' + row['file'] + '\n' for row in reports), encoding='utf-8')
    print(f'{len(reports)} bundles assinados em {args.output}', flush=True)


if __name__ == '__main__':
    main()
