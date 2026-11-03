#!/usr/bin/env python3
"""Connect actual bounded production geometry exports to the existing Mesa QA.
All blocks are deliberately drawn: this pass verifies shaders/pixel output,
while the Kotlin geometry/JUnit passes cover conservative culling and bounds.
"""
import json
import shutil
import sys
from pathlib import Path
raw, packed = map(Path, sys.argv[1:3])
frames = json.loads((raw/'frames.json').read_text())
meta = json.loads((packed/'optimized.json').read_text())
meta['frames'] = []
for shot in frames:
    ranges = meta['meshes'][shot['world']]['ranges']
    instances = list(range(int(shot['frame'][14])))
    meta['frames'].append({'name': shot['name'],
        'visibleWorld': list(range(len(ranges))),
        'shadowWorld': list(range(len(ranges))),
        'visibleInstances': instances, 'shadowInstances': instances})
(packed/'optimized.json').write_text(json.dumps(meta))
shutil.copyfile(raw/'frames.json', packed/'frames.json')
for name in ['scene.vert','scene.frag','depth.vert','depth.frag']:
    shutil.copyfile(raw/name, packed/name)
print(f'{len(frames)} real start/loop frames ready for GLES')
