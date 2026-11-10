"""Generate a self-contained demonstration using the native CLI only."""
import json
import os
from pathlib import Path
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[1]
EXE = ROOT / '_build/native/debug/build/cmd/moonrdiff' / 'moonrdiff.exe'
if not EXE.is_file():
    raise SystemExit('First run: moon build cmd/moonrdiff --target native')
out = ROOT / 'results' / ('demo-' + uuid.uuid4().hex)
out.mkdir(parents=True)
old = b''.join(f'row {i:04d}: example resource content\n'.encode() for i in range(256))
new = b'New version header\n' + old[:4096] + b'An inserted record\n' + old[4096:]
basis, target, sig, delta, restored = [out / name for name in ['old.bin', 'new.bin', 'old.sig', 'update.delta', 'restored.bin']]
basis.write_bytes(old)
target.write_bytes(new)
commands = [
    ['signature', str(basis), str(sig), '--block-size', '128'],
    ['delta', str(sig), str(target), str(delta), '--basis-size', str(len(old))],
    ['patch', str(basis), str(delta), str(restored)],
    ['verify', str(target), str(restored)],
]
records = []
for args in commands:
    result = subprocess.run([str(EXE), *args], capture_output=True, text=True, check=True)
    records.append(json.loads(result.stdout))
assert restored.read_bytes() == new
report = {'basis_bytes': len(old), 'target_bytes': len(new),
          'signature_bytes': sig.stat().st_size, 'delta_bytes': delta.stat().st_size,
          'first_exchange_bytes': sig.stat().st_size + delta.stat().st_size,
          'matched': True, 'commands': records}
(out / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf8')
print(json.dumps(report, indent=2))
print(f'Demonstration files: {out}')
