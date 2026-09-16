#!/usr/bin/env python3
"""Generate an ORIGINAL, tiny skinned GLB used only by the import-contract tests.

This tetrahedron is deliberately not a dog and never enters the playable roster.
No Blender, downloads, image reconstruction or third-party assets are involved.
"""
import json
from pathlib import Path
import struct

OUTPUT = Path(__file__).resolve().parents[2] / 'tests/fixtures/rig_contract.glb'
blob = bytearray()
views, accessors = [], []


def accessor(values, fmt, component, shape, count, minimum=None, maximum=None):
    while len(blob) % 4:
        blob.append(0)
    offset = len(blob)
    packed = struct.pack('<' + fmt * len(values), *values)
    blob.extend(packed)
    views.append({'buffer': 0, 'byteOffset': offset, 'byteLength': len(packed)})
    spec = {'bufferView': len(views)-1, 'componentType': component, 'count': count, 'type': shape}
    if minimum is not None:
        spec['min'], spec['max'] = minimum, maximum
    accessors.append(spec)
    return len(accessors)-1


positions = accessor([-.2, 0, -.2, .2, 0, -.2, 0, .5, 0, 0, 0, .3], 'f', 5126, 'VEC3', 4,
                     [-.2, 0, -.2], [.2, .5, .3])
indices = accessor([0, 2, 1, 0, 3, 2, 1, 2, 3, 0, 1, 3], 'H', 5123, 'SCALAR', 12)
joints = accessor([0, 0, 0, 0] * 4, 'H', 5123, 'VEC4', 4)
weights = accessor([1, 0, 0, 0] * 4, 'f', 5126, 'VEC4', 4)
identity = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
inv_mouth = identity.copy()
inv_mouth[13], inv_mouth[14] = -.7, .6
inverse_bind = accessor(identity + inv_mouth, 'f', 5126, 'MAT4', 2)
times = accessor([0, .2, .4], 'f', 5126, 'SCALAR', 3, [0], [.4])
mouth_motion = accessor([0, .7, -.6, 0, .9, -.7, 0, .7, -.6], 'f', 5126, 'VEC3', 3)
root_motion = accessor([0, 0, 0, 1, 0, .08, 0, .996795, 0, 0, 0, 1], 'f', 5126, 'VEC4', 3)
document = {
    'asset': {'version': '2.0', 'generator': 'Fetch contract fixture generator; NOT A DOG ASSET'},
    'scene': 0, 'scenes': [{'nodes': [0]}],
    'nodes': [
        {'name': 'ContractFixture', 'children': [1, 3]},
        {'name': 'Root', 'children': [2]},
        {'name': 'MouthSocket', 'translation': [0, .7, -.6]},
        {'name': 'FixtureMesh', 'mesh': 0, 'skin': 0},
    ],
    'meshes': [{'primitives': [{'attributes': {'POSITION': positions, 'JOINTS_0': joints,
                                             'WEIGHTS_0': weights}, 'indices': indices}]}],
    'skins': [{'joints': [1, 2], 'skeleton': 1, 'inverseBindMatrices': inverse_bind}],
    'animations': [
        {'name': name,
         'samplers': [{'input': times, 'output': mouth_motion, 'interpolation': 'LINEAR'},
                      {'input': times, 'output': root_motion, 'interpolation': 'LINEAR'}],
         'channels': [{'sampler': 0, 'target': {'node': 2, 'path': 'translation'}},
                      {'sampler': 1, 'target': {'node': 1, 'path': 'rotation'}}]}
        for name in ['idle', 'run', 'throw', 'catch', 'dash', 'ko', 'win']
    ],
    'buffers': [{'byteLength': len(blob)}], 'bufferViews': views, 'accessors': accessors,
}
json_chunk = json.dumps(document, separators=(',', ':')).encode()
json_chunk += b' ' * (-len(json_chunk) % 4)
blob.extend(b'\0' * (-len(blob) % 4))
length = 12 + 8 + len(json_chunk) + 8 + len(blob)
OUTPUT.write_bytes(struct.pack('<4sII', b'glTF', 2, length) +
                   struct.pack('<I4s', len(json_chunk), b'JSON') + json_chunk +
                   struct.pack('<I4s', len(blob), b'BIN\0') + blob)
print(f'Wrote QA-only fixture: {OUTPUT}')
