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
skip_links = parser.parse_args().skip_links

ROOT = Path(__file__).resolve().parents[1]
EXE = ROOT / '_build/native/debug/build/cmd/moonrdiff' / 'moonrdiff.exe'
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

report = {'platform': os.name, 'checks': checks, 'passed': True,
          'link_checks_skipped': skip_links,
          'scope': 'native CLI, byte verification, limits and exclusive file creation; all generated data'}
(OUT / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf8')
print(f'Native CLI passed {len(checks)} acceptance checks. Report: {OUT / "report.json"}')
