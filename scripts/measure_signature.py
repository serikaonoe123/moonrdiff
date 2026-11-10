"""Linux child-process peak RSS measurements; recorded, not a universal limit."""
import json
from pathlib import Path
import platform
import subprocess
import uuid
import struct
import hashlib

root = Path(__file__).resolve().parents[1]
out = root / 'results' / ('signature-memory-' + uuid.uuid4().hex)
out.mkdir(parents=True)
exe = root / '_build/native/debug/build/cmd/moonrdiff/moonrdiff.exe'
records = []
for size in [4 * 1024 * 1024, 32 * 1024 * 1024]:
    source, signature, metrics = [out / f'{size}.{suffix}' for suffix in ['bin', 'sig', 'time']]
    chunk = bytes(range(256)) * 256
    with source.open('xb') as stream:
        for _ in range(size // len(chunk)):
            stream.write(chunk)
    completed = subprocess.run(['/usr/bin/time', '-f', '%M %e', '-o', str(metrics),
                                str(exe), 'signature', str(source), str(signature),
                                '--block-size', '4096', '--chunk-size', '65536'],
                               capture_output=True, text=True, check=True, timeout=120)
    rss, elapsed = metrics.read_text().split()
    result = json.loads(completed.stdout)
    assert result['incremental'] and result['basis_size'] == size
    patch_file, restored, patch_metrics = [out / f'{size}.{suffix}' for suffix in ['delta', 'restored', 'patch-time']]
    patch_file.write_bytes(b'rs\x02\x36\x4f' + struct.pack('>II', 0, size) + b'\x00')
    completed_patch = subprocess.run(['/usr/bin/time', '-f', '%M %e', '-o', str(patch_metrics),
                                      str(exe), 'patch', str(source), str(patch_file), str(restored)],
                                     capture_output=True, text=True, check=True, timeout=120)
    patch_rss, patch_elapsed = patch_metrics.read_text().split()
    assert json.loads(completed_patch.stdout)['incremental']
    with source.open('rb') as a, restored.open('rb') as b:
        assert hashlib.file_digest(a, 'sha256').digest() == hashlib.file_digest(b, 'sha256').digest()
    records.append({'input_bytes': size, 'signature_bytes': signature.stat().st_size,
                    'peak_rss_kib': int(rss), 'elapsed_seconds': float(elapsed),
                    'patch_peak_rss_kib': int(patch_rss), 'patch_elapsed_seconds': float(patch_elapsed)})
(out / 'report.json').write_text(json.dumps({'platform': platform.platform(),
    'measurement': 'GNU time peak RSS of each native child, KiB',
    'block_size': 4096, 'chunk_size': 65536, 'samples': records,
    'limitation': 'two synthetic inputs; not a platform-independent memory guarantee'}, indent=2) + '\n', encoding='utf8')
print(json.dumps(records))
