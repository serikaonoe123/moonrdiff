"""Native CLI acceptance using generated files under results/, never user files."""
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import subprocess
import uuid
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--skip-links', action='store_true', help='Explicit local-only restriction; CI does not pass this option.')
parser.add_argument('--profile', choices=['debug','release'], default='debug')
args = parser.parse_args()
skip_links = args.skip_links

ROOT = Path(__file__).resolve().parents[1]
EXE = ROOT / f'_build/native/{args.profile}/build/cmd/moonrdiff' / 'moonrdiff.exe'
OUT = ROOT / 'results' / ('cli-' + uuid.uuid4().hex)
OUT.mkdir(parents=True)
checks = []


def invoke(*args, code=0):
    result = subprocess.run([str(EXE), *map(str, args)], capture_output=True,
                            text=True, encoding='utf8', timeout=30)
    assert result.returncode == code, (args, result.returncode, result.stdout, result.stderr)
    if code == 2:
        assert result.stderr and not result.stdout
    else:
        assert not result.stderr
    checks.append({'command': str(args[0]) if args else 'missing', 'exit': code})
    return result


basis = OUT / '旧文件 空格.bin'
target = OUT / '新文件.bin'
sig = OUT / '摘要.sig'
delta = OUT / '更新.delta'
restored = OUT / '还原.bin'
old = bytes(range(256)) * 8 + b'tail'
new = b'prefix' + old[512:] + old[:512] + b'suffix'
basis.write_bytes(old)
target.write_bytes(new)

assert 'signature BASIS' in invoke('--help').stdout
info = json.loads(invoke('signature', basis, sig, '--block-size', '32').stdout)
assert info['basis_size'] == len(old)
invoke('delta', sig, target, delta, '--basis-size', len(old))
invoke('patch', basis, delta, restored)
assert restored.read_bytes() == new
assert json.loads(invoke('verify', target, restored).stdout)['matched']
assert not json.loads(invoke('verify', basis, restored, code=1).stdout)['matched']

# Invalid arguments and inputs must not create output.
absent = OUT / 'must-not-exist'
invoke(code=2)
invoke('unknown', code=2)
invoke('signature', basis, code=2)
invoke('delta', sig, target, absent, code=2)
invoke('delta', sig, target, absent, '--basis-size', '0', code=2)
invoke('signature', basis, absent, '--block-size', '0', code=2)
for value in ['-1', '1e3', '2147483648', '']:
    invoke('signature', basis, absent, '--max-input', value, code=2)
invoke('signature', basis, absent, '--unknown', '1', code=2)
invoke('signature', basis, absent, '--max-input', '1', '--max-input', '2', code=2)
invoke('signature', basis, absent, '--max-input', '1', code=2)
invoke('signature', basis, absent, '--max-output', '1', code=2)
invoke('signature', OUT / 'missing', absent, code=2)
invoke('signature', OUT, absent, code=2)
invoke('patch', basis, delta, absent, '--max-output', '1', code=2)
bad = OUT / 'invalid.delta'
bad.write_bytes(b'bad format')
invoke('patch', basis, bad, absent, code=2)
assert not absent.exists()

# Existing outputs, same-path inputs and filesystem aliases remain intact.
before = sig.read_bytes()
invoke('signature', basis, sig, code=2)
assert sig.read_bytes() == before
invoke('signature', basis, basis, code=2)
assert basis.read_bytes() == old
if not skip_links:
    hardlink = OUT / 'hardlink.bin'
    os.link(basis, hardlink)
    invoke('patch', basis, delta, hardlink, code=2)
    assert hardlink.read_bytes() == old and basis.read_bytes() == old
if os.name != 'nt' and not skip_links:
    symlink = OUT / 'symlink.bin'
    symlink.symlink_to(basis)
    invoke('patch', basis, delta, symlink, code=2)
    assert symlink.is_symlink() and basis.read_bytes() == old

# Concurrent writers cannot both claim the same output.
race_output = OUT / 'race.sig'
def race():
    return subprocess.run([str(EXE), 'signature', str(basis), str(race_output)],
                          capture_output=True, timeout=30)
