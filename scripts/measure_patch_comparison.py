"""Narrow follow-up for the observed 128 MiB COPY patch timing regression."""
import argparse
import hashlib
import json
from pathlib import Path
import random
import statistics
import subprocess
import uuid

parser=argparse.ArgumentParser()
parser.add_argument('--baseline-root',type=Path,required=True)
args=parser.parse_args()
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'results'/('patch-comparison-'+uuid.uuid4().hex)
OUT.mkdir(parents=True)
baseline=args.baseline_root.resolve()
def commit(root): return subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
assert commit(baseline)=='79b18247f0b30438c0474cfe80f60fd406554558'
executables={name:root/'_build/native/release/build/cmd/moonrdiff/moonrdiff.exe'
             for name,root in [('baseline',baseline),('candidate',ROOT)]}
size=128*1024*1024
limit=str(512*1024*1024)
basis=OUT/'basis.bin'
rng=random.Random(20261110)
with basis.open('xb') as stream:
    for _ in range(size//65536): stream.write(rng.randbytes(65536))
def digest(path):
    with path.open('rb') as stream: return hashlib.file_digest(stream,'sha256').hexdigest()
expected=digest(basis)
historical=json.loads((ROOT/'benchmarks/2026-11-10-linux.json').read_text())
assert expected==next(x for x in historical['records'] if x['nominal_mib']==128 and x['scenario']=='identical')['basis_sha256']
def run(command):
    result=subprocess.run(list(map(str,command)),capture_output=True,text=True,timeout=120)
    with (OUT/'commands.log').open('a',encoding='utf8') as stream:
        stream.write(json.dumps(list(map(str,command)))+'\n'+result.stdout+result.stderr+'\n')
    result.check_returncode()
sig,delta=OUT/'basis.sig',OUT/'copy.delta'
run([executables['candidate'],'signature',basis,sig,'--block-size','4096','--max-input',limit])
run([executables['candidate'],'delta',sig,basis,delta,'--basis-size',str(size),'--max-input',limit,'--max-output',limit])
records=[]
report={'schema_version':1,'status':'running','baseline_commit':commit(baseline),'candidate_commit':commit(ROOT),
        'profile':'release','basis_bytes':size,'basis_sha256':expected,'delta_sha256':digest(delta),
        'protocol':'One untimed warmup per version; ten measured pairs, alternating AB/BA order; fresh output and independent SHA256 for every invocation.',
        'limitations':'Single cloud runner; end-to-end sync IO; alternating order reduces but does not eliminate host/disk variation. CPU time does not identify the cause of waits.',
        'records':records}
def save(): (OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
try:
    for name,exe in executables.items():
        output=OUT/(name+'-warmup.bin')
        run([exe,'patch',basis,delta,output,'--max-input',limit,'--max-output',limit])
        assert digest(output)==expected
    for pair in range(10):
        order=['baseline','candidate'] if pair%2==0 else ['candidate','baseline']
        for name in order:
            output=OUT/f'{name}-{pair}.bin'
            metrics=OUT/f'{name}-{pair}.time'
            run(['/usr/bin/time','-f','%M %e %U %S','-o',metrics,executables[name],
                 'patch',basis,delta,output,'--max-input',limit,'--max-output',limit])
            assert digest(output)==expected
            rss,elapsed,user,system=metrics.read_text().split()
            records.append({'pair':pair,'label':name,'peak_rss_kib':int(rss),
                            'elapsed_seconds':float(elapsed),'user_seconds':float(user),
                            'system_seconds':float(system),'restore_verified':True})
            save()
    report['summary']={name:{'median_elapsed_seconds':statistics.median(x['elapsed_seconds'] for x in records if x['label']==name),
                             'median_user_seconds':statistics.median(x['user_seconds'] for x in records if x['label']==name),
                             'median_system_seconds':statistics.median(x['system_seconds'] for x in records if x['label']==name)}
                       for name in executables}
    report['status']='success';save()
    print('PATCH_COMPARISON '+json.dumps(report['summary']),flush=True)
    print(f'Verified {len(records)} measured restores plus two warmups. Report: {OUT / "report.json"}')
except Exception as error:
    report['status']='failed';report['error']=str(error);save()
    raise
