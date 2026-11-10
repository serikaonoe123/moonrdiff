"""Independent rdiff 2.3.4 smoke tests; does not implement delta algorithms."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import struct

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'results' / 'interop'
OUT.mkdir(parents=True, exist_ok=True)


def run(args):
    result = subprocess.run(args, cwd=ROOT, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(f'{args[0]} failed: {result.stdout}\n{result.stderr}')
    return result.stdout.strip()


def probe(*args):
    executable = ROOT / '_build/js/debug/build/cmd/probe/probe.js'
    if not executable.is_file():
        run(['moon', 'build', 'cmd/probe', '--target', 'js'])
    return bytes.fromhex(run(['node', str(executable), *args]))


version = subprocess.run(['rdiff', '--version'], capture_output=True, text=True)
version_text = version.stdout + version.stderr
if version.returncode or '2.3.4' not in version_text:
    raise RuntimeError('Expected reference rdiff 2.3.4: ' + version_text)

records = []
basis = OUT / 'basis.bin'
delta = OUT / 'moon.delta'
restored = OUT / 'restored.bin'
basis.write_bytes(b'hello world')
delta.write_bytes(probe('encode-fixture'))
run(['rdiff', '-f', 'patch', str(basis), str(delta), str(restored)])
assert restored.read_bytes() == b'world!hello'
records.append({'case': 'moon-copy-literal-to-rdiff', 'passed': True})

cases = [
    (b'', b''),
    (b'', bytes(range(256)) * 2),
    (bytes(range(256)) * 4, bytes(range(256)) * 4),
    (b'abcdefgh' * 256, b'prefix' + b'abcdefgh' * 256 + b'end'),
    (b'abcd' * 256, b'abcd' * 100 + b'changed' + b'abcd' * 100),
    (b'old', b'completely different'),
]
for index, (old, new) in enumerate(cases):
    basis.write_bytes(old)
    target = OUT / 'target.bin'
    signature = OUT / 'basis.sig'
    reference_delta = OUT / 'reference.delta'
    target.write_bytes(new)
    run(['rdiff', '-f', '-b', '32', 'signature', str(basis), str(signature)])
    run(['rdiff', '-f', 'delta', str(signature), str(target), str(reference_delta)])
    # Only the decoder gets the basis. Signature-only matching is still pending.
    actual = probe('patch', old.hex(), reference_delta.read_bytes().hex())
    assert actual == new, f'reference delta case {index}'
    records.append({'case': f'rdiff-to-moon-{index}', 'passed': True,
                    'target_sha256': hashlib.sha256(new).hexdigest(),
                    'delta_sha256': hashlib.sha256(reference_delta.read_bytes()).hexdigest()})

for size in [0, 1, 4, 31, 32, 33, 127, 128, 129, 255, 256, 257, 384, 512]:
    old = bytes((i * 73 + 255) % 256 for i in range(size))
    basis.write_bytes(old)
    for block_size, strong_length in [(1, 1), (4, 16), (32, 32), (128, 16)]:
        signature = OUT / 'reference.sig'
        run(['rdiff', '-f', '-H', 'blake2', '-R', 'rabinkarp',
             '-b', str(block_size), '-S', str(strong_length),
             'signature', str(basis), str(signature)])
        expected = signature.read_bytes()
        actual = probe('signature', old.hex(), f'{block_size:02x}', f'{strong_length:02x}')
        assert actual == expected, f'signature mismatch {size}/{block_size}/{strong_length}'
        assert probe('signature-roundtrip', expected.hex()) == expected
        assert expected[:12] == struct.pack('>III', 0x72730147, block_size, strong_length)
        for index, offset in enumerate(range(0, len(old), block_size)):
            pos = 12 + index * (4 + strong_length) + 4
            strong = hashlib.blake2b(old[offset:offset+block_size], digest_size=32).digest()[:strong_length]
            assert actual[pos:pos+strong_length] == strong
        records.append({'case': f'signature-{size}-{block_size}-{strong_length}',
                        'passed': True, 'signature_sha256': hashlib.sha256(actual).hexdigest()})

# Exercise a MoonBit-produced signature in a real reference delta calculation.
basis.write_bytes(b'abcdefgh' * 256)
moon_signature = OUT / 'moon.sig'
moon_signature.write_bytes(probe('signature', basis.read_bytes().hex(), '20', '20'))
target.write_bytes(b'prefix' + basis.read_bytes() + b'end')
run(['rdiff', '-f', 'delta', str(moon_signature), str(target), str(reference_delta)])
run(['rdiff', '-f', 'patch', str(basis), str(reference_delta), str(restored)])
assert restored.read_bytes() == target.read_bytes()
assert probe('patch', basis.read_bytes().hex(), reference_delta.read_bytes().hex()) == target.read_bytes()
assert len(reference_delta.read_bytes()) < len(target.read_bytes()), 'Expected actual block reuse'
records.append({'case': 'moon-signature-reference-delta-both-decoders', 'passed': True})

report = {'reference': version_text.strip(), 'tests': records,
          'scope': 'RK/BLAKE2 signature interoperability and explicit delta codec; MoonBit matching still pending'}
(OUT / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf8')
print(f'Passed {len(records)} independent rdiff smoke tests.')
