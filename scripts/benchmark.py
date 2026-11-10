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
import statistics
import subprocess
import time
import uuid
import zlib

parser=argparse.ArgumentParser()
parser.add_argument('--sizes',nargs='+',type=int,choices=[1,16,128],default=[1,16,128])
parser.add_argument('--scenarios',nargs='+',choices=['identical','modified','insert-delete','random','compressed'],
                    default=['identical','modified','insert-delete','random','compressed'])
parser.add_argument('--generate-only',action='store_true')
parser.add_argument('--profile',choices=['debug','release'],default='debug')
parser.add_argument('--source-root',type=Path,help='Checkout whose CLI is measured; default is this repository.')
parser.add_argument('--label',choices=['baseline','candidate','standalone'],default='standalone')
parser.add_argument('--repetitions',type=int,choices=[1,3,5],default=1)
args=parser.parse_args()
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'results'/('benchmark-'+uuid.uuid4().hex)
OUT.mkdir(parents=True)
SOURCE=(args.source_root or ROOT).resolve()
EXE=SOURCE/f'_build/native/{args.profile}/build/cmd/moonrdiff/moonrdiff.exe'
BLOCK=4096
LIMIT=512*1024*1024
SEED=20261110
records=[]
report={'schema_version':2,'generation_only':args.generate_only,'seed':SEED,
        'profile':args.profile,'label':args.label,'repetitions':args.repetitions,
        'zlib_compile_version':zlib.ZLIB_VERSION,'zlib_runtime_version':zlib.ZLIB_RUNTIME_VERSION,
        'python':platform.python_version(),'platform':platform.platform(),
        'cpu':platform.processor(),'logical_cpus':os.cpu_count(),'block_size':BLOCK,'strong_length':32,
        'measurement':'GNU time per native process; end-to-end CLI; fixed order; median elapsed/wall, maximum RSS across samples',
        'limitations':'Not network latency or isolated algorithm speed. MoonRdiff preflights delta/patch in two passes; rdiff differs. No confidence intervals; build profiles must match for code comparisons.',
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

def timed(command,directory,label,output):
    samples=[]
    output_index=command.index(str(output))
    first_hash=None
    for repetition in range(args.repetitions):
        actual=command.copy()
        actual_output=output if repetition==0 else output.with_name(output.name+f'.sample-{repetition}')
        actual[output_index]=str(actual_output)
        metrics=directory/(label+f'-{repetition}.time')
        started=time.perf_counter()
        result=subprocess.run(['/usr/bin/time','-f','%M %e','-o',str(metrics),*actual],
                              capture_output=True,text=True,timeout=600)
        wall=time.perf_counter()-started
        with (OUT/'commands.log').open('a',encoding='utf8') as stream:
            stream.write(json.dumps(actual)+'\n'+result.stdout+result.stderr+'\n')
        result.check_returncode()
        rss,elapsed=metrics.read_text().split()
        samples.append({'peak_rss_kib':int(rss),'elapsed_seconds':float(elapsed),'harness_wall_seconds':wall})
        # Every repetition writes a fresh file. Check outside the timed interval.
        output_hash=digest(actual_output)
        if first_hash is None: first_hash=output_hash
        assert output_hash==first_hash,(label,repetition,'nondeterministic output')
    return {'peak_rss_kib':max(x['peak_rss_kib'] for x in samples),
            'elapsed_seconds':statistics.median(x['elapsed_seconds'] for x in samples),
            'harness_wall_seconds':statistics.median(x['harness_wall_seconds'] for x in samples),
            'samples':samples}

def rejected(command,output,reason):
    result=subprocess.run(command,capture_output=True,text=True,timeout=60)
    with (OUT/'commands.log').open('a',encoding='utf8') as stream:
        stream.write(json.dumps(command)+'\n'+result.stdout+result.stderr+'\n')
    legacy=report['source_commit']=='79b18247f0b30438c0474cfe80f60fd406554558' and args.label=='baseline' and args.profile=='release'
    # The fixed historical release CLI interpolates Error and loses its payload.
    # Do not rewrite that baseline. Record/check its exact constructor instead;
    # the candidate must emit the specific reason, plus exit 2 and no output.
    expected=('moonrdiff.DeltaError.Invalid' if reason=='Output budget exceeded' else 'moonrdiff.CliError.Usage') if legacy else reason
    assert result.returncode==2 and expected in result.stderr and not result.stdout and not output.exists(),(command,result.returncode,result.stderr)
    report.setdefault('rejection_diagnostics',[]).append({'reason':reason,'specific_reason_verified':not legacy,'expected_diagnostic':expected})
    return True

try:
    if not args.generate_only:
        version=subprocess.run(['rdiff','--version'],capture_output=True,text=True,check=True)
        report['reference_version']=version.stdout+version.stderr
        assert '2.3.4' in report['reference_version']
        report['compiler']=subprocess.check_output(['moon','version','--all'],text=True)
        report['source_commit']=subprocess.check_output(['git','rev-parse','HEAD'],cwd=SOURCE,text=True).strip()
        report['executable_sha256']=digest(EXE)
        print('BENCH_ENV '+json.dumps({k:v for k,v in report.items() if k!='records'}),flush=True)
    for mib in args.sizes:
        for scenario in args.scenarios:
            directory=OUT/f'{mib}MiB-{scenario}';directory.mkdir()
            old,new=generate(directory,mib*1024*1024,scenario)
            record={'nominal_mib':mib,'scenario':scenario,'basis_bytes':old.stat().st_size,
                    'target_bytes':new.stat().st_size,'basis_sha256':digest(old),'target_sha256':digest(new)}
            if not args.generate_only:
                sig,delta,restored,rsig,rdelta,rrestored=[directory/name for name in ['moon.sig','moon.delta','moon-restored.bin','ref.sig','ref.delta','ref-restored.bin']]
                record['moon_signature']=timed([str(EXE),'signature',str(old),str(sig),'--block-size',str(BLOCK),'--max-input',str(LIMIT)],directory,'moon-signature',sig)
                record['ref_signature']=timed(['rdiff','-H','blake2','-R','rabinkarp','-b',str(BLOCK),'-S','32','signature',str(old),str(rsig)],directory,'ref-signature',rsig)
                assert sig.read_bytes()==rsig.read_bytes()
                record['moon_delta']=timed([str(EXE),'delta',str(sig),str(new),str(delta),'--basis-size',str(old.stat().st_size),
                                            '--max-input',str(LIMIT),'--max-output',str(LIMIT)],directory,'moon-delta',delta)
                record['ref_delta']=timed(['rdiff','delta',str(rsig),str(new),str(rdelta)],directory,'ref-delta',rdelta)
                record['moon_patch']=timed([str(EXE),'patch',str(old),str(delta),str(restored),'--max-input',str(LIMIT),'--max-output',str(LIMIT)],directory,'moon-patch',restored)
                record['ref_patch']=timed(['rdiff','patch',str(old),str(rdelta),str(rrestored)],directory,'ref-patch',rrestored)
                assert digest(restored)==digest(rrestored)==record['target_sha256']
                record.update({'signature_bytes':sig.stat().st_size,'delta_bytes':delta.stat().st_size,
                               'signature_sha256':digest(sig),'delta_sha256':digest(delta),
                               'first_exchange_bytes':sig.stat().st_size+delta.stat().st_size,
                               'ref_delta_bytes':rdelta.stat().st_size,'ref_first_exchange_bytes':rsig.stat().st_size+rdelta.stat().st_size,
                               'full_transfer_bytes':new.stat().st_size,'restores_verified':True})
                if new.stat().st_size>67108864:
                    absent=directory/'must-not-exist'
                    record['default_limit_controls']=[
                        rejected([str(EXE),'signature',str(old),str(absent)],absent,'Input byte limit exceeded'),
                        rejected([str(EXE),'delta',str(sig),str(new),str(absent),'--basis-size',str(old.stat().st_size)],absent,'Target byte limit exceeded'),
                        rejected([str(EXE),'patch',str(old),str(delta),str(absent)],absent,'Patch input byte limit exceeded'),
                        rejected([str(EXE),'patch',str(old),str(delta),str(absent),'--max-input',str(LIMIT)],absent,'Output budget exceeded')]
            records.append(record);save()
            if not args.generate_only: print('BENCH_RESULT '+json.dumps(record),flush=True)
            print(f'Completed {mib}MiB {scenario}',flush=True)
    report['status']='success';save()
    print(f'Benchmark cases: {len(records)}; generation_only={args.generate_only}; report={OUT / "report.json"}')
except Exception as error:
    report['status']='failed';report['error']=str(error);save()
    raise
