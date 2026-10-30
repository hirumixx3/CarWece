#!/usr/bin/env python3
"""Restore a private keystore from a GitHub Secret without logging its bytes."""
import argparse
import base64
import os
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', required=True, type=Path)
    args = parser.parse_args()
    required = ['ANDROID_KEYSTORE_BASE64', 'ANDROID_KEYSTORE_PASSWORD',
                'ANDROID_KEY_PASSWORD', 'ANDROID_KEY_ALIAS']
    missing = [name for name in required if not os.environ.get(name)]
    if missing:
        raise SystemExit('Configure os Secrets: ' + ', '.join(missing))
    try:
        data = base64.b64decode(''.join(os.environ['ANDROID_KEYSTORE_BASE64'].split()),
                                validate=True)
    except ValueError:
        raise SystemExit('ANDROID_KEYSTORE_BASE64 não contém um keystore em Base64 válido.')
    args.directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    keystore = (args.directory / 'hirumi-upload.jks').resolve()
    keystore.write_bytes(data)
    keystore.chmod(0o600)
    result = subprocess.run([
        'keytool', '-list', '-keystore', str(keystore),
        '-storepass:env', 'ANDROID_KEYSTORE_PASSWORD',
        '-alias', os.environ['ANDROID_KEY_ALIAS'],
    ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        keystore.unlink(missing_ok=True)
        raise SystemExit('Não foi possível abrir a chave. Confira a senha e o alias dos Secrets.')
    environment_file = os.environ.get('GITHUB_ENV')
    if environment_file:
        with open(environment_file, 'a', encoding='utf-8') as output:
            output.write('ANDROID_KEYSTORE_PATH=' + str(keystore) + '\n')
    print('Keystore restaurado e alias conferido.')


if __name__ == '__main__':
    main()