with ThreadPoolExecutor(max_workers=2) as pool:
    results = list(pool.map(lambda _: race(), range(2)))
assert sorted(r.returncode for r in results) == [0, 2]
reference = OUT / 'reference.sig'
invoke('signature', basis, reference)
assert race_output.read_bytes() == reference.read_bytes()
checks.append({'command': 'concurrent-exclusive-create', 'exit_codes': [0, 2]})

# Zero-byte files work, including a zero-byte restore budget.
empty = OUT / 'empty.bin'
empty.write_bytes(b'')
empty_sig, empty_delta, empty_restore = [OUT / name for name in ['empty.sig', 'empty.delta', 'empty-restored.bin']]
invoke('signature', empty, empty_sig, '--max-input', '0')
invoke('delta', empty_sig, empty, empty_delta, '--basis-size', '0', '--max-output', '5')
invoke('patch', empty, empty_delta, empty_restore, '--max-output', '0')
assert empty_restore.read_bytes() == b''
assert basis.read_bytes() == old and target.read_bytes() == new

# Incremental signature output must be independent of IO chunk boundaries.
for chunk_size in [1, 7, 128, 65536]:
    chunk_sig = OUT / f'chunk-{chunk_size}.sig'
    info = json.loads(invoke('signature', basis, chunk_sig, '--block-size', '32',
                             '--chunk-size', chunk_size).stdout)
    assert info['incremental'] and info['chunk_size'] == chunk_size
    assert chunk_sig.read_bytes() == sig.read_bytes()
for chunk_size in ['0', '65537']:
    invoke('signature', basis, absent, '--chunk-size', chunk_size, code=2)
invoke('signature', basis, absent, '--block-size', '1048577', code=2)
assert not absent.exists()

# Multi-chunk input and output; compare with an independent hashlib signature.
import hashlib
import struct
large_basis = OUT / 'multi-chunk.bin'
large_sig = OUT / 'multi-chunk.sig'
block = bytes(range(256)) * 16
with large_basis.open('xb') as stream:
    for _ in range(2048):
        stream.write(block)
info = json.loads(invoke('signature', large_basis, large_sig, '--block-size', '4096',
                         '--chunk-size', '8191').stdout)
weak = 1
for byte in block:
    weak = (weak * 0x08104225 + byte) & 0xffffffff
record = struct.pack('>I', weak) + hashlib.blake2b(block, digest_size=32).digest()
assert large_sig.read_bytes() == struct.pack('>III', 0x72730147, 4096, 32) + record * 2048
assert info['basis_size'] == 8388608

small_basis, small_delta = OUT / 'small-basis.bin', OUT / 'small.delta'
small_basis.write_bytes(b'abcdefghijk')
small_delta.write_bytes(b'rs\x02\x36\x45\x08\x03\x03NEW\x45\x00\x08\x00')
for chunk_size in [1, 2, 7, 65536]:
    result_path = OUT / f'patch-chunk-{chunk_size}.bin'
    info = json.loads(invoke('patch', small_basis, small_delta, result_path,
                             '--chunk-size', chunk_size).stdout)
    assert info['incremental'] and result_path.read_bytes() == b'ijkNEWabcdefgh'
invoke('patch', small_basis, small_delta, absent, '--max-instructions', '2', code=2)
invoke('patch', small_basis, small_delta, absent, '--chunk-size', '0', code=2)
invoke('patch', small_basis, small_delta, absent, '--chunk-size', '65537', code=2)
for index, data in enumerate([small_delta.read_bytes()[:-1], b'rs\x02\x36\x45\xff\x01\x00', small_delta.read_bytes() + b'x']):
    broken = OUT / f'broken-{index}.delta'
    broken.write_bytes(data)
    invoke('patch', small_basis, broken, absent, '--chunk-size', '1', code=2)
assert not absent.exists()
large_patch = OUT / 'large-copy.delta'
large_restored = OUT / 'large-copy.bin'
large_patch.write_bytes(b'rs\x02\x36\x4f' + struct.pack('>II', 0, 8388608) + b'\x00')
invoke('patch', large_basis, large_patch, large_restored)
assert hashlib.sha256(large_restored.read_bytes()).digest() == hashlib.sha256(large_basis.read_bytes()).digest()

