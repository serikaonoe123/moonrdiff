"""Cross-platform generated-file acceptance; no timing/performance claims."""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import subprocess
import sys
import uuid

parser=argparse.ArgumentParser()
parser.add_argument('--size-mib',type=int,choices=[1,128],default=128,
                    help='1 is a harness smoke check, not 128 MiB acceptance.')
args=parser.parse_args()
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'results'/('large-files-'+uuid.uuid4().hex)
OUT.mkdir(parents=True)
EXE=ROOT/'_build/native/release/build/cmd/moonrdiff/moonrdiff.exe'
LIMIT=str(512*1024*1024)
records=[]
report={'schema_version':1,'status':'running','profile':'release','platform':platform.platform(),
        'python':platform.python_version(),'nominal_mib':args.size_mib,
        'full_128mib_acceptance':False,'records':records,
        'scope':'Generated files; correctness and default-budget rejection, not performance, snapshots or multi-gigabyte acceptance.'}
def save(): (OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
def digest(path):
    with path.open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()
def run(command,code=0,reason=None):
    result=subprocess.run(list(map(str,command)),capture_output=True,text=True,encoding='utf8',timeout=300)
    with (OUT/'commands.log').open('a',encoding='utf8') as stream:
        stream.write(json.dumps(list(map(str,command)))+'\n'+result.stdout+result.stderr+'\n')
    assert result.returncode==code,(command,result.returncode,result.stderr)
    if code==0:
        assert not result.stderr,result.stderr
    else:
        assert reason in result.stderr and not result.stdout,(reason,result.stderr)
    return result.stdout
def invoke(*command):return json.loads(run([EXE,*command]))
try:
    report['source_commit']=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    report['executable_sha256']=digest(EXE)
    report['compiler']=subprocess.check_output(['moon','version','--all'],text=True)
    # Reuse the committed deterministic fixture generator without running its
    # Linux/GNU-time benchmark mode. Keep its separate generation report too.
    generated=run([sys.executable,ROOT/'scripts/benchmark.py','--generate-only',
                   '--sizes',str(args.size_mib),'--profile','release'])
    source=Path(generated.rsplit('report=',1)[1].strip()).resolve()
    assert source.is_relative_to((ROOT/'results').resolve()) and source.name=='report.json'
    fixtures=json.loads(source.read_text(encoding='utf8'))
    assert fixtures['status']=='success' and fixtures['generation_only']
    assert len(fixtures['records'])==5
    report['fixture_report']=str(source.relative_to(ROOT))
    report['fixture_report_sha256']=digest(source)
    for fixture in fixtures['records']:
        case=fixture['scenario']
        directory=source.parent/f'{args.size_mib}MiB-{case}'
        basis,target=directory/'old.bin',directory/'new.bin'
        assert digest(basis)==fixture['basis_sha256'] and digest(target)==fixture['target_sha256']
        sig,delta,restored=[directory/name for name in ['accept.sig','accept.delta','accept-restored.bin']]
        info=invoke('signature',basis,sig,'--block-size','4096','--max-input',LIMIT)
        assert info['basis_size']==basis.stat().st_size
        invoke('delta',sig,target,delta,'--basis-size',str(basis.stat().st_size),
               '--max-input',LIMIT,'--max-output',LIMIT)
        invoke('patch',basis,delta,restored,'--max-input',LIMIT,'--max-output',LIMIT)
        assert digest(restored)==fixture['target_sha256']
        row={**fixture,'signature_sha256':digest(sig),'delta_sha256':digest(delta),
             'signature_bytes':sig.stat().st_size,'delta_bytes':delta.stat().st_size,
             'restore_sha256':digest(restored),'restore_verified':True,'default_budget_controls':[]}
        absent=directory/'must-not-exist'
        if args.size_mib==128:
            commands=[
                (['signature',basis,absent], 'Input byte limit exceeded'),
                (['delta',sig,target,absent,'--basis-size',str(basis.stat().st_size)],'Target byte limit exceeded'),
                (['patch',basis,delta,absent],'Patch input byte limit exceeded'),
                (['patch',basis,delta,absent,'--max-input',LIMIT],'Output budget exceeded')]
            for command,reason in commands:
                run([EXE,*command],code=2,reason=reason)
                assert not absent.exists()
                row['default_budget_controls'].append({'reason':reason,'no_output':True})
        if case=='modified':
            assert invoke('verify',target,restored,'--max-input',LIMIT)['matched']
            manifest=directory/'binding.json'
            invoke('manifest',basis,target,delta,manifest,'--max-input',LIMIT)
            binding=json.loads(manifest.read_text(encoding='utf8'))
            for key,path in [('basis',basis),('target',target),('delta',delta)]:
                assert binding[key]['size']==path.stat().st_size
                with path.open('rb') as stream:
                    assert binding[key]['hash']==hashlib.file_digest(stream,lambda:hashlib.blake2b(digest_size=32)).hexdigest()
            bound=directory/'bound-restored.bin'
            assert invoke('patch',basis,delta,bound,'--manifest',manifest,
                          '--max-input',LIMIT,'--max-output',LIMIT)['manifest_verified']
            assert digest(bound)==fixture['target_sha256']
            row['bound_restore_verified']=True
            row['manifest_independent_hashes_verified']=True
            row['cli_verify_matched']=True
            if args.size_mib==128:
                run([EXE,'verify',target,restored],code=2,reason='Input byte limit exceeded')
                run([EXE,'manifest',basis,target,delta,absent],code=2,reason='Manifest input byte limit exceeded')
                assert not absent.exists()
                row['default_verify_manifest_rejected']=True
        records.append(row);save()
        print('LARGE_FILE_RESULT '+json.dumps(row),flush=True)
    assert {x['scenario'] for x in records}=={'identical','modified','insert-delete','random','compressed'}
    report['full_128mib_acceptance']=args.size_mib==128
    report['status']='success';save()
    print(f'Large-file cases: {len(records)}; full_128mib_acceptance={report["full_128mib_acceptance"]}; report={OUT / "report.json"}')
except Exception as error:
    report['status']='failed';report['error']=str(error);save()
    raise
