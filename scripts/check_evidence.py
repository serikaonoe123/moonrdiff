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
candidate_012 = (ROOT/'packaging/candidate-0.1.2.json').read_bytes()
assert hashlib.sha256(candidate_012).hexdigest() == '1156780057f1506bee8c6c587f9435369d5b0cce12db8adc80b745c8a92d68f5'
assert json.loads(candidate_012)['source_commit'] == '287872c13b6f2865b3657c10d66ce6eff88cff30'
assert hashlib.sha256(candidate.read_bytes()).hexdigest()=='99cfe413492f8573d49fd63283bec8549e64588b08b57344182029f32bacb0be'
patch_candidate=ROOT/'packaging/candidate-0.1.1.json'
assert hashlib.sha256(patch_candidate.read_bytes()).hexdigest()=='d5454b944e8a21a37f65eab8da495f96ba0eb97849a6c6458a057844162c41ac'
registry={
    'windows-report.json':'62a09e7ecbe9cdf7acede75b96445f506dcddfefade1472c7953079791673772',
    'windows-resolution.json':'170d01fd294e465e48adde495a9631aeda81899588fec9edb4dd27faf4106a9f',
    'linux-report.json':'ba29b5c6388e8ca97eba2662db121e2d1642b0a9eeb43fce0dfc721502604852',
    'linux-resolution.json':'3fff3f99e57cb34869bc862ad48c4b6c0f520135d551e7649233762c8002e668',
}
for name,sha in registry.items():
    assert hashlib.sha256((ROOT/'packaging/registry-0.1.0'/name).read_bytes()).hexdigest()==sha,name
registry_patch={
    'linux-report.json':'7c0611bac1f8cf124924db1f656df710c14dc044103107266ede55d05fd0a167',
    'linux-resolution.json':'83e3ed91e4bfb6ec53a6ebb277faf029896daabdfe692f323d99ef410c7cedc5',
    'windows-report.json':'08194e950ab6bc23bd1b6f000dd9f7f83b1755e7351f4e0d57fce0ff7e6ab667',
    'windows-resolution.json':'7e6bcc8807945e655383fa953e633110ac3a0c7ef2bc826cec48f3ddece031b7',
}
for name,sha in registry_patch.items():
    assert hashlib.sha256((ROOT/'packaging/registry-0.1.1'/name).read_bytes()).hexdigest()==sha,name
source_update = {
    'windows.json': '2170268a0cb89f6fce3a028e83e5733591a17293cca3fed8a770de9f8b99df1f',
    'linux.json': '5deee3612a6a557c89cf422df15494198682779f2ef435f24974b6f7e8bf7660',
}
for name, sha in source_update.items():
    original = (ROOT/'benchmarks/source-update-2026-11-11'/name).read_bytes()
    assert hashlib.sha256(original).hexdigest() == sha, name
    report = json.loads(original)
    assert report['status'] == 'success'
    assert report['source_commit'] == '281bbee7e9900988027be0c9f3253cf09f0c8bf3'
    assert {case['format']: case['offline_plan']['choice'] for case in report['cases']} == {
        'tar': 'delta', 'zip': 'delta', 'tar.gz': 'full',
    }
    for case in report['cases']:
        assert case['target_sha256'] == case['restored_sha256'] == case['selected_result_sha256']
verify_evidence = {'linux-memory.json': 'a0d7bc356e92d8622f0021e00c760d7d09dc531994479fc4c25e9c6446591cc9', 'windows-large.json': 'a83fd3fdb368e05608afe82b29ff63a3e890c8b5deaa5765dcfdd3290d6dfd7f', 'windows-fixtures.json': 'f6026d4fe1c7f017d38e11cb7dae019e469e1f202e8dbb6fa645c5101ed49c29', 'linux-large.json': 'bc2f1fde9727ce75483684a4ebdefb494f481848bf620ed3ebc3313bcf226d62', 'linux-fixtures.json': '39aa397f47f3594874d90a4eb1284ddf9e89c1f7681655eec384a7a63cb6c0f5'}
for name, sha in verify_evidence.items():
    original = (ROOT/"benchmarks/verify-2026-11-11"/name).read_bytes()
    assert hashlib.sha256(original).hexdigest() == sha, name
registry_012 = {'linux-report.json': '486370bf19d4cd1cd71027f6deebfd11362ddf8f3c07d5a8ebfee62d11350fa4', 'linux-resolution.json': 'b8466a0e787197b2181010a08d19b398cde7da9eff5d6a6e617e9d832ad9b495', 'windows-report.json': 'eabf62f45f8757ac3ee911dd8a09c221cbc584ba15dfe4151ef7fc7128f80fdd', 'windows-resolution.json': 'd2a97bb6e2b6924bb399a2e2586d3f5ce94248aa312f10dbc7fa07f8aed298ec'}
for name, sha in registry_012.items():
    assert hashlib.sha256((ROOT/"packaging/registry-0.1.2"/name).read_bytes()).hexdigest() == sha, name
print('Original large-file, source-update, candidate and published registry evidence bytes retained.')
