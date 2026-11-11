"""Validate the actual archive, then build/test an extracted package consumer.

Local workspace resolution is intentional here. This is not registry acceptance.
"""
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import uuid
import zipfile
import re
import argparse
parser=argparse.ArgumentParser()
parser.add_argument("--targets",nargs="+",choices=["js","native","wasm-gc"],default=["js","native","wasm-gc"])
parser.add_argument("--skip-native-cli",action="store_true")
args=parser.parse_args()

ROOT = Path(__file__).resolve().parents[1]
metadata=(ROOT/'moon.mod').read_text(encoding='utf8')
versions=re.findall(r'^version\s*=\s*"([^"\n]+)"\s*$',metadata,re.MULTILINE)
assert len(versions)==1
VERSION=versions[0]
CONSUMER_TESTS=5
OUT = ROOT / 'results' / ('package-' + uuid.uuid4().hex)
OUT.mkdir(parents=True)
def run(args, cwd=ROOT):
    result = subprocess.run(args,cwd=cwd,capture_output=True,text=True,encoding='utf8')
    with (OUT/'commands.log').open('a',encoding='utf8') as stream:
        stream.write(' '.join(args)+'\n'+result.stdout+result.stderr+'\n')
    result.check_returncode()
    return result.stdout

run(['moon','package','--frozen'])
archive = ROOT/f'_build/publish/serikaonoe123-moonrdiff-{VERSION}.zip'
allowed = set((ROOT/'packaging/files.txt').read_text().splitlines())
package = OUT/'package'
package.mkdir()
inventory=[]
with zipfile.ZipFile(archive) as zipped:
    files = [e for e in zipped.infolist() if not e.is_dir()]
    names=[e.filename for e in files]
    assert len(names)==len(set(names)) and set(names)==allowed, (set(names)-allowed,allowed-set(names))
    for item in files:
        path=PurePosixPath(item.filename)
        assert not path.is_absolute() and '..' not in path.parts and '\\' not in item.filename
        assert (item.external_attr >> 16) & 0o170000 != 0o120000
        data=zipped.read(item)
        assert data==(ROOT/path).read_bytes(),item.filename
        target=package/path
        assert target.resolve().is_relative_to(package.resolve())
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(data)
        inventory.append({'path':item.filename,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})

# Inspect README links within the package; no development-script link is required.
import re
for link in re.findall(r'\]\(([^)]+)\)',(package/'README.mooncakes.md').read_text(encoding='utf8')):
    if '://' not in link: assert (package/link).is_file(),link
consumer=OUT/'consumer'
shutil.copytree(ROOT/'examples/consumer',consumer,ignore=shutil.ignore_patterns('_build','.mooncakes','pkg.generated.mbti'))
(OUT/'moon.work').write_text('members = ["package", "consumer"]\n',encoding='utf8')
resolution=json.loads(run(['moon','tree','--json'],consumer))
(OUT/'resolution.json').write_text(json.dumps(resolution,indent=2),encoding='utf8')
modules=resolution['modules']
engine=[x for x in modules if x['name']=='serikaonoe123/moonrdiff']
assert len(engine)==1 and engine[0]['source']['kind']=='local'
assert engine[0]['version']==VERSION
assert Path(engine[0]['source']['path']).resolve()==package.resolve()
assert all(Path(x['source']['path']).resolve()!=ROOT for x in modules if x['source']['kind']=='local')
dependency=[x for x in modules if x['name']=='moonbitlang/async']
assert len(dependency)==1 and dependency[0]['version']=='0.19.3' and dependency[0]['source']['kind']=='registry'
results=[]
for target in args.targets:
    log=run(['moon','test','--package','moonrdiff-example/consumer','--target',target,'--deny-warn'],consumer)
    assert f'Total tests: {CONSUMER_TESTS}, passed: {CONSUMER_TESTS}, failed: 0.' in log
    results.append({'target':target,'public_consumer_tests':CONSUMER_TESTS,'passed':True})
if not args.skip_native_cli:
    run(['moon','build','cmd/moonrdiff','--target','native','--deny-warn'],package)
    # Workspace builds place each module under a shared target dir; resolve its artifact.
    candidates=list(OUT.rglob('moonrdiff.exe'))
    assert len(candidates)==1,candidates
    exe=candidates[0]
    fixture=OUT/'file-consumer';fixture.mkdir()
    basis,target,sig,delta,manifest,restored=[fixture/name for name in ['old.bin','new.bin','old.sig','update.delta','binding.json','restored.bin']]
    basis.write_bytes(b'abcdefghijk');target.write_bytes(b'!ijkabcdefgh!')
    for command_args in [
        ['signature',str(basis),str(sig),'--block-size','4'],
        ['delta',str(sig),str(target),str(delta),'--basis-size','11'],
        ['manifest',str(basis),str(target),str(delta),str(manifest)],
        ['patch',str(basis),str(delta),str(restored),'--manifest',str(manifest)],
        ['verify',str(target),str(restored)],
    ]:
        run([str(exe),*command_args],package)
    assert restored.read_bytes()==target.read_bytes()
shutil.copyfile(archive,OUT/archive.name)
report={'module':'serikaonoe123/moonrdiff','version':VERSION,
        'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        'archive_bytes':archive.stat().st_size,
        'archive_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'files':inventory,
        'resolution':'local workspace pointing only at extracted archive; not Mooncakes registry',
        'consumer_results':results,'packaged_native_file_flow_passed':not args.skip_native_cli}
(OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
print(f'Archive accepted: {len(inventory)} files; public consumer backends: {args.targets}; packaged native CLI passed: {not args.skip_native_cli}.')
print(f'Report: {OUT / "report.json"}')
