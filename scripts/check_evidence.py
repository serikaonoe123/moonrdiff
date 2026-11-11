"""Audit original artifact bytes after Git checkout on either platform."""
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
DIRECTORY=ROOT/'benchmarks/large-files-2026-11-11'
expected={
    'windows.json':'3b996c565f68257424ab912d48fdfda17d0beb5d3e35812c4b6e978190e97658',
    'linux.json':'d6921765cad78265cef29e75e01bed1e8f72a7e5c3280be52b3046513add5289',
    'fixtures-windows.json':'8d2ed30beb98d8b1653573be78e91d55e1227d4ff830debba570fa59ab07d675',
    'fixtures-linux.json':'39aa397f47f3594874d90a4eb1284ddf9e89c1f7681655eec384a7a63cb6c0f5',
}
for name,sha in expected.items():
    assert hashlib.sha256((DIRECTORY/name).read_bytes()).hexdigest()==sha,name
for label in ['windows','linux']:
    report=json.loads((DIRECTORY/(label+'.json')).read_bytes())
    assert report['status']=='success' and report['full_128mib_acceptance']
    assert report['fixture_report_sha256']==expected['fixtures-'+label+'.json']
candidate=ROOT/'packaging/candidate-0.1.0.json'
assert hashlib.sha256(candidate.read_bytes()).hexdigest()=='99cfe413492f8573d49fd63283bec8549e64588b08b57344182029f32bacb0be'
print('Original artifact bytes retained: four large-file snapshots and the 0.1.0 candidate inventory.')
