#!/usr/bin/env python3
"""Verify the built APK contains the exact new tracks, playable via openFd."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    catalog_bytes = (root / 'assets/music/catalog.json').read_bytes()
    catalog = json.loads(catalog_bytes)
    counts = {key: len(catalog[key]) for key in ('menuIds', 'raceIds', 'battleIds')}
    if counts != {'menuIds': 5, 'raceIds': 15, 'battleIds': 5}:
        raise SystemExit(f'Categorias inesperadas: {counts}')
    prefix = 'assets/flutter_assets/assets/music/'
    with zipfile.ZipFile(args.apk) as apk:
        expected = {prefix + track['file'] for track in catalog['tracks']} | {prefix + 'catalog.json'}
        names = [entry.filename for entry in apk.infolist() if entry.filename.startswith(prefix)]
        if set(names) != expected or len(names) != len(expected):
            raise SystemExit('Arquivos de música ausentes, duplicados ou extras no APK.')
        if apk.read(prefix + 'catalog.json') != catalog_bytes:
            raise SystemExit('O catálogo no APK difere do código-fonte.')
        for track in catalog['tracks']:
            info = apk.getinfo(prefix + track['file'])
            if info.compress_type != zipfile.ZIP_STORED:
                raise SystemExit(f"{track['file']}: comprimida no ZIP; openFd exige entrada sem compressão.")
            data = apk.read(info)
            if len(data) != track['bytes'] or hashlib.sha256(data).hexdigest() != track['sha256']:
                raise SystemExit(f"{track['file']}: tamanho ou SHA-256 diferente do catálogo.")
    print('OK: 25/25 faixas novas, categorias corretas, hashes íntegros e sem compressão ZIP.')


if __name__ == '__main__':
    main()
