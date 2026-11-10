"""Reproducible synthetic CLI benchmarks; Linux GNU time + rdiff 2.3.4.

Local --generate-only checks fixtures and writes no performance claims.
"""
import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import platform
import random
import shutil
import subprocess
import time
import uuid

parser=argparse.ArgumentParser()
parser.add_argument('--sizes',nargs='+',type=int,choices=[1,16,128],default=[1,16,128])
parser.add_argument('--scenarios',nargs='+',choices=['identical','modified','insert-delete','random','compressed'],
                    default=['identical','modified','insert-delete','random','compressed'])
parser.add_argument('--generate-only',action='store_true')
args=parser.parse_args()
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'results'/('benchmark-'+uuid.uuid4().hex)
OUT.mkdir(parents=True)
EXE=ROOT/'_build/native/debug/build/cmd/moonrdiff/moonrdiff.exe'
BLOCK=4096
LIMIT=512*1024*1024
SEED=20261110
records=[]
report={'schema_version':1,'generation_only':args.generate_only,'seed':SEED,
        'python':platform.python_version(),'platform':platform.platform(),
        'cpu':platform.processor(),'logical_cpus':os.cpu_count(),'block_size':BLOCK,'strong_length':32,
        'measurement':'GNU time per native process; end-to-end CLI; one warm-cache sample, fixed order',
        'limitations':'Not network latency or isolated algorithm speed. MoonRdiff preflights delta/patch in two passes; rdiff differs. No confidence intervals.',
        'status':'running','records':records}

def save():
    (OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')

def digest(path):
    with path.open('rb') as stream: return hashlib.file_digest(stream,'sha256').hexdigest()

def random_file(path,size,seed,compressed=False,modify=False):
    rng=random.Random(seed)
    with path.open('xb') as file:
        stream=gzip.GzipFile(filename='',fileobj=file,mode='wb',mtime=0,compresslevel=6) if compressed else file
        try:
            position=0
            while position<size:
                n=min(65536,size-position)
                data=rng.randbytes(n)
                if modify and position==size//2:
                    data=b'X'*4096+data[4096:]
                stream.write(data)
                position+=n
        finally:
            if compressed: stream.close()

def span(source,target,start,length):
    source.seek(start)
    while length:
        data=source.read(min(length,65536))
        assert data
        target.write(data);length-=len(data)

def generate(directory,size,scenario):
    old,new=directory/'old.bin',directory/'new.bin'
    if scenario=='compressed':
        random_file(old,size,SEED,compressed=True)
        random_file(new,size,SEED,compressed=True,modify=True)
    else:
        random_file(old,size,SEED)
        if scenario=='random': random_file(new,size,SEED+1)
        elif scenario=='insert-delete':
            cut=size//3
            with old.open('rb') as source,new.open('xb') as target:
                span(source,target,0,cut)
                target.write(b'inserted-data---'*256) # 4096 bytes
                span(source,target,cut+4096,size-cut-4096)
        else:
            shutil.copyfile(old,new)
            if scenario=='modified':
                with new.open('r+b') as file: file.seek(size//2);file.write(b'X'*4096)
    assert (digest(old)==digest(new)) == (scenario=='identical')
    return old,new

def timed(command,directory,label):
    metrics=directory/(label+'.time')
    started=time.perf_counter()
    result=subprocess.run(['/usr/bin/time','-f','%M %e','-o',str(metrics),*command],
                          capture_output=True,text=True,timeout=600)
    wall=time.perf_counter()-started
    with (OUT/'commands.log').open('a',encoding='utf8') as stream:
        stream.write(json.dumps(command)+'\n'+result.stdout+result.stderr+'\n')
    result.check_returncode()
    rss,elapsed=metrics.read_text().split()
    return {'peak_rss_kib':int(rss),'elapsed_seconds':float(elapsed),'harness_wall_seconds':wall}

def rejected(command,output):
    result=subprocess.run(command,capture_output=True,text=True,timeout=60)
    assert result.returncode==2 and not output.exists(),(command,result.returncode)
    return True

try:
    if not args.generate_only:
        version=subprocess.run(['rdiff','--version'],capture_output=True,text=True,check=True)
        report['reference_version']=version.stdout+version.stderr
        assert '2.3.4' in report['reference_version']
        report['compiler']=subprocess.check_output(['moon','version','--all'],text=True)
        print('BENCH_ENV '+json.dumps({k:v for k,v in report.items() if k!='records'}),flush=True)
    for mib in args.sizes:
        for scenario in args.scenarios:
            directory=OUT/f'{mib}MiB-{scenario}';directory.mkdir()
            old,new=generate(directory,mib*1024*1024,scenario)
            record={'nominal_mib':mib,'scenario':scenario,'basis_bytes':old.stat().st_size,
                    'target_bytes':new.stat().st_size,'basis_sha256':digest(old),'target_sha256':digest(new)}
            if not args.generate_only:
                sig,delta,restored,rsig,rdelta,rrestored=[directory/name for name in ['moon.sig','moon.delta','moon-restored.bin','ref.sig','ref.delta','ref-restored.bin']]
                record['moon_signature']=timed([str(EXE),'signature',str(old),str(sig),'--block-size',str(BLOCK),'--max-input',str(LIMIT)],directory,'moon-signature')
                record['ref_signature']=timed(['rdiff','-H','blake2','-R','rabinkarp','-b',str(BLOCK),'-S','32','signature',str(old),str(rsig)],directory,'ref-signature')
                assert sig.read_bytes()==rsig.read_bytes()
                record['moon_delta']=timed([str(EXE),'delta',str(sig),str(new),str(delta),'--basis-size',str(old.stat().st_size),
                                            '--max-input',str(LIMIT),'--max-output',str(LIMIT)],directory,'moon-delta')
                record['ref_delta']=timed(['rdiff','delta',str(rsig),str(new),str(rdelta)],directory,'ref-delta')
                record['moon_patch']=timed([str(EXE),'patch',str(old),str(delta),str(restored),'--max-input',str(LIMIT),'--max-output',str(LIMIT)],directory,'moon-patch')
                record['ref_patch']=timed(['rdiff','patch',str(old),str(rdelta),str(rrestored)],directory,'ref-patch')
                assert digest(restored)==digest(rrestored)==record['target_sha256']
                record.update({'signature_bytes':sig.stat().st_size,'delta_bytes':delta.stat().st_size,
                               'first_exchange_bytes':sig.stat().st_size+delta.stat().st_size,
                               'ref_delta_bytes':rdelta.stat().st_size,'ref_first_exchange_bytes':rsig.stat().st_size+rdelta.stat().st_size,
                               'full_transfer_bytes':new.stat().st_size,'restores_verified':True})
                if new.stat().st_size>67108864:
                    absent=directory/'must-not-exist'
                    record['default_limit_controls']=[
                        rejected([str(EXE),'signature',str(old),str(absent)],absent),
                        rejected([str(EXE),'delta',str(sig),str(new),str(absent),'--basis-size',str(old.stat().st_size)],absent),
                        rejected([str(EXE),'patch',str(old),str(delta),str(absent)],absent),
                        rejected([str(EXE),'patch',str(old),str(delta),str(absent),'--max-input',str(LIMIT)],absent)]
            records.append(record);save()
            if not args.generate_only: print('BENCH_RESULT '+json.dumps(record),flush=True)
            print(f'Completed {mib}MiB {scenario}',flush=True)
    report['status']='success';save()
    print(f'Benchmark cases: {len(records)}; generation_only={args.generate_only}; report={OUT / "report.json"}')
except Exception as error:
    report['status']='failed';report['error']=str(error);save()
    raise