previous = None
for chunk_size in [1, 2, 7, 65536]:
    chunk_delta = OUT / f'delta-chunk-{chunk_size}.delta'
    info = json.loads(invoke('delta', sig, target, chunk_delta, '--basis-size', len(old),
                             '--chunk-size', chunk_size).stdout)
    assert info['incremental']
    assert previous is None or previous == chunk_delta.read_bytes()
    previous = chunk_delta.read_bytes()
for chunk_size in ['0','65537']:
    invoke('delta', sig, target, absent, '--basis-size', len(old), '--chunk-size', chunk_size, code=2)
invoke('delta', sig, target, absent, '--basis-size', len(old), '--max-output', '5', code=2)
assert not absent.exists()
fallback = OUT / 'fallback.delta'
invoke('delta', sig, target, fallback, '--basis-size', len(old), '--max-checks', '0')
fallback_restore = OUT / 'fallback.bin'
invoke('patch', basis, fallback, fallback_restore)
assert fallback_restore.read_bytes() == new

manifest = OUT / 'binding.json'
invoke('manifest', basis, target, delta, manifest)
binding = json.loads(manifest.read_text())
assert binding['schema_version'] == 1 and binding['algorithm'] == 'blake2b-256'
for key, data in [('basis',old),('target',new),('delta',delta.read_bytes())]:
    assert binding[key] == {'size':len(data),'hash':hashlib.blake2b(data,digest_size=32).hexdigest()}
bound_result = OUT / 'bound.bin'
assert json.loads(invoke('patch',basis,delta,bound_result,'--manifest',manifest).stdout)['manifest_verified']
assert bound_result.read_bytes() == new
invoke('manifest',basis,target,delta,manifest,code=2)
wrong_basis = OUT / 'wrong-basis.bin'
wrong_basis.write_bytes(bytes([old[0]^1])+old[1:])
invoke('patch',wrong_basis,delta,absent,'--manifest',manifest,code=2)
wrong_delta = OUT / 'wrong.delta'
raw = delta.read_bytes()
wrong_delta.write_bytes(raw[:-1]+bytes([raw[-1]^1]))
invoke('patch',basis,wrong_delta,absent,'--manifest',manifest,code=2)
for field,value in [('schema_version',2),('algorithm','sha256'),('extra',0)]:
    altered = dict(binding); altered[field]=value
    path = OUT / f'binding-{field}.json';path.write_text(json.dumps(altered))
    invoke('patch',basis,delta,absent,'--manifest',path,code=2)
for key in ['basis','target','delta']:
    altered = json.loads(json.dumps(binding));altered[key]['hash']='0'*64
    path=OUT/f'binding-{key}-bad.json';path.write_text(json.dumps(altered))
    invoke('patch',basis,delta,absent,'--manifest',path,code=2)
duplicate = OUT / 'duplicate.json'
duplicate.write_text(manifest.read_text().replace('"schema_version": 1','"schema_version": 1, "schema_version": 1'))
invoke('patch',basis,delta,absent,'--manifest',duplicate,code=2)
invoke('patch',basis,delta,absent,'--manifest',manifest,'--manifest',manifest,code=2)
invoke('patch',basis,delta,absent,'--manifest',OUT/'missing-manifest',code=2)
assert not absent.exists()

# A truthful record of unrelated inputs is not a valid bound update.
unrelated = OUT / 'unrelated.bin';unrelated.write_bytes(b'unrelated result')
bad_association = OUT / 'unrelated-binding.json'
invoke('manifest',basis,unrelated,delta,bad_association)
invoke('patch',basis,delta,absent,'--manifest',bad_association,code=2)
assert not absent.exists()
invoke('manifest',basis,target,delta,absent,'--max-output','1',code=2)
assert not absent.exists()

report = {'platform': os.name, 'checks': checks, 'passed': True,
          'profile': args.profile,
          'link_checks_skipped': skip_links,
          'scope': 'native CLI, byte verification, limits and exclusive file creation; all generated data'}
(OUT / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf8')
print(f'Native CLI passed {len(checks)} acceptance checks. Report: {OUT / "report.json"}')
