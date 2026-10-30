#!/usr/bin/env python3
"""Compare apksigner's verified certificate digest to the project's public PEM."""
import argparse
import hashlib
from pathlib import Path
import re
import ssl


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apksigner_log', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    pem = (root / 'android/hirumi-upload-certificate.pem').read_text(encoding='ascii')
    expected = hashlib.sha256(ssl.PEM_cert_to_DER_cert(pem)).hexdigest()
    text = args.apksigner_log.read_text(encoding='utf-8')
    digests = re.findall(r'^Signer #[0-9]+ certificate SHA-256 digest:\s*([a-fA-F0-9]{64})\s*$', text, re.MULTILINE)
    if len(digests) != 1 or digests[0].lower() != expected:
        raise SystemExit('O APK não usa exclusivamente o certificado público esperado do projeto.')
    print('OK: certificado de assinatura corresponde à chave pública do projeto.')


if __name__ == '__main__':
    main()
