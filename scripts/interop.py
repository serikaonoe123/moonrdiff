"""Independent rdiff 2.3.4 smoke tests; does not implement delta algorithms."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import struct
import os
import uuid

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'results' / 'interop'
OUT.mkdir(parents=True, exist_ok=True)


def run(args, cwd=ROOT, input_text=None):
    result = subprocess.run(args, cwd=cwd, input=input_text, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(f'{args[0]} failed: {result.stdout}\n{result.stderr}')
    return result.stdout.strip()


def probe(*args, cwd=ROOT):
    executable = ROOT / '_build/js/debug/build/cmd/probe/probe.js'
    if not executable.is_file():
        run(['moon', 'build', 'cmd/probe', '--target', 'js'])
    # Hex signatures can exceed OS argument limits with many small blocks.
    return bytes.fromhex(run(['node', str(executable), '--stdin'], cwd=cwd,
                             input_text=json.dumps(args)))


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

sender = OUT / 'sender'
sender.mkdir(exist_ok=True)
assert not (sender / 'basis.bin').exists()
matching_cases = cases + [
    (b'abcdefghijk', b'ijkabcdefgh'),
    (b'abcdefghijk', b''),
    (b'a' * 512, b'a' * 128 + b'!' + b'a' * 128),
    (bytes(range(256)) * 2, b'x' + bytes(range(256)) + b'y'),
]
for case_index, (old, new) in enumerate(matching_cases):
    basis.write_bytes(old)
    target.write_bytes(new)
    for block_size in [1, 4, 32, 128]:
        reference_sig = OUT / 'reference.sig'
        run(['rdiff', '-f', '-H', 'blake2', '-R', 'rabinkarp', '-b', str(block_size),
             '-S', '32', 'signature', str(basis), str(reference_sig)])
        moon_sig = probe('signature', old.hex(), f'{block_size:02x}', '20')
        assert moon_sig == reference_sig.read_bytes()
        for signature_source, signature_bytes in [('moon', moon_sig), ('rdiff', reference_sig.read_bytes())]:
            supplied_sig = sender / 'basis.sig'
            supplied_sig.write_bytes(signature_bytes)
            (sender / 'target.bin').write_bytes(new)
            for generator in ['moon', 'rdiff']:
                generated = sender / 'generated.delta'
                if generator == 'moon':
                    generated.write_bytes(probe('delta', signature_bytes.hex(), new.hex(),
                                                len(old).to_bytes(4, 'big').hex(), cwd=sender))
                else:
                    run(['rdiff', '-f', 'delta', str(supplied_sig), str(sender / 'target.bin'),
                         str(generated)], cwd=sender)
                restored_bytes = probe('patch', old.hex(), generated.read_bytes().hex())
                assert restored_bytes == new, (case_index, block_size, signature_source, generator, 'moon decoder')
                run(['rdiff', '-f', 'patch', str(basis), str(generated), str(restored)])
                assert restored.read_bytes() == new, (case_index, block_size, signature_source, generator, 'rdiff decoder')
                records.append({'case': f'match-{case_index}-{block_size}-{signature_source}-{generator}',
                                'passed': True, 'target_bytes': len(new), 'delta_bytes': generated.stat().st_size})

# One shifted, block-reusing example must actually save bytes with MoonBit matching.
old = bytes(range(256)) * 4
new = b'prefix' + old + b'end'
delta_bytes = probe('delta', probe('signature', old.hex(), '20', '20').hex(),
                    new.hex(), len(old).to_bytes(4, 'big').hex(), cwd=sender)
assert len(delta_bytes) < len(new)
assert probe('patch', old.hex(), delta_bytes.hex()) == new
records.append({'case': 'moon-matcher-reuses-shifted-blocks', 'passed': True,
                'target_bytes': len(new), 'delta_bytes': len(delta_bytes)})

# Exercise actual native file I/O across the same format boundary.
cli = ROOT / '_build/native/debug/build/cmd/moonrdiff' / 'moonrdiff.exe'
native_dir = OUT / ('native-' + uuid.uuid4().hex)
native_dir.mkdir()
basis.write_bytes(old)
target.write_bytes(new)
native_sig, native_delta, native_restore = [native_dir / name for name in ['basis.sig', 'update.delta', 'restored.bin']]
run([str(cli), 'signature', str(basis), str(native_sig), '--block-size', '32'])
assert native_sig.read_bytes() == probe('signature', old.hex(), '20', '20')
records.append({'case': 'native-cli-signature', 'passed': True})
run([str(cli), 'delta', str(native_sig), str(target), str(native_delta), '--basis-size', str(len(old))])
run(['rdiff', '-f', 'patch', str(basis), str(native_delta), str(restored)])
assert restored.read_bytes() == new
records.append({'case': 'native-cli-delta-to-rdiff', 'passed': True})
run(['rdiff', '-f', 'delta', str(native_sig), str(target), str(reference_delta)])
run([str(cli), 'patch', str(basis), str(reference_delta), str(native_restore)])
assert native_restore.read_bytes() == new
records.append({'case': 'rdiff-delta-to-native-cli', 'passed': True})
assert json.loads(run([str(cli), 'verify', str(target), str(native_restore)]))['matched']
records.append({'case': 'native-cli-verify', 'passed': True})

for block_size in [1, 32, 128]:
    expected_signature = probe('signature', old.hex(), f'{block_size:02x}', '20')
    for chunk_size in [1, 7, 128, 65536]:
        streamed = native_dir / f'chunk-{block_size}-{chunk_size}.sig'
        run([str(cli), 'signature', str(basis), str(streamed), '--block-size', str(block_size),
             '--chunk-size', str(chunk_size)])
        assert streamed.read_bytes() == expected_signature
        records.append({'case': f'native-incremental-{block_size}-{chunk_size}', 'passed': True})

for chunk_size in [1, 7, 65536]:
    partitioned = native_dir / f'patch-chunk-{chunk_size}.bin'
    run([str(cli), 'patch', str(basis), str(reference_delta), str(partitioned), '--chunk-size', str(chunk_size)])
    assert partitioned.read_bytes() == new
    records.append({'case': f'native-incremental-patch-{chunk_size}', 'passed': True})

report = {'reference': version_text.strip(), 'tests': records,
          'scope': 'in-memory RK/BLAKE2 signature, automatic delta matching, both decoders; sender has no basis file'}
(OUT / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf8')
print(f'Passed {len(records)} independent rdiff smoke tests.')
