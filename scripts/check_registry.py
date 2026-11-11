"""Post-publication consumer acceptance; never publishes or changes credentials."""
import argparse
import hashlib
import json
import platform
import re
from pathlib import Path
import shutil
import subprocess
import uuid

parser=argparse.ArgumentParser()
parser.add_argument('--approved-inventory',type=Path,required=True,
                    help='Downloaded successful package report from the approved source commit.')
args=parser.parse_args()
ROOT=Path(__file__).resolve().parents[1]
approved=json.loads(args.approved_inventory.read_text(encoding='utf8'))
assert approved['module']=='serikaonoe123/moonrdiff'
VERSION=approved['version']
assert re.fullmatch(r'\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?',VERSION)
assert approved['packaged_native_file_flow_passed']
assert {x['target'] for x in approved['consumer_results']}=={'js','native','wasm-gc'}
assert all(x['passed'] and x['public_consumer_tests']==5 for x in approved['consumer_results'])
assert {x['path'] for x in approved['files']}==set((ROOT/'packaging/files.txt').read_text().splitlines())
OUT=ROOT/'results'/('registry-'+uuid.uuid4().hex)
OUT.mkdir(parents=True)
consumer=OUT/'consumer'
shutil.copytree(ROOT/'examples/consumer',consumer,
                ignore=shutil.ignore_patterns('_build','.mooncakes','pkg.generated.mbti'))
consumer_mod=consumer/'moon.mod'
text=consumer_mod.read_text(encoding='utf8')
text,count=re.subn(r'serikaonoe123/moonrdiff@[^"\s]+','serikaonoe123/moonrdiff@'+VERSION,text)
assert count==1
consumer_mod.write_text(text,encoding='utf8')
report={'module':approved['module'],'version':VERSION,'status':'running',
        'platform':platform.platform(),'python':platform.python_version(),
        'approved_source_commit':approved['source_commit'],'consumer_results':[]}
def save(): (OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
def run(command):
    result=subprocess.run(command,cwd=consumer,capture_output=True,text=True,encoding='utf8',timeout=300)
    with (OUT/'commands.log').open('a',encoding='utf8') as stream:
        stream.write(json.dumps(command)+'\n'+result.stdout+result.stderr+'\n')
    result.check_returncode()
    return result.stdout
try:
    report['compiler']=subprocess.check_output(['moon','version','--all'],text=True)
    # No MoonRdiff workspace member or local dependency is created here.
    run(['moon','update'])
    tree=json.loads(run(['moon','tree','--json']))
    (OUT/'resolution.json').write_text(json.dumps(tree,indent=2)+'\n',encoding='utf8')
    engine=[x for x in tree['modules'] if x['name']==approved['module']]
    assert len(engine)==1 and engine[0]['source']['kind']=='registry' and engine[0]['version']==VERSION
    # tree resolves registry metadata; a normal check installs the sources.
    run(['moon','check','--target','js','--deny-warn'])
    module=consumer/'.mooncakes/serikaonoe123/moonrdiff'
    assert module.is_dir() and not module.is_symlink()
    installed=module.resolve()
    for item in approved['files']:
        path=(installed/item['path']).resolve()
        assert path.is_relative_to(installed) and path.is_file()
        assert hashlib.sha256(path.read_bytes()).hexdigest()==item['sha256'],item['path']
    report['registry_content_matches_approved_inventory']=True
    for target in ['js','native','wasm-gc']:
        log=run(['moon','test','--package','moonrdiff-example/consumer','--target',target,'--deny-warn'])
        assert 'Total tests: 5, passed: 5, failed: 0.' in log
        report['consumer_results'].append({'target':target,'public_consumer_tests':5,'passed':True})
        save()
    report['status']='success';save()
    print(f'Registry-only {VERSION} consumer and 34-file content acceptance passed: {OUT / "report.json"}')
except Exception as error:
    report['status']='failed';report['error']=str(error);save()
    raise
